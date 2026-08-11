-- AYO SURUH - AYOPAY ACCOUNT FOUNDATION
-- Generic AyoPay account/ledger for Customer and Mitra accounts.
-- Depends on 20260810_ayopay_wallet_pin_security.sql because activation requires a PIN.
-- This stage intentionally does NOT enable online top up yet. It creates the one-time
-- activation record and secure ledger that future vouchers/top-up/payment methods can use.

begin;

create table if not exists public.ayopay_accounts (
  user_id uuid primary key references public.users(id) on delete cascade,
  status text not null default 'inactive'
    check (status in ('inactive', 'active', 'suspended')),
  balance numeric(18,2) not null default 0 check (balance >= 0),
  activated_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create table if not exists public.ayopay_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null,
  amount numeric(18,2) not null check (amount <> 0),
  balance_after numeric(18,2) not null check (balance_after >= 0),
  entry_type text not null check (
    entry_type in (
      'activation_bonus',
      'voucher_credit',
      'topup',
      'job_payment',
      'refund',
      'admin_adjustment',
      'transfer_in',
      'transfer_out'
    )
  ),
  reference_key text not null unique,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists ayopay_ledger_user_created_idx
  on public.ayopay_ledger(user_id, created_at desc);

create index if not exists ayopay_ledger_job_idx
  on public.ayopay_ledger(job_id)
  where job_id is not null;

create or replace function public.touch_ayopay_account_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_ayopay_account_updated_at on public.ayopay_accounts;
create trigger trg_touch_ayopay_account_updated_at
before update on public.ayopay_accounts
for each row execute function public.touch_ayopay_account_updated_at();

alter table public.ayopay_accounts enable row level security;
alter table public.ayopay_ledger enable row level security;

revoke all on public.ayopay_accounts from anon, authenticated;
revoke all on public.ayopay_ledger from anon, authenticated;

grant select on public.ayopay_accounts to authenticated;
grant select on public.ayopay_ledger to authenticated;

drop policy if exists "ayo_ayopay_account_read_own" on public.ayopay_accounts;
create policy "ayo_ayopay_account_read_own"
on public.ayopay_accounts for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "ayo_ayopay_ledger_read_own" on public.ayopay_ledger;
create policy "ayo_ayopay_ledger_read_own"
on public.ayopay_ledger for select
to authenticated
using (user_id = auth.uid());

-- Internal atomic ledger writer. Future voucher/top-up/payment migrations should call
-- this function instead of mutating balance directly.
create or replace function public._ayopay_apply_entry(
  p_user_id uuid,
  p_amount numeric,
  p_entry_type text,
  p_reference_key text,
  p_description text default null,
  p_job_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_account public.ayopay_accounts%rowtype;
  v_new_balance numeric(18,2);
  v_existing public.ayopay_ledger%rowtype;
begin
  if p_user_id is null then
    raise exception 'User AyoPay tidak valid.';
  end if;
  if p_amount is null or p_amount = 0 then
    raise exception 'Nominal transaksi AyoPay tidak valid.';
  end if;
  if trim(coalesce(p_reference_key, '')) = '' then
    raise exception 'Reference transaksi AyoPay wajib diisi.';
  end if;
  if p_entry_type not in (
    'activation_bonus', 'voucher_credit', 'topup', 'job_payment',
    'refund', 'admin_adjustment', 'transfer_in', 'transfer_out'
  ) then
    raise exception 'Jenis transaksi AyoPay tidak didukung.';
  end if;

  select * into v_existing
  from public.ayopay_ledger
  where reference_key = p_reference_key;

  if found then
    if v_existing.user_id <> p_user_id then
      raise exception 'Reference transaksi AyoPay sudah digunakan.';
    end if;
    return jsonb_build_object(
      'ok', true,
      'duplicate', true,
      'ledger_id', v_existing.id,
      'balance', v_existing.balance_after
    );
  end if;

  select * into v_account
  from public.ayopay_accounts
  where user_id = p_user_id
  for update;

  if not found or v_account.status <> 'active' then
    raise exception 'AyoPay belum aktif.';
  end if;

  v_new_balance := round(v_account.balance + p_amount, 2);
  if v_new_balance < 0 then
    raise exception 'Saldo AyoPay tidak mencukupi.';
  end if;

  update public.ayopay_accounts
  set balance = v_new_balance
  where user_id = p_user_id;

  insert into public.ayopay_ledger(
    user_id,
    job_id,
    amount,
    balance_after,
    entry_type,
    reference_key,
    description,
    metadata
  ) values (
    p_user_id,
    p_job_id,
    p_amount,
    v_new_balance,
    p_entry_type,
    trim(p_reference_key),
    nullif(trim(coalesce(p_description, '')), ''),
    coalesce(p_metadata, '{}'::jsonb)
  ) returning * into v_existing;

  return jsonb_build_object(
    'ok', true,
    'duplicate', false,
    'ledger_id', v_existing.id,
    'balance', v_new_balance
  );
end;
$$;

revoke all on function public._ayopay_apply_entry(uuid, numeric, text, text, text, uuid, jsonb)
from public, anon, authenticated;

create or replace function public.activate_ayopay()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_account public.ayopay_accounts%rowtype;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1
    from public.wallet_security ws
    where ws.user_id = v_user_id
  ) then
    return jsonb_build_object('ok', false, 'code', 'pin_required');
  end if;

  select * into v_account
  from public.ayopay_accounts
  where user_id = v_user_id
  for update;

  if found and v_account.status = 'suspended' then
    return jsonb_build_object('ok', false, 'code', 'suspended');
  end if;

  if found and v_account.status = 'active' then
    return jsonb_build_object(
      'ok', true,
      'code', 'already_active',
      'balance', v_account.balance,
      'activated_at', v_account.activated_at
    );
  end if;

  insert into public.ayopay_accounts(
    user_id,
    status,
    balance,
    activated_at,
    created_at,
    updated_at
  ) values (
    v_user_id,
    'active',
    0,
    v_now,
    v_now,
    v_now
  )
  on conflict (user_id) do update
  set status = 'active',
      activated_at = coalesce(public.ayopay_accounts.activated_at, excluded.activated_at),
      updated_at = v_now;

  select * into v_account
  from public.ayopay_accounts
  where user_id = v_user_id;

  return jsonb_build_object(
    'ok', true,
    'code', 'activated',
    'balance', v_account.balance,
    'activated_at', v_account.activated_at
  );
end;
$$;

revoke all on function public.activate_ayopay() from public, anon;
grant execute on function public.activate_ayopay() to authenticated;

create or replace function public.get_my_ayopay_summary()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_account public.ayopay_accounts%rowtype;
  v_has_pin boolean;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  select exists(
    select 1 from public.wallet_security ws where ws.user_id = v_user_id
  ) into v_has_pin;

  select * into v_account
  from public.ayopay_accounts
  where user_id = v_user_id;

  if not found then
    return jsonb_build_object(
      'is_active', false,
      'status', 'inactive',
      'balance', 0,
      'has_pin', v_has_pin,
      'activated_at', null,
      'topup_enabled', false
    );
  end if;

  return jsonb_build_object(
    'is_active', v_account.status = 'active',
    'status', v_account.status,
    'balance', v_account.balance,
    'has_pin', v_has_pin,
    'activated_at', v_account.activated_at,
    'topup_enabled', false
  );
end;
$$;

revoke all on function public.get_my_ayopay_summary() from public, anon;
grant execute on function public.get_my_ayopay_summary() to authenticated;

create or replace function public.get_my_ayopay_ledger(p_limit integer default 30)
returns setof public.ayopay_ledger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  return query
  select l.*
  from public.ayopay_ledger l
  where l.user_id = auth.uid()
  order by l.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
end;
$$;

revoke all on function public.get_my_ayopay_ledger(integer) from public, anon;
grant execute on function public.get_my_ayopay_ledger(integer) to authenticated;

-- Super Admin adjustment is useful for customer support and sandbox QA. It is also
-- a safe building block to verify ledger behaviour before voucher credit is added.
create or replace function public.admin_adjust_ayopay_balance(
  p_user_id uuid,
  p_amount numeric,
  p_reason text,
  p_reference_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_reference text;
begin
  if v_actor is null then
    raise exception 'Admin belum login.';
  end if;

  if not exists (
    select 1
    from public.admin_users a
    where a.user_id = v_actor
      and a.is_active = true
      and a.admin_role = 'super_admin'
  ) then
    raise exception 'Hanya Super Admin yang dapat menyesuaikan saldo AyoPay.';
  end if;

  if p_amount is null or p_amount = 0 or abs(p_amount) > 10000000 then
    raise exception 'Nominal penyesuaian harus antara -Rp10.000.000 dan Rp10.000.000, selain nol.';
  end if;

  if trim(coalesce(p_reason, '')) = '' then
    raise exception 'Alasan penyesuaian wajib diisi.';
  end if;

  v_reference := coalesce(
    nullif(trim(coalesce(p_reference_key, '')), ''),
    'admin-adjust:' || gen_random_uuid()::text
  );

  return public._ayopay_apply_entry(
    p_user_id,
    p_amount,
    'admin_adjustment',
    v_reference,
    trim(p_reason),
    null,
    jsonb_build_object('actor_id', v_actor)
  );
end;
$$;

revoke all on function public.admin_adjust_ayopay_balance(uuid, numeric, text, text)
from public, anon;
grant execute on function public.admin_adjust_ayopay_balance(uuid, numeric, text, text)
to authenticated;

commit;
