-- Ayo Suruh - Batch 1.1 Stability + Bank Accounts + In-App Admin Foundation
-- Jalankan setelah migration 20260807_* dan refund/wallet migrations.

begin;

-- ---------------------------------------------------------------------------
-- 1. Lindungi dual-mode agar customer tidak dapat memesan jasa milik akun sendiri.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_no_self_service_job()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.preferred_mitra_id is not null
     and new.preferred_mitra_id = new.customer_id then
    raise exception 'Kamu tidak dapat memesan jasa milik akunmu sendiri.';
  end if;

  if new.mitra_id is not null and new.mitra_id = new.customer_id then
    raise exception 'Customer dan mitra pada pekerjaan yang sama tidak boleh akun yang sama.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_no_self_service_job on public.jobs;
create trigger trg_enforce_no_self_service_job
before insert or update of customer_id, preferred_mitra_id, mitra_id
on public.jobs
for each row execute function public.enforce_no_self_service_job();

create or replace function public.enforce_no_self_bid()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_customer_id uuid;
begin
  select j.customer_id into v_customer_id
  from public.jobs j
  where j.id = new.job_id;

  if v_customer_id is not null and v_customer_id = new.mitra_id then
    raise exception 'Kamu tidak dapat mengirim penawaran pada pekerjaan milik akunmu sendiri.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_no_self_bid on public.bids;
create trigger trg_enforce_no_self_bid
before insert or update of job_id, mitra_id
on public.bids
for each row execute function public.enforce_no_self_bid();

-- ---------------------------------------------------------------------------
-- 2. Katalog jasa publik: hanya mengekspos profil mitra yang memang dibutuhkan UI.
--    SECURITY DEFINER menghindari nama mitra menjadi generic akibat RLS public.users.
-- ---------------------------------------------------------------------------
create or replace function public.get_public_mitra_services()
returns table (
  id uuid,
  mitra_id uuid,
  category_id uuid,
  title text,
  description text,
  starting_price numeric,
  created_at timestamp with time zone,
  category_name text,
  category_icon text,
  mitra_fullname text,
  mitra_avatar_url text,
  mitra_rating numeric
)
language sql
security definer
set search_path = public
as $$
  select
    s.id,
    s.mitra_id,
    s.category_id,
    s.title,
    s.description,
    s.starting_price,
    s.created_at,
    c.name,
    c.icon,
    coalesce(nullif(trim(u.fullname), ''), 'Mitra Ayo Suruh'),
    u.avatar_url,
    coalesce(m.rating, 0)
  from public.mitra_services s
  join public.mitras m on m.id = s.mitra_id and coalesce(m.is_active, false) = true
  join public.users u on u.id = s.mitra_id
  join public.categories c on c.id = s.category_id
  where s.is_active = true
  order by s.created_at desc;
$$;

revoke all on function public.get_public_mitra_services() from public;
grant execute on function public.get_public_mitra_services() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Rekening pencairan Mitra. Satu mitra dapat menyimpan beberapa rekening.
-- ---------------------------------------------------------------------------
create table if not exists public.mitra_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  mitra_id uuid not null references public.mitras(id) on delete cascade,
  bank_name text not null check (char_length(trim(bank_name)) >= 2),
  account_number text not null check (char_length(trim(account_number)) >= 6),
  account_holder text not null check (char_length(trim(account_holder)) >= 2),
  is_default boolean not null default false,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists mitra_bank_accounts_mitra_idx
  on public.mitra_bank_accounts(mitra_id, created_at desc);
create unique index if not exists mitra_bank_accounts_one_default_idx
  on public.mitra_bank_accounts(mitra_id)
  where is_default = true;
create unique index if not exists mitra_bank_accounts_unique_number_idx
  on public.mitra_bank_accounts(mitra_id, bank_name, account_number);

create or replace function public.touch_mitra_bank_account_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_mitra_bank_account_updated_at on public.mitra_bank_accounts;
create trigger trg_touch_mitra_bank_account_updated_at
before update on public.mitra_bank_accounts
for each row execute function public.touch_mitra_bank_account_updated_at();

alter table public.mitra_bank_accounts enable row level security;

drop policy if exists "ayo_mitra_bank_read_own" on public.mitra_bank_accounts;
create policy "ayo_mitra_bank_read_own"
on public.mitra_bank_accounts for select
to authenticated
using (mitra_id = auth.uid());

drop policy if exists "ayo_mitra_bank_insert_own" on public.mitra_bank_accounts;
create policy "ayo_mitra_bank_insert_own"
on public.mitra_bank_accounts for insert
to authenticated
with check (
  mitra_id = auth.uid()
  and exists (
    select 1 from public.mitras m
    where m.id = auth.uid() and coalesce(m.is_active, false) = true
  )
);

drop policy if exists "ayo_mitra_bank_update_own" on public.mitra_bank_accounts;
create policy "ayo_mitra_bank_update_own"
on public.mitra_bank_accounts for update
to authenticated
using (mitra_id = auth.uid())
with check (mitra_id = auth.uid());

