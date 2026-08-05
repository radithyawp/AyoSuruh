-- Ayo Suruh - Fitur Pasang Job dan Penawaran Mitra
-- Jalankan satu kali melalui Supabase SQL Editor.

-- ---------------------------------------------------------------------------
-- 1. Constraint bid unik
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bids_job_mitra_unique'
      and conrelid = 'public.bids'::regclass
  ) then
    alter table public.bids
      add constraint bids_job_mitra_unique unique (job_id, mitra_id);
  end if;
end
$$;

-- Kategori dasar untuk form Pasang Pekerjaan. Tidak mengubah kategori yang sudah ada.
insert into public.categories (name, icon)
select 'Kebersihan', 'cleaning_services'
where not exists (
  select 1 from public.categories where lower(name) = lower('Kebersihan')
);

insert into public.categories (name, icon)
select 'Kurir', 'local_shipping'
where not exists (
  select 1 from public.categories where lower(name) = lower('Kurir')
);

insert into public.categories (name, icon)
select 'Tukang', 'handyman'
where not exists (
  select 1 from public.categories where lower(name) = lower('Tukang')
);

insert into public.categories (name, icon)
select 'Perbaikan AC', 'ac_unit'
where not exists (
  select 1 from public.categories where lower(name) = lower('Perbaikan AC')
);

insert into public.categories (name, icon)
select 'Lainnya', 'grid_view'
where not exists (
  select 1 from public.categories where lower(name) = lower('Lainnya')
);

-- ---------------------------------------------------------------------------
-- 2. RPC mitra mengirim penawaran
-- ---------------------------------------------------------------------------
create or replace function public.submit_job_bid(
  p_job_id uuid,
  p_price numeric,
  p_estimated_time text,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bid_id uuid;
  v_customer_id uuid;
  v_job_status public.job_status;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1
    from public.mitras m
    where m.id = auth.uid()
      and coalesce(m.is_active, false) = true
  ) then
    raise exception 'Akun belum terdaftar sebagai mitra aktif.';
  end if;

  select j.customer_id, j.status
    into v_customer_id, v_job_status
  from public.jobs j
  where j.id = p_job_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan.';
  end if;

  if v_customer_id = auth.uid() then
    raise exception 'Mitra tidak dapat menawar pekerjaan miliknya sendiri.';
  end if;

  if v_job_status not in ('posted'::public.job_status, 'waiting_bid'::public.job_status) then
    raise exception 'Pekerjaan sudah tidak menerima penawaran.';
  end if;

  if p_price is null or p_price < 1000 then
    raise exception 'Harga penawaran tidak valid.';
  end if;

  insert into public.bids (
    job_id,
    mitra_id,
    price,
    estimated_time,
    message,
    status
  ) values (
    p_job_id,
    auth.uid(),
    p_price,
    nullif(trim(p_estimated_time), ''),
    nullif(trim(p_message), ''),
    'pending'::public.bid_status
  )
  returning id into v_bid_id;

  if v_job_status = 'posted'::public.job_status then
    update public.jobs
    set status = 'waiting_bid'::public.job_status
    where id = p_job_id;

    insert into public.job_timelines (job_id, status, description)
    values (
      p_job_id,
      'waiting_bid'::public.job_status,
      'Penawaran mitra mulai masuk.'
    );
  end if;

  return v_bid_id;
exception
  when unique_violation then
    raise exception 'Kamu sudah mengirim penawaran untuk pekerjaan ini.';
end;
$$;

