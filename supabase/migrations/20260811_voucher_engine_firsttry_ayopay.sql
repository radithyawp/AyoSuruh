-- AYO SURUH - VOUCHER ENGINE
-- Campaign-driven vouchers for first Customer transaction and AyoPay activation.
-- Depends on 20260811_ayopay_accounts_foundation.sql.
-- Voucher values are database data, not baked into Canva artwork.

begin;

create table if not exists public.voucher_campaigns (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  subtitle text,
  description text,
  eligibility_type text not null check (
    eligibility_type in ('first_transaction', 'ayopay_activation', 'manual')
  ),
  discount_type text not null default 'fixed' check (
    discount_type in ('fixed', 'percent')
  ),
  discount_value numeric(18,2) not null check (discount_value > 0),
  max_discount numeric(18,2),
  min_transaction numeric(18,2) not null default 0 check (min_transaction >= 0),
  valid_from timestamptz not null default timezone('utc'::text, now()),
  valid_until timestamptz,
  valid_days_after_issue integer not null default 30
    check (valid_days_after_issue between 1 and 365),
  usage_limit_per_user integer not null default 1
    check (usage_limit_per_user = 1),
  art_asset_key text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  check (valid_until is null or valid_until > valid_from),
  check (
    (discount_type = 'fixed' and discount_value <= 10000000)
    or
    (discount_type = 'percent' and discount_value <= 100)
  )
);

create table if not exists public.user_vouchers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  campaign_id uuid not null references public.voucher_campaigns(id) on delete restrict,
  status text not null default 'available'
    check (status in ('available', 'used', 'expired', 'cancelled')),
  issued_at timestamptz not null default timezone('utc'::text, now()),
  expires_at timestamptz,
  used_at timestamptz,
  used_job_id uuid references public.jobs(id) on delete set null,
  discount_amount numeric(18,2),
  redemption_reference text unique,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  unique(user_id, campaign_id)
);

create index if not exists user_vouchers_user_status_idx
  on public.user_vouchers(user_id, status, expires_at);

create index if not exists user_vouchers_campaign_idx
  on public.user_vouchers(campaign_id);

create or replace function public.touch_voucher_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_voucher_campaign_updated_at on public.voucher_campaigns;
create trigger trg_touch_voucher_campaign_updated_at
before update on public.voucher_campaigns
for each row execute function public.touch_voucher_updated_at();

drop trigger if exists trg_touch_user_voucher_updated_at on public.user_vouchers;
create trigger trg_touch_user_voucher_updated_at
before update on public.user_vouchers
for each row execute function public.touch_voucher_updated_at();

alter table public.voucher_campaigns enable row level security;
alter table public.user_vouchers enable row level security;

revoke all on public.voucher_campaigns from anon, authenticated;
revoke all on public.user_vouchers from anon, authenticated;

-- Campaign defaults. These values can later be changed in Supabase without
-- touching the Canva artwork or rebuilding Flutter.
insert into public.voucher_campaigns(
  code,
  title,
  subtitle,
  description,
  eligibility_type,
  discount_type,
  discount_value,
  max_discount,
  min_transaction,
  valid_days_after_issue,
  art_asset_key,
  is_active
) values
(
  'FIRSTTRY',
  'Coba Pengalaman Pertama-mu',
  'Diskon Pengguna Baru',
  'Potongan khusus untuk transaksi pekerjaan pertama sebagai Customer Ayo Suruh.',
  'first_transaction',
  'fixed',
  10000,
  null,
  50000,
  30,
  'first_try',
  true
),
(
  'AYOPAYWELCOME',
  'Yuk, Pakai AyoPay!',
  'Bonus Aktivasi AyoPay',
  'Voucher spesial satu kali setelah AyoPay berhasil diaktifkan.',
  'ayopay_activation',
  'fixed',
  15000,
  null,
  50000,
  30,
  'ayopay_welcome',
  true
)
on conflict (code) do update
set title = excluded.title,
    subtitle = excluded.subtitle,
    description = excluded.description,
    eligibility_type = excluded.eligibility_type,
    discount_type = excluded.discount_type,
    discount_value = excluded.discount_value,
    max_discount = excluded.max_discount,
    min_transaction = excluded.min_transaction,
    valid_days_after_issue = excluded.valid_days_after_issue,
    art_asset_key = excluded.art_asset_key,
    updated_at = timezone('utc'::text, now());