drop policy if exists "ayo_mitra_bank_delete_own" on public.mitra_bank_accounts;
create policy "ayo_mitra_bank_delete_own"
on public.mitra_bank_accounts for delete
to authenticated
using (mitra_id = auth.uid());

grant select, insert, update, delete on public.mitra_bank_accounts to authenticated;

-- Seed satu rekening dari data pengajuan mitra lama bila belum punya rekening.
insert into public.mitra_bank_accounts (
  mitra_id,
  bank_name,
  account_number,
  account_holder,
  is_default
)
select
  seeded.user_id,
  seeded.bank_name,
  seeded.account_number,
  seeded.account_holder,
  true
from (
  select distinct on (a.user_id)
    a.user_id,
    trim(a.bank_name) as bank_name,
    trim(a.account_number) as account_number,
    coalesce(nullif(trim(u.fullname), ''), 'Mitra Ayo Suruh') as account_holder
  from public.mitra_applications a
  join public.users u on u.id = a.user_id
  join public.mitras m on m.id = a.user_id and coalesce(m.is_active, false) = true
  where a.status = 'approved'::public.application_status
    and trim(coalesce(a.bank_name, '')) <> ''
    and trim(coalesce(a.account_number, '')) <> ''
  order by a.user_id, a.created_at desc
) seeded
where not exists (
  select 1 from public.mitra_bank_accounts b where b.mitra_id = seeded.user_id
)
on conflict do nothing;

create or replace function public.set_default_mitra_bank_account(p_account_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1 from public.mitra_bank_accounts b
    where b.id = p_account_id and b.mitra_id = auth.uid()
  ) then
    raise exception 'Rekening tidak ditemukan.';
  end if;

  update public.mitra_bank_accounts
  set is_default = false
  where mitra_id = auth.uid() and is_default = true;

  update public.mitra_bank_accounts
  set is_default = true
  where id = p_account_id and mitra_id = auth.uid();
end;
$$;

revoke all on function public.set_default_mitra_bank_account(uuid) from public;
grant execute on function public.set_default_mitra_bank_account(uuid) to authenticated;

