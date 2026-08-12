-- AYO SURUH - LAUNCH GROWTH INCENTIVES
-- 1) Customer baru: pekerjaan pertama mendapat Priority First Job selama 12 jam.
-- 2) Mitra baru: 0% platform commission pada pekerjaan online pertama yang
--    berhasil selesai + pembayaran valid. Bonus dicadangkan agar tidak bisa
--    dipakai paralel pada beberapa job, dan baru dianggap terpakai setelah
--    job completed + payment paid.
--
-- Voucher TIDAK diubah oleh migration ini. Cash checkout juga tetap mengikuti
-- economics sementara yang sudah ada pada 20260811_cash_payment_voucher_checkout.sql.

begin;

-- Launch switches live in the existing singleton business_settings row so the
-- program can be disabled later without a new app release or destructive data
-- migration.
alter table public.business_settings
  add column if not exists first_job_bonus_enabled boolean not null default true,
  add column if not exists first_job_priority_enabled boolean not null default true,
  add column if not exists first_job_priority_hours integer not null default 12
    check (first_job_priority_hours between 1 and 72);

-- ---------------------------------------------------------------------------
-- 1. Customer first-job priority state.
-- ---------------------------------------------------------------------------
alter table public.users
  add column if not exists first_job_priority_claimed_at timestamptz,
  add column if not exists first_job_priority_job_id uuid;

alter table public.jobs
  add column if not exists is_first_job_priority boolean not null default false,
  add column if not exists priority_until timestamptz;

create index if not exists jobs_first_job_priority_idx
  on public.jobs(is_first_job_priority desc, priority_until desc, created_at desc)
  where status in ('posted'::public.job_status, 'waiting_bid'::public.job_status);

-- Existing customers are considered to have consumed the launch benefit if
-- they already published any non-draft job before this migration.
with first_existing_job as (
  select distinct on (j.customer_id)
    j.customer_id,
    j.id,
    j.created_at
  from public.jobs j
  where j.customer_id is not null
    and j.status <> 'draft'::public.job_status
  order by j.customer_id, j.created_at asc, j.id asc
)
update public.users u
set first_job_priority_claimed_at = coalesce(
      u.first_job_priority_claimed_at,
      f.created_at,
      timezone('utc'::text, now())
    ),
    first_job_priority_job_id = coalesce(u.first_job_priority_job_id, f.id)
from first_existing_job f
where u.id = f.customer_id
  and u.first_job_priority_job_id is null;

create or replace function public.apply_first_job_priority()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_claimed_job_id uuid;
  v_now timestamptz := timezone('utc'::text, now());
  v_priority_enabled boolean := true;
  v_priority_hours integer := 12;
begin
  if new.customer_id is null
     or new.status not in (
       'posted'::public.job_status,
       'waiting_bid'::public.job_status
     ) then
    return new;
  end if;

  select
    coalesce(bs.first_job_priority_enabled, true),
    coalesce(bs.first_job_priority_hours, 12)
  into v_priority_enabled, v_priority_hours
  from public.business_settings bs
  where bs.id = 1;

  if not coalesce(v_priority_enabled, true) then
    return new;
  end if;

  -- Serialize claims per customer so two simultaneously-created jobs cannot
  -- both receive the one-time priority benefit.
  perform pg_advisory_xact_lock(
    hashtextextended('ayo:first_job_priority:' || new.customer_id::text, 0)
  );

  select u.first_job_priority_job_id
  into v_claimed_job_id
  from public.users u
  where u.id = new.customer_id
  for update;

  if v_claimed_job_id is null then
    new.is_first_job_priority := true;
    new.priority_until := coalesce(new.priority_until, v_now + make_interval(hours => v_priority_hours));

    update public.users
    set first_job_priority_claimed_at = v_now,
        first_job_priority_job_id = new.id
    where id = new.customer_id;
  elsif v_claimed_job_id = new.id then
    new.is_first_job_priority := true;
    new.priority_until := coalesce(new.priority_until, v_now + make_interval(hours => v_priority_hours));
  else
    new.is_first_job_priority := false;
    new.priority_until := null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_apply_first_job_priority on public.jobs;
