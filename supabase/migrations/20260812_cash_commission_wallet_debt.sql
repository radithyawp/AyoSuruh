-- AYO SURUH - CASH COMMISSION + WALLET OFFSET
-- Cash remains Customer -> Mitra. The Customer is NOT charged an extra fee.
-- The normal platform commission is recorded on the payment and settled from
-- the Mitra AyoPay available balance. If the balance is not enough, the
-- available wallet can become negative; future released earnings naturally
-- offset that outstanding balance before a payout can be requested.
--
-- Voucher rules/reservations are NOT changed. A Cash voucher still reduces
-- the amount handed by Customer and its subsidy is credited to the Mitra
-- wallet. The subsidy can then naturally offset a Cash commission obligation.
--
-- Depends on:
--   20260811_cash_payment_voucher_checkout.sql
--   20260812_growth_launch_incentives.sql

begin;

-- Feature switch. Keep the commercial rule server-controlled.
alter table public.business_settings
  add column if not exists cash_commission_enabled boolean not null default true;

-- Ledger now has an explicit debit entry for Cash commission.
alter table public.mitra_wallet_ledger
  drop constraint if exists mitra_wallet_ledger_entry_type_check;

alter table public.mitra_wallet_ledger
  add constraint mitra_wallet_ledger_entry_type_check
  check (
    entry_type in (
      'job_earning',
      'payout_hold',
      'payout_release',
      'payout_paid',
      'refund_adjustment',
      'manual_adjustment',
      'voucher_subsidy',
      'cash_commission'
    )
  );

-- Payment economics: Cash is now commissionable as well. Because Cash is a
-- commissionable transaction, it can also consume the one-time New Partner
-- Bonus. This keeps the promise "0% on the first eligible completed job"
-- independent of the Customer's payment method.
create or replace function public.set_payment_economics()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_base_percent numeric;
  v_gross numeric;
  v_bonus boolean := false;
  v_cash_commission_enabled boolean := true;
begin
  v_gross := greatest(coalesce(new.amount, 0), 0);

  if new.base_platform_fee_percent is not null then
    v_base_percent := new.base_platform_fee_percent;
  elsif tg_op = 'UPDATE' and old.base_platform_fee_percent is not null then
    v_base_percent := old.base_platform_fee_percent;
  elsif new.platform_fee_percent is not null and new.platform_fee_percent > 0 then
    v_base_percent := new.platform_fee_percent;
  elsif tg_op = 'UPDATE' and old.platform_fee_percent is not null
        and old.platform_fee_percent > 0 then
    v_base_percent := old.platform_fee_percent;
  else
    v_base_percent := public.current_platform_fee_percent();
  end if;

  v_base_percent := greatest(0, least(coalesce(v_base_percent, 0), 100));
  new.base_platform_fee_percent := v_base_percent;

  if coalesce(new.provider, '') = 'cash' then
    select coalesce(bs.cash_commission_enabled, true)
    into v_cash_commission_enabled
    from public.business_settings bs
    where bs.id = 1;

    if not coalesce(v_cash_commission_enabled, true) then
      if tg_op = 'UPDATE' and coalesce(old.first_job_bonus_applied, false) then
        perform public._release_mitra_first_job_bonus(new.job_id);
      end if;

      new.first_job_bonus_applied := false;
      new.first_job_bonus_amount := 0;
      new.platform_fee_percent := 0;
      new.platform_fee_amount := 0;
      new.mitra_net_amount := v_gross;
      return new;
    end if;
  end if;

  if new.job_id is not null
     and coalesce(new.payment_required, false) then
    v_bonus := public._reserve_mitra_first_job_bonus(new.job_id);
  end if;

  if v_bonus then
    new.first_job_bonus_applied := true;
    new.first_job_bonus_amount := round(v_gross * v_base_percent / 100.0, 2);
    new.platform_fee_percent := 0;
    new.platform_fee_amount := 0;
    new.mitra_net_amount := v_gross;
  else
    new.first_job_bonus_applied := false;
    new.first_job_bonus_amount := 0;
    new.platform_fee_percent := v_base_percent;
    new.platform_fee_amount := round(v_gross * v_base_percent / 100.0, 2);
    new.mitra_net_amount := greatest(v_gross - new.platform_fee_amount, 0);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_set_payment_economics on public.payments;
create trigger trg_set_payment_economics
before insert or update of amount, platform_fee_percent, provider, payment_required
on public.payments
for each row execute function public.set_payment_economics();

-- Pending Cash checkouts created before this migration have never transferred
-- money yet, so bring only those rows onto the new economics. Historical paid
-- Cash transactions remain untouched and are NOT charged retroactively.
update public.payments p
set platform_fee_percent = coalesce(
      nullif(p.base_platform_fee_percent, 0),
      public.current_platform_fee_percent()
    )
where coalesce(p.provider, '') = 'cash'
  and p.status = 'pending'::public.payment_status;

