-- AYO SURUH - CASH PAYMENT + VOUCHER CHECKOUT
-- Temporary production-safe cash channel while Midtrans production onboarding
-- is pending. Cash is recorded in-app but money moves Customer -> Mitra.
-- Cash platform fee is 0%. If a voucher is used, Ayo Suruh credits the
-- voucher discount to the Mitra wallet after the job is completed.
-- Depends on:
--   20260811_voucher_engine_firsttry_ayopay.sql
--   20260810_ayopay_wallet_pin_security.sql (wallet foundation already exists)

begin;

-- ---------------------------------------------------------------------------
-- 1. Payment checkout metadata.
-- ---------------------------------------------------------------------------
alter table public.payments
  add column if not exists user_voucher_id uuid references public.user_vouchers(id) on delete set null,
  add column if not exists voucher_code text,
  add column if not exists discount_amount numeric(18,2) not null default 0 check (discount_amount >= 0),
  add column if not exists payable_amount numeric(18,2),
  add column if not exists payment_method_selected_at timestamptz,
  add column if not exists cash_confirmed_at timestamptz,
  add column if not exists cash_confirmed_by uuid references public.users(id) on delete set null;

update public.payments
set payable_amount = greatest(
  0,
  coalesce(amount, 0) + coalesce(service_fee, 0) - coalesce(discount_amount, 0)
)
where payable_amount is null;

create index if not exists payments_user_voucher_idx
  on public.payments(user_voucher_id)
  where user_voucher_id is not null;

-- ---------------------------------------------------------------------------
-- 2. Voucher reservation. Reservation prevents one voucher being attached to
--    two active cash checkouts before money is actually confirmed.
-- ---------------------------------------------------------------------------
alter table public.user_vouchers
  add column if not exists reserved_at timestamptz,
  add column if not exists reserved_job_id uuid references public.jobs(id) on delete set null,
  add column if not exists reservation_reference text;

alter table public.user_vouchers
  drop constraint if exists user_vouchers_status_check;

alter table public.user_vouchers
  add constraint user_vouchers_status_check
  check (status in ('available', 'reserved', 'used', 'expired', 'cancelled'));

create unique index if not exists user_vouchers_reservation_reference_idx
  on public.user_vouchers(reservation_reference)
  where reservation_reference is not null;

-- Wallet can receive only the amount subsidized by a cash voucher. Cash job
-- earnings themselves are handed directly from Customer to Mitra.
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
      'voucher_subsidy'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Internal reservation release helper.