create trigger trg_apply_first_job_priority
before insert or update of status
on public.jobs
for each row execute function public.apply_first_job_priority();

-- ---------------------------------------------------------------------------
-- 2. Mitra one-time first commissionable job bonus state.
-- ---------------------------------------------------------------------------
alter table public.mitras
  add column if not exists first_job_bonus_reserved_job_id uuid,
  add column if not exists first_job_bonus_used_job_id uuid,
  add column if not exists first_job_bonus_used_at timestamptz;

-- Snapshot/audit fields on payment. platform_fee_percent remains the EFFECTIVE
-- rate for the transaction. base_platform_fee_percent stores the normal rate
-- before the one-time new-Partner bonus.
alter table public.payments
  add column if not exists base_platform_fee_percent numeric(5,2),
  add column if not exists first_job_bonus_applied boolean not null default false,
  add column if not exists first_job_bonus_amount numeric(18,2) not null default 0;

alter table public.payment_attempts
  add column if not exists base_platform_fee_percent numeric(5,2),
  add column if not exists first_job_bonus_applied boolean not null default false,
  add column if not exists first_job_bonus_amount numeric(18,2) not null default 0;

-- Existing Mitra who already completed a paid job must not receive a fresh
-- first-job bonus merely because this migration was introduced later.
with first_existing_success as (
  select distinct on (j.mitra_id)
    j.mitra_id,
    j.id as job_id,
    coalesce(p.paid_at, p.updated_at, p.created_at, j.created_at) as used_at
  from public.jobs j
  left join public.payments p on p.job_id = j.id
  where j.mitra_id is not null
    and j.status = 'completed'::public.job_status
  order by j.mitra_id,
           coalesce(p.paid_at, p.updated_at, p.created_at, j.created_at) asc,
           j.id asc
)
update public.mitras m
set first_job_bonus_used_job_id = coalesce(m.first_job_bonus_used_job_id, s.job_id),
    first_job_bonus_used_at = coalesce(m.first_job_bonus_used_at, s.used_at)
from first_existing_success s
where m.id = s.mitra_id
  and m.first_job_bonus_used_job_id is null;

create or replace function public._reserve_mitra_first_job_bonus(
  p_job_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_mitra_id uuid;
  v_reserved_job_id uuid;
  v_used_job_id uuid;
  v_bonus_enabled boolean := true;
begin
  select j.mitra_id
  into v_mitra_id
  from public.jobs j
  where j.id = p_job_id;

  if v_mitra_id is null then
    return false;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('ayo:mitra_first_job_bonus:' || v_mitra_id::text, 0)
  );

  select
    m.first_job_bonus_reserved_job_id,
    m.first_job_bonus_used_job_id
  into v_reserved_job_id, v_used_job_id
  from public.mitras m
  where m.id = v_mitra_id
  for update;

  if not found then
    return false;
  end if;

  -- Keep the historical economics immutable for the job that actually used
  -- the benefit, even if the payment row is updated later.
  if v_used_job_id = p_job_id then
    return true;
  end if;

  if v_used_job_id is not null then
    return false;
  end if;

  if v_reserved_job_id = p_job_id then
    return true;
  end if;

  select coalesce(bs.first_job_bonus_enabled, true)
  into v_bonus_enabled
  from public.business_settings bs
  where bs.id = 1;

  if not coalesce(v_bonus_enabled, true) then
    return false;
  end if;

  if v_reserved_job_id is null then
    update public.mitras
    set first_job_bonus_reserved_job_id = p_job_id
    where id = v_mitra_id;
    return true;
  end if;

  return false;
end;
$$;

