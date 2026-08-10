-- AYO SURUH - AYOPAY / MITRA WALLET PIN SECURITY
-- Protects payout and payout-destination mutations with a server-verified 6 digit PIN.
-- PIN material is HMAC-SHA256-peppered, then bcrypt-hashed; the project pepper lives in Supabase Vault.

begin;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists supabase_vault with schema vault;

-- A project-specific pepper makes an offline PIN hash dump materially harder to brute force.
do $$
begin
  if not exists (
    select 1
    from vault.decrypted_secrets
    where name = 'wallet_pin_pepper'
  ) then
    perform vault.create_secret(
      gen_random_uuid()::text || gen_random_uuid()::text,
      'wallet_pin_pepper',
      'Ayo Suruh wallet PIN project pepper. Do not expose to client roles.'
    );
  end if;
end;
$$;

create table if not exists public.wallet_security (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pin_hash text not null,
  failed_attempts integer not null default 0 check (failed_attempts >= 0),
  locked_until timestamptz,
  pin_changed_at timestamptz not null default timezone('utc'::text, now()),
  last_verified_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.wallet_security enable row level security;
revoke all on public.wallet_security from anon, authenticated;

-- Extend the existing security audit taxonomy without exposing PIN contents.
alter table public.security_audit_events
  drop constraint if exists security_audit_events_event_type_check;

alter table public.security_audit_events
  add constraint security_audit_events_event_type_check check (
    event_type in (
      'account_deactivated',
      'account_reactivated',
      'account_deleted',
      'admin_access_granted',
      'admin_access_updated',
      'admin_access_revoked',
      'wallet_pin_created',
      'wallet_pin_changed',
      'wallet_pin_reset',
      'wallet_pin_locked',
      'wallet_bank_added',
      'wallet_bank_updated',
      'wallet_bank_deleted',
      'wallet_bank_default_changed',
      'wallet_payout_requested',
      'wallet_payout_cancelled'
    )
  );

create or replace function public._wallet_pin_pepper()
returns text
language plpgsql
security definer
set search_path = vault, pg_catalog
as $$
declare
  v_pepper text;
begin
  select decrypted_secret
  into v_pepper
  from vault.decrypted_secrets
  where name = 'wallet_pin_pepper'
  limit 1;

  if coalesce(v_pepper, '') = '' then
    raise exception 'Konfigurasi keamanan dompet belum tersedia.';
  end if;
  return v_pepper;
end;
$$;

revoke all on function public._wallet_pin_pepper() from public, anon, authenticated;

create or replace function public._wallet_validate_pin_format(p_pin text)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(p_pin, '') ~ '^[0-9]{6}$';
$$;

revoke all on function public._wallet_validate_pin_format(text) from public, anon, authenticated;

create or replace function public._wallet_validate_pin_strength(p_pin text)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select public._wallet_validate_pin_format(p_pin)
    and p_pin not in (
      '000000', '111111', '222222', '333333', '444444',
      '555555', '666666', '777777', '888888', '999999',
      '123456', '654321', '112233', '121212', '123123', '101010'
    );
$$;

revoke all on function public._wallet_validate_pin_strength(text) from public, anon, authenticated;

-- Internal checker. It deliberately RETURNS failure instead of raising so failed-attempt
-- counters are committed instead of being rolled back with an exception.
create or replace function public._wallet_check_pin(
  p_user_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = extensions, pg_catalog, public, vault
as $$
declare
  v_row public.wallet_security%rowtype;
  v_now timestamptz := timezone('utc'::text, now());
  v_attempts integer;
  v_locked_until timestamptz;
  v_pepper text;
begin
  select *
  into v_row
  from public.wallet_security
  where user_id = p_user_id
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'pin_not_set');
  end if;

  if v_row.locked_until is not null and v_row.locked_until > v_now then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_locked',
      'locked_until', v_row.locked_until,
      'attempts_remaining', 0
    );
  end if;

  -- A finished lock starts a clean attempt window.
  if v_row.locked_until is not null and v_row.locked_until <= v_now then
    update public.wallet_security
    set failed_attempts = 0,
        locked_until = null,
        updated_at = v_now
    where user_id = p_user_id;
    v_row.failed_attempts := 0;
    v_row.locked_until := null;
  end if;

  v_pepper := public._wallet_pin_pepper();

  if public._wallet_validate_pin_format(p_pin)
     and v_row.pin_hash = crypt(encode(hmac(p_pin || ':' || p_user_id::text, v_pepper, 'sha256'), 'hex'), v_row.pin_hash) then
    update public.wallet_security
    set failed_attempts = 0,
        locked_until = null,
        last_verified_at = v_now,
        updated_at = v_now
    where user_id = p_user_id;

    return jsonb_build_object('ok', true, 'code', 'ok', 'attempts_remaining', 5);
  end if;

  v_attempts := v_row.failed_attempts + 1;
  if v_attempts >= 5 then
    v_locked_until := v_now + interval '15 minutes';

    update public.wallet_security
    set failed_attempts = 5,
        locked_until = v_locked_until,
        updated_at = v_now
    where user_id = p_user_id;

    insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
    values (
      p_user_id,
      p_user_id,
      'wallet_pin_locked',
      jsonb_build_object('locked_until', v_locked_until, 'reason', 'failed_attempts')
    );

    return jsonb_build_object(
      'ok', false,
      'code', 'pin_locked',
      'locked_until', v_locked_until,
      'attempts_remaining', 0
    );
  end if;

  update public.wallet_security
  set failed_attempts = v_attempts,
      updated_at = v_now
  where user_id = p_user_id;

  return jsonb_build_object(
    'ok', false,
    'code', 'invalid_pin',
    'attempts_remaining', 5 - v_attempts
  );