-- ---------------------------------------------------------------------------
create or replace function public._release_cash_voucher_for_payment(
  p_payment_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_payment public.payments%rowtype;
begin
  select p.* into v_payment
  from public.payments p
  where p.id = p_payment_id
  for update;

  if not found or v_payment.user_voucher_id is null then
    return;
  end if;

  update public.user_vouchers uv
  set status = 'available',
      reserved_at = null,
      reserved_job_id = null,
      reservation_reference = null
  where uv.id = v_payment.user_voucher_id
    and uv.status = 'reserved'
    and uv.reserved_job_id = v_payment.job_id;
end;
$$;

revoke all on function public._release_cash_voucher_for_payment(uuid)
from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Customer selects Cash and optionally reserves one eligible voucher.
-- ---------------------------------------------------------------------------
create or replace function public.prepare_cash_payment(
  p_job_id uuid,
  p_user_voucher_id uuid default null
)
returns setof public.payments
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_payment public.payments%rowtype;
  v_subtotal numeric(18,2);
  v_discount numeric(18,2) := 0;
  v_payable numeric(18,2);
  v_preview jsonb;
  v_voucher_code text;
  v_now timestamptz := timezone('utc'::text, now());
  v_reservation_reference text;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  select j.* into v_job
  from public.jobs j
  where j.id = p_job_id
    and j.customer_id = v_user_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan atau bukan milikmu.';
  end if;

  if v_job.mitra_id is null
     or v_job.status not in (
       'accepted'::public.job_status,
       'on_progress'::public.job_status
     ) then
    raise exception 'Pembayaran tunai hanya dapat dipilih setelah Mitra diterima dan sebelum pekerjaan ditutup.';
  end if;

  select p.* into v_payment
  from public.payments p
  where p.job_id = p_job_id
  for update;

  if not found then
    select coalesce(
      (
        select b.price
        from public.bids b
        where b.job_id = p_job_id
          and b.status = 'accepted'::public.bid_status
        order by b.created_at desc
        limit 1
      ),
      v_job.budget,
      0
    ) into v_subtotal;

    insert into public.payments(
      job_id,
      amount,
      service_fee,
      provider,
      payment_required,
      status,
      platform_fee_percent,
      platform_fee_amount,
      mitra_net_amount
    ) values (
      p_job_id,
      v_subtotal,
      0,
      'cash',
      true,
      'pending'::public.payment_status,
      0,
      0,
      v_subtotal
    )
    returning * into v_payment;
  end if;

  if v_payment.status = 'paid'::public.payment_status then
    raise exception 'Pembayaran pekerjaan ini sudah selesai.';
  end if;

  if v_payment.status = 'refunded'::public.payment_status then
    raise exception 'Pembayaran pekerjaan ini sudah direfund.';
  end if;

  -- Do not silently replace an active Midtrans checkout. Customer must cancel
  -- or let it expire first, preventing two simultaneously valid payment paths.
  if coalesce(v_payment.provider, '') = 'midtrans'
     and coalesce(v_payment.payment_required, false)
     and v_payment.status = 'pending'::public.payment_status
     and nullif(trim(coalesce(v_payment.order_id, '')), '') is not null
     and (v_payment.expires_at is null or v_payment.expires_at > v_now) then
    raise exception 'Masih ada checkout Midtrans aktif. Batalkan atau tunggu sampai kedaluwarsa sebelum memilih Cash.';
  end if;

  v_subtotal := greatest(coalesce(v_payment.amount, v_job.budget, 0), 0);
  if v_subtotal <= 0 then
    raise exception 'Nominal pekerjaan tidak valid untuk pembayaran.';
  end if;

  -- The whole function is transactional. If the new voucher later fails,
  -- release below is rolled back and the old reservation remains intact.
  perform public._release_cash_voucher_for_payment(v_payment.id);

  if p_user_voucher_id is not null then
    select public.preview_my_voucher(
      p_user_voucher_id,
      v_subtotal,
      p_job_id
    ) into v_preview;

    if coalesce((v_preview->>'eligible')::boolean, false) is not true then
      raise exception '%', coalesce(
        nullif(v_preview->>'message', ''),
        'Voucher belum dapat digunakan.'
      );
    end if;

    v_discount := coalesce((v_preview->>'discount_amount')::numeric, 0);
    v_voucher_code := nullif(v_preview->>'code', '');
    v_reservation_reference := 'cash:' || v_payment.id::text;

    update public.user_vouchers uv
    set status = 'reserved',
        reserved_at = v_now,
        reserved_job_id = p_job_id,
        reservation_reference = v_reservation_reference
    where uv.id = p_user_voucher_id
      and uv.user_id = v_user_id
      and uv.status = 'available';

    if not found then
      raise exception 'Voucher sudah dipakai atau sedang digunakan pada checkout lain.';
    end if;
  end if;

  v_payable := greatest(0, round(v_subtotal - v_discount, 2));

  update public.payments p
  set provider = 'cash',
      payment_required = true,
      status = 'pending'::public.payment_status,
      service_fee = 0,
      platform_fee_percent = 0,
      platform_fee_amount = 0,
      mitra_net_amount = v_subtotal,
      payment_type = 'cash',
      user_voucher_id = p_user_voucher_id,
      voucher_code = v_voucher_code,
      discount_amount = v_discount,
      payable_amount = v_payable,
      payment_method_selected_at = v_now,
      cash_confirmed_at = null,
      cash_confirmed_by = null,
      paid_at = null,
      order_id = null,
      snap_token = null,
      redirect_url = null,
      transaction_id = null,
      transaction_status = null,
      fraud_status = null,
      status_code = null,
      status_message = 'Menunggu pembayaran tunai langsung ke Mitra.',
      expires_at = null,
      raw_response = null,
      raw_notification = null
  where p.id = v_payment.id
  returning p.* into v_payment;

  return next v_payment;
end;
$$;

revoke all on function public.prepare_cash_payment(uuid, uuid)
from public, anon;
grant execute on function public.prepare_cash_payment(uuid, uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Cash confirmation is only allowed after Mitra submits completion.
-- ---------------------------------------------------------------------------
create or replace function public.confirm_cash_payment(p_job_id uuid)
returns setof public.payments
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_payment public.payments%rowtype;
  v_uv public.user_vouchers%rowtype;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  select j.* into v_job
  from public.jobs j
  where j.id = p_job_id
    and j.customer_id = v_user_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan atau bukan milikmu.';
  end if;

  if v_job.status <> 'on_progress'::public.job_status
     or v_job.progress_stage <> 'completion_submitted'::public.job_progress_stage then
    raise exception 'Konfirmasi tunai baru tersedia setelah Mitra mengajukan pekerjaan selesai.';
  end if;

  select p.* into v_payment
  from public.payments p
  where p.job_id = p_job_id
  for update;

  if not found or coalesce(v_payment.provider, '') <> 'cash' then
    raise exception 'Metode pembayaran pekerjaan ini bukan Cash.';
  end if;

  if v_payment.status = 'paid'::public.payment_status then
    return next v_payment;
    return;
  end if;

  if v_payment.status <> 'pending'::public.payment_status then
    raise exception 'Pembayaran tunai ini tidak dapat dikonfirmasi.';
  end if;

  if v_payment.user_voucher_id is not null then
    select uv.* into v_uv
    from public.user_vouchers uv
    where uv.id = v_payment.user_voucher_id
      and uv.user_id = v_user_id
    for update;

    if not found
       or v_uv.status <> 'reserved'
       or v_uv.reserved_job_id <> p_job_id
       or v_uv.reservation_reference <> 'cash:' || v_payment.id::text then
      raise exception 'Reservasi voucher pembayaran tidak valid.';
    end if;

    update public.user_vouchers
    set status = 'used',
        used_at = v_now,
        used_job_id = p_job_id,
        discount_amount = v_payment.discount_amount,
        redemption_reference = 'cash:' || v_payment.id::text,
        reserved_at = null,
        reserved_job_id = null,
        reservation_reference = null
    where id = v_payment.user_voucher_id;
  end if;

  update public.payments p
  set status = 'paid'::public.payment_status,
      paid_at = v_now,
      cash_confirmed_at = v_now,
      cash_confirmed_by = v_user_id,
      transaction_status = 'settlement',
      status_code = '200',
      status_message = 'Pembayaran tunai dikonfirmasi Customer.'
  where p.id = v_payment.id
  returning p.* into v_payment;

  if v_job.mitra_id is not null then
    perform public.enqueue_notification(
      p_user_id => v_job.mitra_id,
      p_title => 'Pembayaran Tunai Dikonfirmasi',
      p_body => 'Customer mengonfirmasi pembayaran tunai sebesar ' ||
        trim(to_char(coalesce(v_payment.payable_amount, v_payment.amount, 0), 'FM999G999G999G999G990')) ||
        ' untuk pekerjaanmu.',
      p_type => 'cash_payment_confirmed',
      p_job_id => p_job_id,
      p_actor_id => v_user_id,
      p_data => jsonb_build_object(
        'payment_id', v_payment.id,
        'provider', 'cash',
        'amount', v_payment.payable_amount
      )
    );
  end if;

  return next v_payment;
end;
$$;

revoke all on function public.confirm_cash_payment(uuid)
from public, anon;
grant execute on function public.confirm_cash_payment(uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Cash does not block Mitra from starting the accepted job. Online payment
--    still keeps the previous mandatory-payment guard.
-- ---------------------------------------------------------------------------
create or replace function public.start_assigned_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_required boolean := false;
  v_payment_status public.payment_status;
  v_provider text;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select p.payment_required, p.status, p.provider
    into v_payment_required, v_payment_status, v_provider
  from public.payments p
  where p.job_id = p_job_id;

  if coalesce(v_payment_required, false)
     and coalesce(v_provider, 'midtrans') <> 'cash'
     and coalesce(v_payment_status <> 'paid'::public.payment_status, true) then
    raise exception 'Customer belum menyelesaikan pembayaran online.';
  end if;

  update public.jobs
  set status = 'on_progress'::public.job_status,
      progress_stage = 'heading_to_location'::public.job_progress_stage
  where id = p_job_id
    and mitra_id = auth.uid()
    and status = 'accepted'::public.job_status;

  if not found then
    raise exception 'Pekerjaan tidak dapat dimulai oleh akun ini.';
  end if;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description
  ) values (
    p_job_id,
    'on_progress'::public.job_status,
    'heading_to_location'::public.job_progress_stage,
    'Mitra sedang menuju lokasi pekerjaan.'
  );
end;
$$;

revoke all on function public.start_assigned_job(uuid) from public;
grant execute on function public.start_assigned_job(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Defense in depth: a cash job cannot become completed before Customer
--    confirms that cash was actually handed to the Mitra.
-- ---------------------------------------------------------------------------
create or replace function public.guard_cash_job_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed'::public.job_status
     and old.status is distinct from new.status
     and exists (
       select 1
       from public.payments p
       where p.job_id = new.id
         and p.provider = 'cash'
         and p.status <> 'paid'::public.payment_status
     ) then
    raise exception 'Pembayaran tunai harus dikonfirmasi sebelum pekerjaan ditutup.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_cash_job_completion on public.jobs;
create trigger trg_guard_cash_job_completion
before update of status on public.jobs
for each row execute function public.guard_cash_job_completion();

-- Keep the existing review/legacy earning behavior, but add an explicit guard
-- to the public completion RPC so the UI receives a meaningful error too.
create or replace function public.confirm_job_completion(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_status public.job_status;
  v_progress public.job_progress_stage;
  v_payment_provider text;
  v_payment_status public.payment_status;
begin
  select j.customer_id, j.status, j.progress_stage
  into v_customer_id, v_status, v_progress
  from public.jobs j
  where j.id = p_job_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan.';
  end if;

  if auth.uid() is null or auth.uid() <> v_customer_id then
    raise exception 'Hanya pemilik pekerjaan yang dapat mengonfirmasi.';
  end if;

  if v_status <> 'on_progress'::public.job_status
     or v_progress <> 'completion_submitted'::public.job_progress_stage then
    raise exception 'Mitra belum mengajukan pekerjaan selesai.';
  end if;

  select p.provider, p.status
  into v_payment_provider, v_payment_status
  from public.payments p
  where p.job_id = p_job_id;

  if coalesce(v_payment_provider, '') = 'cash'
     and coalesce(v_payment_status <> 'paid'::public.payment_status, true) then
    raise exception 'Konfirmasi pembayaran tunai terlebih dahulu.';
  end if;

  update public.jobs
  set status = 'completed'::public.job_status
  where id = p_job_id;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description
  ) values (
    p_job_id,
    'completed'::public.job_status,
    'completion_submitted'::public.job_progress_stage,
    'Customer mengonfirmasi bahwa pekerjaan telah selesai.'
  );

  perform public.ensure_completed_job_earning(p_job_id);
end;
$$;

revoke all on function public.confirm_job_completion(uuid) from public;
grant execute on function public.confirm_job_completion(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Cancelled cash checkout releases its reserved voucher.
-- ---------------------------------------------------------------------------
create or replace function public.release_cash_checkout_on_job_cancel()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_payment_id uuid;
begin
  if new.status = 'cancelled'::public.job_status
     and old.status is distinct from new.status then
    select p.id into v_payment_id
    from public.payments p
    where p.job_id = new.id
      and p.provider = 'cash'
      and p.status = 'pending'::public.payment_status
    for update;

    if v_payment_id is not null then
      perform public._release_cash_voucher_for_payment(v_payment_id);

      update public.payments
      set status = 'cancelled'::public.payment_status,
          status_message = 'Pekerjaan dibatalkan sebelum pembayaran tunai selesai.'
      where id = v_payment_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_release_cash_checkout_on_job_cancel on public.jobs;
create trigger trg_release_cash_checkout_on_job_cancel
after update of status on public.jobs
for each row execute function public.release_cash_checkout_on_job_cancel();

-- ---------------------------------------------------------------------------
-- 9. Wallet economics.
-- Online payment: keep current platform fee/net-earning behavior.
-- Cash: customer already hands cash to Mitra, so DO NOT duplicate full earning
-- into wallet. Only the voucher discount is credited as Ayo Suruh subsidy.
-- ---------------------------------------------------------------------------
create or replace function public.sync_job_wallet_credit(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mitra_id uuid;
  v_job_status public.job_status;
  v_payment_status public.payment_status;
  v_provider text;
  v_gross_amount numeric;
  v_discount numeric;
  v_fee_percent numeric;
  v_fee_amount numeric;
  v_net_amount numeric;
begin
  select
    j.mitra_id,
    j.status,
    p.status,
    coalesce(p.provider, 'midtrans'),
    coalesce(p.amount, j.budget, 0),
    coalesce(p.discount_amount, 0),
    coalesce(p.platform_fee_percent, public.current_platform_fee_percent()),
    coalesce(
      p.platform_fee_amount,
      round(coalesce(p.amount, j.budget, 0) * public.current_platform_fee_percent() / 100.0)
    ),
    coalesce(
      p.mitra_net_amount,
      greatest(
        coalesce(p.amount, j.budget, 0) -
          round(coalesce(p.amount, j.budget, 0) * public.current_platform_fee_percent() / 100.0),
        0
      )
    )
  into
    v_mitra_id,
    v_job_status,
    v_payment_status,
    v_provider,
    v_gross_amount,
    v_discount,
    v_fee_percent,
    v_fee_amount,
    v_net_amount
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
    if coalesce(v_discount, 0) <= 0 then
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
        'platform_fee_percent', 0
      )
    )
    on conflict (reference_key) do nothing;
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
    'Pendapatan bersih pekerjaan setelah komisi platform ' ||
      trim(to_char(v_fee_percent, 'FM999990.00')) || '%. Menunggu masa hold 1 hari.',
    jsonb_build_object(
      'gross_amount', v_gross_amount,
      'platform_fee_percent', v_fee_percent,
      'platform_fee_amount', v_fee_amount,
      'mitra_net_amount', v_net_amount
    )
  )
  on conflict (reference_key) do nothing;
end;
$$;

revoke all on function public.sync_job_wallet_credit(uuid) from public;

-- ---------------------------------------------------------------------------
-- 10. Payment history shows what Customer actually paid after voucher.
-- Return signature intentionally remains identical to Stage 2.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_payment_history()
returns table (
  payment_id uuid,
  job_id uuid,
  job_title text,
  job_status text,
  amount numeric,
  service_fee numeric,
  total numeric,
  payment_status text,
  payment_type text,
  order_id text,
  paid_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  mitra_name text,
  mitra_avatar_url text,
  attempt_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  return query
  select
    p.id,
    j.id,
    j.title,
    j.status::text,
    p.amount,
    p.service_fee,
    coalesce(
      p.payable_amount,
      greatest(
        0,
        coalesce(p.amount, 0) + coalesce(p.service_fee, 0) - coalesce(p.discount_amount, 0)
      )
    ),
    p.status::text,
    p.payment_type,
    p.order_id,
    p.paid_at,
    p.created_at,
    p.updated_at,
    coalesce(mu.fullname, 'Mitra Ayo Suruh'),
    mu.avatar_url,
    (
      select count(*)
      from public.payment_attempts pa
      where pa.payment_id = p.id
    )
  from public.payments p
  join public.jobs j on j.id = p.job_id
  left join public.users mu on mu.id = j.mitra_id
  where j.customer_id = auth.uid()
  order by coalesce(p.paid_at, p.updated_at, p.created_at) desc;
end;
$$;

revoke all on function public.get_my_payment_history() from public;
grant execute on function public.get_my_payment_history() to authenticated;

commit;