-- Wallet settlement. Online flow remains unchanged. For Cash we never credit
-- the job gross because Customer already handed it to Mitra. We only:
--   1) credit an existing voucher subsidy (unchanged behavior), and
--   2) debit the effective platform commission from available AyoPay.
-- If available balance is insufficient the resulting available balance is
-- negative. Any later earning that becomes available offsets it naturally.
create or replace function public.sync_job_wallet_credit(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_mitra_id uuid;
  v_job_status public.job_status;
  v_payment_status public.payment_status;
  v_provider text;
  v_gross_amount numeric;
  v_discount numeric;
  v_fee_percent numeric;
  v_base_fee_percent numeric;
  v_fee_amount numeric;
  v_net_amount numeric;
  v_first_job_bonus boolean;
  v_first_job_bonus_amount numeric;
  v_inserted integer := 0;
begin
  select
    j.mitra_id,
    j.status,
    p.status,
    coalesce(p.provider, 'midtrans'),
    coalesce(p.amount, j.budget, 0),
    coalesce(p.discount_amount, 0),
    coalesce(p.platform_fee_percent, public.current_platform_fee_percent()),
    coalesce(p.base_platform_fee_percent, public.current_platform_fee_percent()),
    coalesce(p.platform_fee_amount, 0),
    coalesce(p.mitra_net_amount, coalesce(p.amount, j.budget, 0)),
    coalesce(p.first_job_bonus_applied, false),
    coalesce(p.first_job_bonus_amount, 0)
  into
    v_mitra_id,
    v_job_status,
    v_payment_status,
    v_provider,
    v_gross_amount,
    v_discount,
    v_fee_percent,
    v_base_fee_percent,
    v_fee_amount,
    v_net_amount,
    v_first_job_bonus,
    v_first_job_bonus_amount
  from public.jobs j
  join public.payments p on p.job_id = j.id
  where j.id = p_job_id;

  if not found
     or v_mitra_id is null
     or v_job_status <> 'completed'::public.job_status
     or v_payment_status <> 'paid'::public.payment_status then
    return;
  end if;

  if v_provider = 'cash' then
    -- Existing voucher subsidy behavior is preserved exactly: Ayo Suruh
    -- credits the discount because Customer hands only the discounted Cash
    -- amount directly to the Mitra.
    if coalesce(v_discount, 0) > 0 then
      insert into public.mitra_wallet_ledger (
        mitra_id,
        job_id,
        amount,
        bucket,
        entry_type,
        available_at,
        reference_key,
        description,
        raw_data
      ) values (
        v_mitra_id,
        p_job_id,
        v_discount,
        'pending',
        'voucher_subsidy',
        timezone('utc'::text, now()) + interval '1 day',
        'job:' || p_job_id::text || ':cash_voucher_subsidy',
        'Subsidi voucher untuk transaksi Cash. Customer membayar nominal setelah diskon langsung ke Mitra.',
        jsonb_build_object(
          'gross_amount', v_gross_amount,
          'customer_cash_amount', greatest(v_gross_amount - v_discount, 0),
          'voucher_subsidy', v_discount,
          'base_platform_fee_percent', v_base_fee_percent,
          'platform_fee_percent', v_fee_percent,
          'platform_fee_amount', v_fee_amount,
          'first_job_bonus_applied', v_first_job_bonus,
          'first_job_bonus_amount', v_first_job_bonus_amount
        )
      )
      on conflict (reference_key) do nothing;
    end if;

    -- First-job bonus has effective fee 0, therefore no debit is created.
    if coalesce(v_fee_amount, 0) > 0 then
      insert into public.mitra_wallet_ledger (
        mitra_id,
        job_id,
        amount,
        bucket,
        entry_type,
        reference_key,
        description,
        raw_data
      ) values (
        v_mitra_id,
        p_job_id,
        -v_fee_amount,
        'available',
        'cash_commission',
        'job:' || p_job_id::text || ':cash_commission',
        'Komisi platform untuk transaksi Cash. Dipotong dari saldo AyoPay; jika saldo belum cukup, menjadi saldo terutang dan otomatis tertutup oleh pendapatan berikutnya.',
        jsonb_build_object(
          'gross_amount', v_gross_amount,
          'customer_cash_amount', greatest(v_gross_amount - v_discount, 0),
          'voucher_subsidy', v_discount,
          'base_platform_fee_percent', v_base_fee_percent,
          'platform_fee_percent', v_fee_percent,
          'platform_fee_amount', v_fee_amount,
          'mitra_net_amount', v_net_amount,
          'first_job_bonus_applied', v_first_job_bonus,
          'first_job_bonus_amount', v_first_job_bonus_amount
        )
      )
      on conflict (reference_key) do nothing;

      get diagnostics v_inserted = row_count;
      if v_inserted > 0 then
        perform public.enqueue_notification(
          p_user_id => v_mitra_id,
          p_title => 'Komisi Cash Tercatat',
          p_body => 'Komisi platform sebesar Rp' ||
            trim(to_char(v_fee_amount, 'FM999G999G999G999G990')) ||
            ' dicatat pada saldo AyoPay. Jika saldo belum cukup, pendapatan berikutnya akan menutup kewajiban ini.',
          p_type => 'cash_commission_recorded',
          p_job_id => p_job_id,
          p_data => jsonb_build_object(
            'platform_fee_amount', v_fee_amount,
            'platform_fee_percent', v_fee_percent
          )
        );
      end if;
    end if;

    return;
  end if;

  if coalesce(v_net_amount, 0) <= 0 then
    return;
  end if;

  insert into public.mitra_wallet_ledger (
    mitra_id,
    job_id,
    amount,
    bucket,
    entry_type,
    available_at,
    reference_key,
    description,
    raw_data
  ) values (
    v_mitra_id,
    p_job_id,
    v_net_amount,
    'pending',
    'job_earning',
    timezone('utc'::text, now()) + interval '1 day',
    'job:' || p_job_id::text || ':earning',
    case
      when v_first_job_bonus then
        'Bonus Mitra Baru: 0% komisi untuk pekerjaan pertama. Menunggu masa hold 1 hari.'
      else
        'Pendapatan bersih pekerjaan setelah komisi platform ' ||
        trim(to_char(v_fee_percent, 'FM999990.00')) || '%. Menunggu masa hold 1 hari.'
    end,
    jsonb_build_object(
      'gross_amount', v_gross_amount,
      'base_platform_fee_percent', v_base_fee_percent,
      'platform_fee_percent', v_fee_percent,
      'platform_fee_amount', v_fee_amount,
      'mitra_net_amount', v_net_amount,
      'first_job_bonus_applied', v_first_job_bonus,
      'first_job_bonus_amount', v_first_job_bonus_amount
    )
  )
  on conflict (reference_key) do nothing;
end;
$$;

revoke all on function public.sync_job_wallet_credit(uuid) from public;

-- Reversal also understands the new Cash wallet effects. This is defensive
-- accounting for a later admin/refund flow and keeps the ledger balanced.
create or replace function public.reverse_job_wallet_credit(
  p_job_id uuid,
  p_reason text default 'Pembayaran direfund atau dibatalkan.'
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_provider text;
  v_entry public.mitra_wallet_ledger%rowtype;
  v_earning public.mitra_wallet_ledger%rowtype;
begin
  select coalesce(p.provider, 'midtrans')
  into v_provider
  from public.payments p
  where p.job_id = p_job_id;

  if coalesce(v_provider, '') = 'cash' then
    for v_entry in
      select l.*
      from public.mitra_wallet_ledger l
      where l.job_id = p_job_id
        and l.entry_type in ('cash_commission', 'voucher_subsidy')
        and l.state = 'posted'
      order by l.created_at asc
    loop
      insert into public.mitra_wallet_ledger (
        mitra_id,
        job_id,
        amount,
        bucket,
        entry_type,
        available_at,
        reference_key,
        description,
        raw_data
      ) values (
        v_entry.mitra_id,
        p_job_id,
        -v_entry.amount,
        case
          when v_entry.bucket = 'pending' then 'pending'
          else 'available'
        end,
        'refund_adjustment',
        case
          when v_entry.bucket = 'pending' then
            coalesce(v_entry.available_at, timezone('utc'::text, now()))
          else null
        end,
        'job:' || p_job_id::text || ':reverse:' || v_entry.entry_type,
        coalesce(nullif(trim(p_reason), ''), 'Pembayaran direfund atau dibatalkan.'),
        jsonb_build_object(
          'reversed_entry_id', v_entry.id,
          'reversed_entry_type', v_entry.entry_type,
          'reversed_bucket', v_entry.bucket
        )
      )
      on conflict (reference_key) do nothing;
    end loop;
    return;
  end if;

  select l.*
  into v_earning
  from public.mitra_wallet_ledger l
  where l.job_id = p_job_id
    and l.entry_type = 'job_earning'
    and l.state = 'posted'
  order by l.created_at asc
  limit 1;

  if not found then
    return;
  end if;

  insert into public.mitra_wallet_ledger (
    mitra_id,
    job_id,
    amount,
    bucket,
    entry_type,
    reference_key,
    description,
    raw_data
  ) values (
    v_earning.mitra_id,
    p_job_id,
    -v_earning.amount,
    case
      when v_earning.bucket = 'pending' then 'pending'
      else 'available'
    end,
    'refund_adjustment',
    'job:' || p_job_id::text || ':refund_adjustment',
    coalesce(nullif(trim(p_reason), ''), 'Pembayaran direfund atau dibatalkan.'),
    jsonb_build_object(
      'earning_entry_id', v_earning.id,
      'earning_bucket', v_earning.bucket
    )
  )
  on conflict (reference_key) do nothing;
end;
$$;

revoke all on function public.reverse_job_wallet_credit(uuid, text) from public;

commit;