end;
$$;

revoke all on function public._wallet_check_pin(uuid, text) from public, anon, authenticated;

create or replace function public.get_wallet_pin_status()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.wallet_security%rowtype;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select * into v_row
  from public.wallet_security
  where user_id = auth.uid();

  if not found then
    return jsonb_build_object(
      'has_pin', false,
      'locked', false,
      'attempts_remaining', 5
    );
  end if;

  return jsonb_build_object(
    'has_pin', true,
    'locked', v_row.locked_until is not null and v_row.locked_until > v_now,
    'locked_until', v_row.locked_until,
    'attempts_remaining', greatest(0, 5 - v_row.failed_attempts),
    'pin_changed_at', v_row.pin_changed_at,
    'last_verified_at', v_row.last_verified_at
  );
end;
$$;

revoke all on function public.get_wallet_pin_status() from public, anon;
grant execute on function public.get_wallet_pin_status() to authenticated;

create or replace function public.setup_wallet_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = extensions, pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_pepper text;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;
  if not public._wallet_validate_pin_format(p_pin) then
    return jsonb_build_object('ok', false, 'code', 'invalid_format');
  end if;
  if not public._wallet_validate_pin_strength(p_pin) then
    return jsonb_build_object('ok', false, 'code', 'weak_pin');
  end if;
  if exists (select 1 from public.wallet_security where user_id = v_user_id) then
    return jsonb_build_object('ok', false, 'code', 'pin_already_set');
  end if;

  v_pepper := public._wallet_pin_pepper();
  insert into public.wallet_security(user_id, pin_hash, pin_changed_at, created_at, updated_at)
  values (
    v_user_id,
    crypt(encode(hmac(p_pin || ':' || v_user_id::text, v_pepper, 'sha256'), 'hex'), gen_salt('bf', 12)),
    v_now,
    v_now,
    v_now
  );

  insert into public.security_audit_events(user_id, actor_id, event_type)
  values (v_user_id, v_user_id, 'wallet_pin_created');

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

revoke all on function public.setup_wallet_pin(text) from public, anon;
grant execute on function public.setup_wallet_pin(text) to authenticated;