revoke all on function public.submit_job_bid(uuid, numeric, text, text) from public;
grant execute on function public.submit_job_bid(uuid, numeric, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPC customer menerima satu mitra secara atomik
-- ---------------------------------------------------------------------------
create or replace function public.accept_job_bid(
  p_job_id uuid,
  p_bid_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_mitra_id uuid;
  v_job_status public.job_status;
begin
  select j.customer_id, j.status
    into v_customer_id, v_job_status
  from public.jobs j
  where j.id = p_job_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan.';
  end if;

  if auth.uid() is null or auth.uid() <> v_customer_id then
    raise exception 'Hanya pemilik pekerjaan yang dapat memilih mitra.';
  end if;

  if v_job_status not in ('posted'::public.job_status, 'waiting_bid'::public.job_status) then
    raise exception 'Pekerjaan sudah tidak menerima penawaran.';
  end if;

  select b.mitra_id
    into v_mitra_id
  from public.bids b
  where b.id = p_bid_id
    and b.job_id = p_job_id
    and b.status = 'pending'::public.bid_status
  for update;

  if not found then
    raise exception 'Penawaran tidak ditemukan atau sudah diproses.';
  end if;

  update public.bids
  set status = 'rejected'::public.bid_status
  where job_id = p_job_id
    and id <> p_bid_id
    and status = 'pending'::public.bid_status;

  update public.bids
  set status = 'accepted'::public.bid_status
  where id = p_bid_id;

  update public.jobs
  set mitra_id = v_mitra_id,
      status = 'accepted'::public.job_status
  where id = p_job_id;

  insert into public.job_timelines (job_id, status, description)
  values (
    p_job_id,
    'accepted'::public.job_status,
    'Customer memilih mitra untuk mengerjakan pekerjaan.'
  );
end;
$$;

revoke all on function public.accept_job_bid(uuid, uuid) from public;
grant execute on function public.accept_job_bid(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC mitra memulai pekerjaan yang sudah diberikan kepadanya
-- ---------------------------------------------------------------------------
create or replace function public.start_assigned_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  update public.jobs
  set status = 'on_progress'::public.job_status
  where id = p_job_id
    and mitra_id = auth.uid()
    and status = 'accepted'::public.job_status;

  if not found then
    raise exception 'Pekerjaan tidak dapat dimulai oleh akun ini.';
  end if;

  insert into public.job_timelines (job_id, status, description)
  values (
    p_job_id,
    'on_progress'::public.job_status,
    'Mitra mulai mengerjakan pekerjaan.'
  );
end;
$$;

revoke all on function public.start_assigned_job(uuid) from public;
grant execute on function public.start_assigned_job(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. RLS minimal untuk alur job dan bid
-- Nama policy dibuat khusus agar tidak bertabrakan dengan policy lama.
-- ---------------------------------------------------------------------------
alter table public.categories enable row level security;
alter table public.addresses enable row level security;
alter table public.jobs enable row level security;
alter table public.bids enable row level security;
alter table public.job_timelines enable row level security;
alter table public.mitras enable row level security;
alter table public.earnings enable row level security;

-- Categories
drop policy if exists "ayo_categories_read" on public.categories;
create policy "ayo_categories_read"
on public.categories for select
to authenticated
using (true);

-- Addresses milik sendiri
drop policy if exists "ayo_addresses_read_own" on public.addresses;
create policy "ayo_addresses_read_own"
on public.addresses for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "ayo_addresses_insert_own" on public.addresses;
create policy "ayo_addresses_insert_own"
on public.addresses for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "ayo_addresses_update_own" on public.addresses;
create policy "ayo_addresses_update_own"
on public.addresses for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Jobs: pemilik, mitra terpilih, dan job terbuka dapat dibaca
drop policy if exists "ayo_jobs_read_relevant" on public.jobs;
create policy "ayo_jobs_read_relevant"
on public.jobs for select
to authenticated
using (
  customer_id = auth.uid()
  or mitra_id = auth.uid()
  or status in ('posted'::public.job_status, 'waiting_bid'::public.job_status)
);

drop policy if exists "ayo_jobs_insert_customer" on public.jobs;
create policy "ayo_jobs_insert_customer"
on public.jobs for insert
to authenticated
with check (customer_id = auth.uid());

drop policy if exists "ayo_jobs_update_customer" on public.jobs;
create policy "ayo_jobs_update_customer"
on public.jobs for update
to authenticated
using (customer_id = auth.uid())
with check (customer_id = auth.uid());

-- Bids: mitra melihat miliknya, customer melihat bid untuk job miliknya
drop policy if exists "ayo_bids_read_relevant" on public.bids;
create policy "ayo_bids_read_relevant"
on public.bids for select
to authenticated
using (
  mitra_id = auth.uid()
  or exists (
    select 1 from public.jobs j
    where j.id = bids.job_id
      and j.customer_id = auth.uid()
  )
);

drop policy if exists "ayo_bids_insert_own" on public.bids;
create policy "ayo_bids_insert_own"
on public.bids for insert
to authenticated
with check (
  mitra_id = auth.uid()
  and exists (
    select 1 from public.mitras m
    where m.id = auth.uid()
      and coalesce(m.is_active, false) = true
  )
);

drop policy if exists "ayo_bids_update_customer" on public.bids;
create policy "ayo_bids_update_customer"
on public.bids for update
to authenticated
using (
  exists (
    select 1 from public.jobs j
    where j.id = bids.job_id
      and j.customer_id = auth.uid()
  )
);

-- Profil mitra dibaca untuk kartu penawaran
drop policy if exists "ayo_mitras_read" on public.mitras;
create policy "ayo_mitras_read"
on public.mitras for select
to authenticated
using (true);

-- Earnings hanya dibaca oleh mitra pemiliknya
drop policy if exists "ayo_earnings_read_own" on public.earnings;
create policy "ayo_earnings_read_own"
on public.earnings for select
to authenticated
using (mitra_id = auth.uid());

-- Timeline hanya dibaca pihak yang berkaitan dengan job
drop policy if exists "ayo_timelines_read_relevant" on public.job_timelines;
create policy "ayo_timelines_read_relevant"
on public.job_timelines for select
to authenticated
using (
  exists (
    select 1 from public.jobs j
    where j.id = job_timelines.job_id
      and (j.customer_id = auth.uid() or j.mitra_id = auth.uid())
  )
);

drop policy if exists "ayo_timelines_insert_relevant" on public.job_timelines;
create policy "ayo_timelines_insert_relevant"
on public.job_timelines for insert
to authenticated
with check (
  exists (
    select 1 from public.jobs j
    where j.id = job_timelines.job_id
      and (j.customer_id = auth.uid() or j.mitra_id = auth.uid())
  )
);