create or replace function public._voucher_has_prior_transaction(
  p_user_id uuid,
  p_exclude_job_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.jobs j
    left join public.payments p on p.job_id = j.id
    where j.customer_id = p_user_id
      and (p_exclude_job_id is null or j.id <> p_exclude_job_id)
      and (
        j.status::text = 'completed'
        or coalesce(p.status::text, '') = 'paid'
      )
  );
$$;

revoke all on function public._voucher_has_prior_transaction(uuid, uuid)
from public, anon, authenticated;

create or replace function public._voucher_sync_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_campaign public.voucher_campaigns%rowtype;
  v_eligible boolean;
  v_expiry timestamptz;
begin
  if p_user_id is null or not exists (
    select 1 from public.users u where u.id = p_user_id
  ) then
    return;
  end if;

  -- Expire already-issued vouchers first.
  update public.user_vouchers uv
  set status = 'expired'
  where uv.user_id = p_user_id
    and uv.status = 'available'
    and uv.expires_at is not null
    and uv.expires_at <= v_now;

  -- A FIRSTTRY voucher stops being valid if the account already completed/paid
  -- a prior Customer transaction without using it.
  if public._voucher_has_prior_transaction(p_user_id, null) then
    update public.user_vouchers uv
    set status = 'cancelled'
    from public.voucher_campaigns c
    where uv.user_id = p_user_id
      and uv.campaign_id = c.id
      and uv.status = 'available'
      and c.eligibility_type = 'first_transaction';
  end if;

  for v_campaign in
    select c.*
    from public.voucher_campaigns c
    where c.is_active = true
      and c.valid_from <= v_now
      and (c.valid_until is null or c.valid_until > v_now)
      and c.eligibility_type in ('first_transaction', 'ayopay_activation')
  loop
    v_eligible := false;

    if v_campaign.eligibility_type = 'first_transaction' then
      v_eligible := not public._voucher_has_prior_transaction(p_user_id, null);
    elsif v_campaign.eligibility_type = 'ayopay_activation' then
      v_eligible := exists (
        select 1
        from public.ayopay_accounts a
        where a.user_id = p_user_id
          and a.status = 'active'
          and a.activated_at is not null
      );
    end if;

    if v_eligible then
      v_expiry := v_now + make_interval(days => v_campaign.valid_days_after_issue);
      if v_campaign.valid_until is not null and v_campaign.valid_until < v_expiry then
        v_expiry := v_campaign.valid_until;
      end if;

      insert into public.user_vouchers(
        user_id,
        campaign_id,
        status,
        issued_at,
        expires_at
      ) values (
        p_user_id,
        v_campaign.id,
        'available',
        v_now,
        v_expiry
      )
      on conflict (user_id, campaign_id) do nothing;
    end if;
  end loop;
end;
$$;

revoke all on function public._voucher_sync_user(uuid)
from public, anon, authenticated;

create or replace function public.sync_my_vouchers()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_available integer;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public._voucher_sync_user(v_user_id);

  select count(*)::integer into v_available
  from public.user_vouchers uv
  where uv.user_id = v_user_id
    and uv.status = 'available';

  return jsonb_build_object('ok', true, 'available_count', v_available);
end;
$$;

revoke all on function public.sync_my_vouchers() from public, anon;
grant execute on function public.sync_my_vouchers() to authenticated;