create or replace function public.change_wallet_pin(
  p_current_pin text,
  p_new_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = extensions, pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_check jsonb;
  v_pepper text;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;
  if not public._wallet_validate_pin_format(p_new_pin) then
    return jsonb_build_object('ok', false, 'code', 'invalid_format');
  end if;
  if not public._wallet_validate_pin_strength(p_new_pin) then
    return jsonb_build_object('ok', false, 'code', 'weak_pin');
  end if;

  v_check := public._wallet_check_pin(v_user_id, p_current_pin);
  if coalesce((v_check->>'ok')::boolean, false) is not true then
    return v_check;
  end if;
  if p_current_pin = p_new_pin then
    return jsonb_build_object('ok', false, 'code', 'pin_unchanged');
  end if;

  v_pepper := public._wallet_pin_pepper();
  update public.wallet_security
  set pin_hash = crypt(encode(hmac(p_new_pin || ':' || v_user_id::text, v_pepper, 'sha256'), 'hex'), gen_salt('bf', 12)),
      failed_attempts = 0,
      locked_until = null,
      pin_changed_at = v_now,
      updated_at = v_now
  where user_id = v_user_id;

  insert into public.security_audit_events(user_id, actor_id, event_type)
  values (v_user_id, v_user_id, 'wallet_pin_changed');

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

revoke all on function public.change_wallet_pin(text, text) from public, anon;
grant execute on function public.change_wallet_pin(text, text) to authenticated;

-- Service-role-only PIN reset. Reauthentication is performed by an Edge Function.
create or replace function public.admin_reset_wallet_pin(
  p_user_id uuid,
  p_new_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = extensions, pg_catalog, public
as $$
declare
  v_pepper text;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'Akses ditolak.';
  end if;
  if not public._wallet_validate_pin_format(p_new_pin) then
    return jsonb_build_object('ok', false, 'code', 'invalid_format');
  end if;
  if not public._wallet_validate_pin_strength(p_new_pin) then
    return jsonb_build_object('ok', false, 'code', 'weak_pin');
  end if;

  v_pepper := public._wallet_pin_pepper();
  insert into public.wallet_security(
    user_id, pin_hash, failed_attempts, locked_until, pin_changed_at, created_at, updated_at
  ) values (
    p_user_id,
    crypt(encode(hmac(p_new_pin || ':' || p_user_id::text, v_pepper, 'sha256'), 'hex'), gen_salt('bf', 12)),
    0,
    null,
    v_now,
    v_now,
    v_now
  )
  on conflict (user_id) do update
  set pin_hash = excluded.pin_hash,
      failed_attempts = 0,
      locked_until = null,
      pin_changed_at = v_now,
      updated_at = v_now;

  insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
  values (p_user_id, p_user_id, 'wallet_pin_reset', jsonb_build_object('method', 'password_reauth'));

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

revoke all on function public.admin_reset_wallet_pin(uuid, text) from public, anon, authenticated;
grant execute on function public.admin_reset_wallet_pin(uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- Secure bank-account mutation RPCs.
-- Direct writes are revoked so a modified client cannot bypass the PIN gate.
-- ---------------------------------------------------------------------------
revoke insert, update, delete on public.mitra_bank_accounts from authenticated;
revoke all on function public.set_default_mitra_bank_account(uuid) from authenticated;

create or replace function public.secure_add_mitra_bank_account(
  p_bank_name text,
  p_account_number text,
  p_account_holder text,
  p_is_default boolean,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_check jsonb;
  v_make_default boolean;
  v_id uuid;
begin
  if v_user_id is null then raise exception 'Pengguna belum login.'; end if;
  if not exists (select 1 from public.mitras where id = v_user_id and coalesce(is_active, false)) then
    raise exception 'Akun Mitra belum aktif.';
  end if;

  v_check := public._wallet_check_pin(v_user_id, p_pin);
  if coalesce((v_check->>'ok')::boolean, false) is not true then return v_check; end if;

  if length(trim(coalesce(p_bank_name, ''))) not between 2 and 80
     or trim(coalesce(p_account_number, '')) !~ '^[0-9]{6,32}$'
     or length(trim(coalesce(p_account_holder, ''))) not between 2 and 100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_bank');
  end if;

  v_make_default := coalesce(p_is_default, false) or not exists (
    select 1 from public.mitra_bank_accounts where mitra_id = v_user_id
  );

  if v_make_default then
    update public.mitra_bank_accounts set is_default = false
    where mitra_id = v_user_id and is_default = true;
  end if;

  insert into public.mitra_bank_accounts(
    mitra_id, bank_name, account_number, account_holder, is_default
  ) values (
    v_user_id,
    trim(p_bank_name),
    trim(p_account_number),
    trim(p_account_holder),
    v_make_default
  ) returning id into v_id;

  insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
  values (v_user_id, v_user_id, 'wallet_bank_added', jsonb_build_object('bank_account_id', v_id));

  return jsonb_build_object('ok', true, 'code', 'ok', 'id', v_id);
end;
$$;

revoke all on function public.secure_add_mitra_bank_account(text, text, text, boolean, text) from public, anon;
grant execute on function public.secure_add_mitra_bank_account(text, text, text, boolean, text) to authenticated;

create or replace function public.secure_update_mitra_bank_account(
  p_account_id uuid,
  p_bank_name text,
  p_account_number text,
  p_account_holder text,
  p_make_default boolean,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_check jsonb;
begin
  if v_user_id is null then raise exception 'Pengguna belum login.'; end if;
  v_check := public._wallet_check_pin(v_user_id, p_pin);
  if coalesce((v_check->>'ok')::boolean, false) is not true then return v_check; end if;

  if not exists (
    select 1 from public.mitra_bank_accounts
    where id = p_account_id and mitra_id = v_user_id
  ) then return jsonb_build_object('ok', false, 'code', 'bank_not_found'); end if;

  if length(trim(coalesce(p_bank_name, ''))) not between 2 and 80
     or trim(coalesce(p_account_number, '')) !~ '^[0-9]{6,32}$'
     or length(trim(coalesce(p_account_holder, ''))) not between 2 and 100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_bank');
  end if;

  if coalesce(p_make_default, false) then
    update public.mitra_bank_accounts set is_default = false
    where mitra_id = v_user_id and is_default = true;
  end if;

  update public.mitra_bank_accounts
  set bank_name = trim(p_bank_name),
      account_number = trim(p_account_number),
      account_holder = trim(p_account_holder),
      is_default = case when coalesce(p_make_default, false) then true else is_default end,
      updated_at = timezone('utc'::text, now())
  where id = p_account_id and mitra_id = v_user_id;

  insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
  values (v_user_id, v_user_id, 'wallet_bank_updated', jsonb_build_object('bank_account_id', p_account_id));

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

revoke all on function public.secure_update_mitra_bank_account(uuid, text, text, text, boolean, text) from public, anon;
grant execute on function public.secure_update_mitra_bank_account(uuid, text, text, text, boolean, text) to authenticated;

create or replace function public.secure_set_default_mitra_bank_account(
  p_account_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_check jsonb;
begin
  if v_user_id is null then raise exception 'Pengguna belum login.'; end if;
  v_check := public._wallet_check_pin(v_user_id, p_pin);
  if coalesce((v_check->>'ok')::boolean, false) is not true then return v_check; end if;

  if not exists (
    select 1 from public.mitra_bank_accounts
    where id = p_account_id and mitra_id = v_user_id
  ) then return jsonb_build_object('ok', false, 'code', 'bank_not_found'); end if;

  update public.mitra_bank_accounts set is_default = false
  where mitra_id = v_user_id and is_default = true;
  update public.mitra_bank_accounts set is_default = true
  where id = p_account_id and mitra_id = v_user_id;

  insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
  values (v_user_id, v_user_id, 'wallet_bank_default_changed', jsonb_build_object('bank_account_id', p_account_id));

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

revoke all on function public.secure_set_default_mitra_bank_account(uuid, text) from public, anon;
grant execute on function public.secure_set_default_mitra_bank_account(uuid, text) to authenticated;

create or replace function public.secure_delete_mitra_bank_account(
  p_account_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_check jsonb;
  v_was_default boolean := false;
  v_next_id uuid;
begin
  if v_user_id is null then raise exception 'Pengguna belum login.'; end if;
  v_check := public._wallet_check_pin(v_user_id, p_pin);
  if coalesce((v_check->>'ok')::boolean, false) is not true then return v_check; end if;

  select is_default into v_was_default
  from public.mitra_bank_accounts
  where id = p_account_id and mitra_id = v_user_id;
  if not found then return jsonb_build_object('ok', false, 'code', 'bank_not_found'); end if;

  delete from public.mitra_bank_accounts
  where id = p_account_id and mitra_id = v_user_id;

  if v_was_default then
    select id into v_next_id
    from public.mitra_bank_accounts
    where mitra_id = v_user_id
    order by created_at
    limit 1;
    if v_next_id is not null then
      update public.mitra_bank_accounts set is_default = true where id = v_next_id;
    end if;
  end if;

  insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
  values (v_user_id, v_user_id, 'wallet_bank_deleted', jsonb_build_object('bank_account_id', p_account_id));

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

revoke all on function public.secure_delete_mitra_bank_account(uuid, text) from public, anon;
grant execute on function public.secure_delete_mitra_bank_account(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Secure payout wrapper and removal of old client bypass paths.
-- ---------------------------------------------------------------------------
revoke all on function public.request_mitra_payout_v2(numeric, uuid) from authenticated;
revoke all on function public.request_mitra_payout(numeric, text, text, text) from authenticated;
revoke all on function public.cancel_mitra_payout(uuid) from authenticated;

create or replace function public.secure_request_mitra_payout(
  p_amount numeric,
  p_bank_account_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_check jsonb;
  v_request_id uuid;
begin
  if v_user_id is null then raise exception 'Pengguna belum login.'; end if;
  v_check := public._wallet_check_pin(v_user_id, p_pin);
  if coalesce((v_check->>'ok')::boolean, false) is not true then return v_check; end if;

  v_request_id := public.request_mitra_payout_v2(p_amount, p_bank_account_id);

  insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
  values (
    v_user_id,
    v_user_id,
    'wallet_payout_requested',
    jsonb_build_object('payout_request_id', v_request_id, 'amount', p_amount)
  );

  return jsonb_build_object('ok', true, 'code', 'ok', 'request_id', v_request_id);
end;
$$;

revoke all on function public.secure_request_mitra_payout(numeric, uuid, text) from public, anon;
grant execute on function public.secure_request_mitra_payout(numeric, uuid, text) to authenticated;

create or replace function public.secure_cancel_mitra_payout(
  p_request_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_check jsonb;
begin
  if v_user_id is null then raise exception 'Pengguna belum login.'; end if;
  v_check := public._wallet_check_pin(v_user_id, p_pin);
  if coalesce((v_check->>'ok')::boolean, false) is not true then return v_check; end if;

  perform public.cancel_mitra_payout(p_request_id);

  insert into public.security_audit_events(user_id, actor_id, event_type, metadata)
  values (
    v_user_id,
    v_user_id,
    'wallet_payout_cancelled',
    jsonb_build_object('payout_request_id', p_request_id)
  );

  return jsonb_build_object('ok', true, 'code', 'ok');
end;
$$;

revoke all on function public.secure_cancel_mitra_payout(uuid, text) from public, anon;
grant execute on function public.secure_cancel_mitra_payout(uuid, text) to authenticated;

commit;