-- Payout v2 menggunakan rekening tersimpan dan menyalin snapshot ke payout_requests.
create or replace function public.request_mitra_payout_v2(
  p_amount numeric,
  p_bank_account_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bank public.mitra_bank_accounts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select * into v_bank
  from public.mitra_bank_accounts b
  where b.id = p_bank_account_id
    and b.mitra_id = auth.uid();

  if not found then
    raise exception 'Rekening pencairan tidak ditemukan.';
  end if;

  return public.request_mitra_payout(
    p_amount,
    v_bank.bank_name,
    v_bank.account_number,
    v_bank.account_holder
  );
end;
$$;

revoke all on function public.request_mitra_payout_v2(numeric, uuid) from public;
grant execute on function public.request_mitra_payout_v2(numeric, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Statistik finansial Mitra harus berasal dari wallet ledger NET 94%, bukan earnings lama.
-- ---------------------------------------------------------------------------
create or replace function public.get_mitra_financial_summary()
returns table (
  lifetime_net_earnings numeric,
  pending_balance numeric,
  available_balance numeric,
  held_balance numeric,
  withdrawn_total numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public.release_mature_wallet_entries(auth.uid());

  return query
  select
    coalesce(sum(l.amount) filter (
      where l.entry_type in ('job_earning', 'refund_adjustment')
        and l.state = 'posted'
    ), 0),
    coalesce(sum(l.amount) filter (
      where l.bucket = 'pending' and l.state = 'posted'
    ), 0),
    coalesce(sum(l.amount) filter (
      where l.bucket = 'available' and l.state = 'posted'
    ), 0),
    coalesce(sum(l.amount) filter (
      where l.bucket = 'held' and l.state = 'posted'
    ), 0),
    coalesce(sum(l.amount) filter (
      where l.bucket = 'withdrawn' and l.state = 'posted'
    ), 0)
  from public.mitra_wallet_ledger l
  where l.mitra_id = auth.uid();
end;
$$;

revoke all on function public.get_mitra_financial_summary() from public;
grant execute on function public.get_mitra_financial_summary() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Admin di dalam aplikasi. Tidak mengubah enum user_role customer/mitra.
-- ---------------------------------------------------------------------------
create table if not exists public.admin_users (
  user_id uuid primary key references public.users(id) on delete cascade,
  admin_role text not null default 'admin' check (admin_role in ('admin', 'super_admin')),
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.admin_users enable row level security;

create or replace function public.is_current_user_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_users a
    where a.user_id = auth.uid() and a.is_active = true
  );
$$;

revoke all on function public.is_current_user_admin() from public;
grant execute on function public.is_current_user_admin() to authenticated;

-- Admin perlu melihat KTM/selfie pada bucket privat saat verifikasi mitra.
drop policy if exists "ayo_admin_mitra_documents_storage_read"
  on storage.objects;
create policy "ayo_admin_mitra_documents_storage_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'mitra-documents'
  and public.is_current_user_admin()
);

drop policy if exists "ayo_admin_users_read_self" on public.admin_users;
create policy "ayo_admin_users_read_self"
on public.admin_users for select
to authenticated
using (user_id = auth.uid());

grant select on public.admin_users to authenticated;

create or replace function public.admin_dashboard_summary()
returns table (
  total_users bigint,
  total_mitras bigint,
  pending_mitra_applications bigint,
  active_jobs bigint,
  completed_jobs bigint,
  pending_payouts bigint,
  gmv_paid numeric,
  platform_revenue numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  return query
  select
    (select count(*) from public.users)::bigint,
    (select count(*) from public.mitras where coalesce(is_active, false) = true)::bigint,
    (select count(*) from public.mitra_applications where status = 'applied'::public.application_status)::bigint,
    (select count(*) from public.jobs where status in ('posted'::public.job_status, 'waiting_bid'::public.job_status, 'accepted'::public.job_status, 'on_progress'::public.job_status))::bigint,
    (select count(*) from public.jobs where status = 'completed'::public.job_status)::bigint,
    (select count(*) from public.payout_requests where status in ('requested','under_review','approved','processing'))::bigint,
    coalesce((select sum(amount) from public.payments where status = 'paid'::public.payment_status), 0),
    coalesce((select sum(platform_fee_amount) from public.payments where status = 'paid'::public.payment_status), 0);
end;
$$;

revoke all on function public.admin_dashboard_summary() from public;
grant execute on function public.admin_dashboard_summary() to authenticated;

create or replace function public.admin_list_users()
returns table (
  user_id uuid,
  fullname text,
  email text,
  phone text,
  role text,
  avatar_url text,
  created_at timestamp with time zone,
  is_mitra boolean,
  mitra_active boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  return query
  select
    u.id,
    u.fullname,
    u.email,
    u.phone,
    u.role::text,
    u.avatar_url,
    u.created_at,
    (m.id is not null),
    coalesce(m.is_active, false)
  from public.users u
  left join public.mitras m on m.id = u.id
  order by u.created_at desc;
end;
$$;

revoke all on function public.admin_list_users() from public;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_list_mitra_applications()
returns table (
  application_id uuid,
  user_id uuid,
  fullname text,
  email text,
  phone text,
  address text,
  description text,
  bank_name text,
  account_number text,
  status text,
  created_at timestamp with time zone,
  ktm_url text,
  selfie_url text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  return query
  select
    a.id,
    a.user_id,
    u.fullname,
    u.email,
    u.phone,
    a.address,
    a.description,
    a.bank_name,
    a.account_number,
    a.status::text,
    a.created_at,
    d.ktm,
    d.selfie
  from public.mitra_applications a
  join public.users u on u.id = a.user_id
  left join public.mitra_documents d on d.application_id = a.id
  order by
    case when a.status = 'applied'::public.application_status then 0 else 1 end,
    a.created_at desc;
end;
$$;

revoke all on function public.admin_list_mitra_applications() from public;
grant execute on function public.admin_list_mitra_applications() to authenticated;

create or replace function public.admin_review_mitra_application(
  p_application_id uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text := lower(trim(coalesce(p_action, '')));
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  if v_action = 'approve' then
    perform public.approve_mitra_application(p_application_id);
  elsif v_action = 'reject' then
    perform public.reject_mitra_application(
      p_application_id,
      coalesce(nullif(trim(p_note), ''), 'Pengajuan belum memenuhi ketentuan Ayo Suruh.')
    );
  else
    raise exception 'Action harus approve atau reject.';
  end if;
end;
$$;

revoke all on function public.admin_review_mitra_application(uuid, text, text) from public;
grant execute on function public.admin_review_mitra_application(uuid, text, text) to authenticated;

create or replace function public.admin_list_payouts()
returns table (
  payout_id uuid,
  mitra_id uuid,
  mitra_name text,
  amount numeric,
  bank_name text,
  account_number text,
  account_holder text,
  status text,
  requested_at timestamp with time zone,
  processed_at timestamp with time zone
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  return query
  select
    p.id,
    p.mitra_id,
    coalesce(nullif(trim(u.fullname), ''), 'Mitra Ayo Suruh'),
    p.amount,
    p.bank_name,
    p.account_number,
    p.account_holder,
    p.status,
    p.requested_at,
    p.processed_at
  from public.payout_requests p
  join public.users u on u.id = p.mitra_id
  order by
    case when p.status in ('requested','under_review','approved','processing') then 0 else 1 end,
    p.requested_at desc;
end;
$$;

revoke all on function public.admin_list_payouts() from public;
grant execute on function public.admin_list_payouts() to authenticated;

create or replace function public.admin_process_payout(
  p_request_id uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;
  perform public.process_mock_payout(p_request_id, p_action, p_note);
end;
$$;

revoke all on function public.admin_process_payout(uuid, text, text) from public;
grant execute on function public.admin_process_payout(uuid, text, text) to authenticated;

commit;

-- SETUP ADMIN PERTAMA (jalankan manual sekali setelah migration, ganti UUID):
-- insert into public.admin_users(user_id, admin_role)
-- values ('UUID_USER_ADMIN', 'super_admin')
-- on conflict (user_id) do update set is_active = true, admin_role = excluded.admin_role;