revoke all on function public._reserve_mitra_first_job_bonus(uuid)
from public, anon, authenticated;

create or replace function public._release_mitra_first_job_bonus(
  p_job_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  update public.mitras m
  set first_job_bonus_reserved_job_id = null
  where m.first_job_bonus_reserved_job_id = p_job_id
    and m.first_job_bonus_used_job_id is null;
end;
$$;

revoke all on function public._release_mitra_first_job_bonus(uuid)
from public, anon, authenticated;

create or replace function public._finalize_mitra_first_job_bonus(
  p_job_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_mitra_id uuid;
  v_job_status public.job_status;
  v_payment_status public.payment_status;
  v_bonus_applied boolean;
begin
  select
    j.mitra_id,
    j.status,
    p.status,
    coalesce(p.first_job_bonus_applied, false)
  into
    v_mitra_id,
    v_job_status,
    v_payment_status,
    v_bonus_applied
  from public.jobs j
  join public.payments p on p.job_id = j.id
  where j.id = p_job_id;

  if not found
     or v_mitra_id is null
     or v_job_status <> 'completed'::public.job_status
     or v_payment_status <> 'paid'::public.payment_status
     or not v_bonus_applied then
    return;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('ayo:mitra_first_job_bonus:' || v_mitra_id::text, 0)
  );

  update public.mitras m
  set first_job_bonus_used_job_id = p_job_id,
      first_job_bonus_used_at = coalesce(
        m.first_job_bonus_used_at,
        timezone('utc'::text, now())
      ),
      first_job_bonus_reserved_job_id = null
  where m.id = v_mitra_id
    and m.first_job_bonus_used_job_id is null
    and m.first_job_bonus_reserved_job_id = p_job_id;
end;
$$;

revoke all on function public._finalize_mitra_first_job_bonus(uuid)
from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Payment economics with one-time Partner bonus.
-- Cash remains intentionally untouched: current Cash checkout already uses
-- 0% platform fee while the money moves Customer -> Mitra directly.
-- ---------------------------------------------------------------------------
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

-- Existing trigger already has the right INSERT/UPDATE coverage, recreate it
-- explicitly so this migration is self-contained.
drop trigger if exists trg_set_payment_economics on public.payments;
create trigger trg_set_payment_economics
before insert or update of amount, platform_fee_percent, provider, payment_required
on public.payments
for each row execute function public.set_payment_economics();

create or replace function public.set_payment_attempt_economics()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_parent_base_percent numeric;
  v_parent_effective_percent numeric;
  v_parent_bonus boolean;
  v_parent_bonus_amount numeric;
  v_gross numeric;
begin
  select
    coalesce(p.base_platform_fee_percent, public.current_platform_fee_percent()),
    coalesce(p.platform_fee_percent, public.current_platform_fee_percent()),
    coalesce(p.first_job_bonus_applied, false),
    coalesce(p.first_job_bonus_amount, 0)
  into
    v_parent_base_percent,
    v_parent_effective_percent,
    v_parent_bonus,
    v_parent_bonus_amount
  from public.payments p
  where p.id = new.payment_id;

  v_gross := greatest(coalesce(new.amount, 0), 0);

  new.base_platform_fee_percent := coalesce(
    v_parent_base_percent,
    public.current_platform_fee_percent()
  );
  new.first_job_bonus_applied := coalesce(v_parent_bonus, false);
  new.first_job_bonus_amount := case
    when coalesce(v_parent_bonus, false)
      then round(v_gross * new.base_platform_fee_percent / 100.0, 2)
    else 0
  end;
  new.platform_fee_percent := coalesce(
    v_parent_effective_percent,
    public.current_platform_fee_percent()
  );
  new.platform_fee_amount := round(
    v_gross * new.platform_fee_percent / 100.0,
    2
  );
  new.mitra_net_amount := greatest(v_gross - new.platform_fee_amount, 0);
  return new;
end;
$$;

drop trigger if exists trg_set_payment_attempt_economics
on public.payment_attempts;
create trigger trg_set_payment_attempt_economics
before insert or update of amount, platform_fee_percent, payment_id
on public.payment_attempts
for each row execute function public.set_payment_attempt_economics();

-- Fill audit fields for old transactions without changing their historical
-- effective fee/net values.
update public.payments
set base_platform_fee_percent = coalesce(
      base_platform_fee_percent,
      case
        when platform_fee_percent > 0 then platform_fee_percent
        else public.current_platform_fee_percent()
      end
    )
where base_platform_fee_percent is null;

update public.payment_attempts pa
set base_platform_fee_percent = coalesce(
      pa.base_platform_fee_percent,
      p.base_platform_fee_percent,
      public.current_platform_fee_percent()
    ),
    first_job_bonus_applied = coalesce(pa.first_job_bonus_applied, false),
    first_job_bonus_amount = coalesce(pa.first_job_bonus_amount, 0)
from public.payments p
where p.id = pa.payment_id
  and pa.base_platform_fee_percent is null;

-- ---------------------------------------------------------------------------
-- 4. Bonus lifecycle triggers.
-- ---------------------------------------------------------------------------
create or replace function public.trg_finalize_or_release_first_job_bonus()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_table_name = 'jobs' then
    if new.status = 'cancelled'::public.job_status
       and old.status is distinct from new.status then
      perform public._release_mitra_first_job_bonus(new.id);
    else
      perform public._finalize_mitra_first_job_bonus(new.id);
    end if;
    return new;
  end if;

  if tg_table_name = 'payments' then
    if new.status in (
         'cancelled'::public.payment_status,
         'refunded'::public.payment_status
       )
       and old.status is distinct from new.status then
      perform public._release_mitra_first_job_bonus(new.job_id);
    else
      perform public._finalize_mitra_first_job_bonus(new.job_id);
    end if;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_first_job_bonus_on_job_status on public.jobs;
create trigger trg_first_job_bonus_on_job_status
after update of status on public.jobs
for each row execute function public.trg_finalize_or_release_first_job_bonus();

drop trigger if exists trg_first_job_bonus_on_payment_status on public.payments;
create trigger trg_first_job_bonus_on_payment_status
after insert or update of status on public.payments
for each row execute function public.trg_finalize_or_release_first_job_bonus();

-- ---------------------------------------------------------------------------
-- 5. Wallet credit keeps Cash voucher behavior unchanged and adds a clear
-- description for the first successful commission-free online job.
-- ---------------------------------------------------------------------------
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

  -- Existing Cash + voucher behavior is deliberately preserved.
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

-- ---------------------------------------------------------------------------
-- 6. Read-only benefit status for the Mitra UI.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_growth_benefits()
returns table (
  first_job_bonus_available boolean,
  first_job_bonus_reserved boolean,
  first_job_bonus_reserved_job_id uuid,
  first_job_bonus_used boolean,
  first_job_bonus_used_job_id uuid,
  first_job_bonus_used_at timestamptz,
  normal_platform_fee_percent numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  return query
  select
    m.first_job_bonus_used_job_id is null
      and m.first_job_bonus_reserved_job_id is null
      and coalesce(
        (select bs.first_job_bonus_enabled
         from public.business_settings bs
         where bs.id = 1),
        true
      ),
    m.first_job_bonus_used_job_id is null
      and m.first_job_bonus_reserved_job_id is not null,
    m.first_job_bonus_reserved_job_id,
    m.first_job_bonus_used_job_id is not null,
    m.first_job_bonus_used_job_id,
    m.first_job_bonus_used_at,
    public.current_platform_fee_percent()
  from public.mitras m
  where m.id = auth.uid();
end;
$$;

revoke all on function public.get_my_growth_benefits() from public, anon;
grant execute on function public.get_my_growth_benefits() to authenticated;

commit;