create or replace function public.get_my_vouchers()
returns table (
  user_voucher_id uuid,
  campaign_id uuid,
  code text,
  title text,
  subtitle text,
  description text,
  eligibility_type text,
  discount_type text,
  discount_value numeric,
  max_discount numeric,
  min_transaction numeric,
  art_asset_key text,
  status text,
  issued_at timestamptz,
  expires_at timestamptz,
  used_at timestamptz,
  used_job_id uuid,
  discount_amount numeric
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public._voucher_sync_user(v_user_id);

  return query
  select
    uv.id,
    c.id,
    c.code,
    c.title,
    c.subtitle,
    c.description,
    c.eligibility_type,
    c.discount_type,
    c.discount_value,
    c.max_discount,
    c.min_transaction,
    c.art_asset_key,
    uv.status,
    uv.issued_at,
    uv.expires_at,
    uv.used_at,
    uv.used_job_id,
    uv.discount_amount
  from public.user_vouchers uv
  join public.voucher_campaigns c on c.id = uv.campaign_id
  where uv.user_id = v_user_id
  order by
    case uv.status
      when 'available' then 0
      when 'used' then 1
      when 'expired' then 2
      else 3
    end,
    uv.issued_at desc;
end;
$$;

revoke all on function public.get_my_vouchers() from public, anon;
grant execute on function public.get_my_vouchers() to authenticated;

create or replace function public.preview_my_voucher(
  p_user_voucher_id uuid,
  p_subtotal numeric,
  p_job_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_uv public.user_vouchers%rowtype;
  v_campaign public.voucher_campaigns%rowtype;
  v_now timestamptz := timezone('utc'::text, now());
  v_discount numeric(18,2);
  v_payable numeric(18,2);
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;
  if p_subtotal is null or p_subtotal <= 0 then
    return jsonb_build_object('eligible', false, 'code', 'invalid_subtotal', 'message', 'Nominal transaksi tidak valid.');
  end if;

  perform public._voucher_sync_user(v_user_id);

  select * into v_uv
  from public.user_vouchers uv
  where uv.id = p_user_voucher_id
    and uv.user_id = v_user_id;

  if not found then
    return jsonb_build_object('eligible', false, 'code', 'voucher_not_found', 'message', 'Voucher tidak ditemukan.');
  end if;

  select * into v_campaign
  from public.voucher_campaigns c
  where c.id = v_uv.campaign_id;

  if v_uv.status <> 'available' then
    return jsonb_build_object('eligible', false, 'code', 'voucher_unavailable', 'message', 'Voucher sudah tidak tersedia.');
  end if;
  if not v_campaign.is_active
      or v_campaign.valid_from > v_now
      or (v_campaign.valid_until is not null and v_campaign.valid_until <= v_now)
      or (v_uv.expires_at is not null and v_uv.expires_at <= v_now) then
    return jsonb_build_object('eligible', false, 'code', 'voucher_expired', 'message', 'Voucher sudah kedaluwarsa.');
  end if;
  if p_subtotal < v_campaign.min_transaction then
    return jsonb_build_object(
      'eligible', false,
      'code', 'minimum_not_met',
      'message', 'Minimum transaksi voucher belum terpenuhi.',
      'min_transaction', v_campaign.min_transaction
    );
  end if;

  if p_job_id is not null and not exists (
    select 1 from public.jobs j
    where j.id = p_job_id and j.customer_id = v_user_id
  ) then
    return jsonb_build_object('eligible', false, 'code', 'job_not_owned', 'message', 'Pekerjaan tidak valid untuk voucher ini.');
  end if;

  if v_campaign.eligibility_type = 'first_transaction'
     and public._voucher_has_prior_transaction(v_user_id, p_job_id) then
    return jsonb_build_object('eligible', false, 'code', 'not_first_transaction', 'message', 'Voucher hanya berlaku untuk transaksi pertamamu.');
  end if;

  if v_campaign.eligibility_type = 'ayopay_activation'
     and not exists (
       select 1 from public.ayopay_accounts a
       where a.user_id = v_user_id and a.status = 'active'
     ) then
    return jsonb_build_object('eligible', false, 'code', 'ayopay_required', 'message', 'Aktifkan AyoPay untuk menggunakan voucher ini.');
  end if;

  if v_campaign.discount_type = 'percent' then
    v_discount := round(p_subtotal * (v_campaign.discount_value / 100), 2);
    if v_campaign.max_discount is not null then
      v_discount := least(v_discount, v_campaign.max_discount);
    end if;
  else
    v_discount := v_campaign.discount_value;
  end if;

  v_discount := least(v_discount, p_subtotal);
  v_payable := greatest(0, round(p_subtotal - v_discount, 2));

  return jsonb_build_object(
    'eligible', true,
    'code', v_campaign.code,
    'user_voucher_id', v_uv.id,
    'discount_amount', v_discount,
    'payable_amount', v_payable,
    'subtotal', p_subtotal,
    'min_transaction', v_campaign.min_transaction
  );
end;
$$;

revoke all on function public.preview_my_voucher(uuid, numeric, uuid)
from public, anon;
grant execute on function public.preview_my_voucher(uuid, numeric, uuid)
to authenticated;

-- Internal transaction-safe consumer for the next Cash/Midtrans/AyoPay payment stage.
-- Clients cannot call this directly.
create or replace function public._consume_user_voucher(
  p_user_id uuid,
  p_user_voucher_id uuid,
  p_job_id uuid,
  p_subtotal numeric,
  p_redemption_reference text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uv public.user_vouchers%rowtype;
  v_campaign public.voucher_campaigns%rowtype;
  v_now timestamptz := timezone('utc'::text, now());
  v_discount numeric(18,2);
  v_payable numeric(18,2);
begin
  if trim(coalesce(p_redemption_reference, '')) = '' then
    raise exception 'Reference penggunaan voucher wajib diisi.';
  end if;
  if p_subtotal is null or p_subtotal <= 0 then
    raise exception 'Nominal transaksi voucher tidak valid.';
  end if;
  if not exists (
    select 1 from public.jobs j
    where j.id = p_job_id and j.customer_id = p_user_id
  ) then
    raise exception 'Pekerjaan voucher tidak valid.';
  end if;

  select * into v_uv
  from public.user_vouchers uv
  where uv.id = p_user_voucher_id
    and uv.user_id = p_user_id
  for update;

  if not found then
    raise exception 'Voucher tidak ditemukan.';
  end if;

  if v_uv.status = 'used' and v_uv.redemption_reference = trim(p_redemption_reference) then
    return jsonb_build_object(
      'ok', true,
      'duplicate', true,
      'discount_amount', coalesce(v_uv.discount_amount, 0),
      'user_voucher_id', v_uv.id
    );
  end if;

  if v_uv.status <> 'available' then
    raise exception 'Voucher sudah tidak tersedia.';
  end if;

  select * into v_campaign
  from public.voucher_campaigns c
  where c.id = v_uv.campaign_id;

  if not found or not v_campaign.is_active
      or v_campaign.valid_from > v_now
      or (v_campaign.valid_until is not null and v_campaign.valid_until <= v_now)
      or (v_uv.expires_at is not null and v_uv.expires_at <= v_now) then
    raise exception 'Voucher sudah kedaluwarsa.';
  end if;

  if p_subtotal < v_campaign.min_transaction then
    raise exception 'Minimum transaksi voucher belum terpenuhi.';
  end if;

  if v_campaign.eligibility_type = 'first_transaction'
     and public._voucher_has_prior_transaction(p_user_id, p_job_id) then
    raise exception 'Voucher hanya berlaku untuk transaksi pertama.';
  end if;

  if v_campaign.eligibility_type = 'ayopay_activation'
     and not exists (
       select 1 from public.ayopay_accounts a
       where a.user_id = p_user_id and a.status = 'active'
     ) then
    raise exception 'AyoPay harus aktif untuk menggunakan voucher ini.';
  end if;

  if v_campaign.discount_type = 'percent' then
    v_discount := round(p_subtotal * (v_campaign.discount_value / 100), 2);
    if v_campaign.max_discount is not null then
      v_discount := least(v_discount, v_campaign.max_discount);
    end if;
  else
    v_discount := v_campaign.discount_value;
  end if;

  v_discount := least(v_discount, p_subtotal);
  v_payable := greatest(0, round(p_subtotal - v_discount, 2));

  update public.user_vouchers
  set status = 'used',
      used_at = v_now,
      used_job_id = p_job_id,
      discount_amount = v_discount,
      redemption_reference = trim(p_redemption_reference)
  where id = v_uv.id;

  return jsonb_build_object(
    'ok', true,
    'duplicate', false,
    'code', v_campaign.code,
    'discount_amount', v_discount,
    'payable_amount', v_payable,
    'user_voucher_id', v_uv.id
  );
end;
$$;

revoke all on function public._consume_user_voucher(uuid, uuid, uuid, numeric, text)
from public, anon, authenticated;

-- New users lazily receive FIRSTTRY through the same eligibility function.
create or replace function public.trg_sync_new_user_vouchers()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  perform public._voucher_sync_user(new.id);
  return new;
end;
$$;

drop trigger if exists trg_sync_new_user_vouchers on public.users;
create trigger trg_sync_new_user_vouchers
after insert on public.users
for each row execute function public.trg_sync_new_user_vouchers();

-- AyoPay activation automatically makes AYOPAYWELCOME eligible. This trigger is
-- idempotent because user_vouchers has unique(user_id, campaign_id).
create or replace function public.trg_sync_ayopay_activation_voucher()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.status = 'active' and new.activated_at is not null then
    perform public._voucher_sync_user(new.user_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_ayopay_activation_voucher on public.ayopay_accounts;
create trigger trg_sync_ayopay_activation_voucher
after insert or update of status, activated_at on public.ayopay_accounts
for each row execute function public.trg_sync_ayopay_activation_voucher();

commit;
