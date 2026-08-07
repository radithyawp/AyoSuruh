-- Ayo Suruh - Marketplace Jasa Mitra (MVP)
-- Mitra dapat mempublikasikan keahlian/jasa. Customer dapat menemukan jasa lalu
-- membuat job dengan alur bidding yang sama, ditujukan ke mitra tersebut.

begin;

create table if not exists public.mitra_services (
  id uuid primary key default gen_random_uuid(),
  mitra_id uuid not null references public.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  title text not null check (char_length(trim(title)) >= 5),
  description text not null check (char_length(trim(description)) >= 10),
  starting_price numeric not null default 0 check (starting_price >= 0),
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists mitra_services_active_category_idx
  on public.mitra_services(is_active, category_id, created_at desc);
create index if not exists mitra_services_mitra_idx
  on public.mitra_services(mitra_id, created_at desc);

create or replace function public.touch_mitra_service_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_mitra_service_updated_at
on public.mitra_services;
create trigger trg_touch_mitra_service_updated_at
before update on public.mitra_services
for each row execute function public.touch_mitra_service_updated_at();

alter table public.mitra_services enable row level security;

drop policy if exists "ayo_mitra_services_read" on public.mitra_services;
create policy "ayo_mitra_services_read"
on public.mitra_services for select
to authenticated
using (
  mitra_id = auth.uid()
  or (
    is_active = true
    and exists (
      select 1
      from public.mitras m
      where m.id = mitra_services.mitra_id
        and coalesce(m.is_active, false) = true
    )
  )
);

drop policy if exists "ayo_mitra_services_insert_own" on public.mitra_services;
create policy "ayo_mitra_services_insert_own"
on public.mitra_services for insert
to authenticated
with check (
  mitra_id = auth.uid()
  and exists (
    select 1 from public.mitras m
    where m.id = auth.uid() and coalesce(m.is_active, false) = true
  )
);

drop policy if exists "ayo_mitra_services_update_own" on public.mitra_services;
create policy "ayo_mitra_services_update_own"
on public.mitra_services for update
to authenticated
using (mitra_id = auth.uid())
with check (
  mitra_id = auth.uid()
  and exists (
    select 1 from public.mitras m
    where m.id = auth.uid() and coalesce(m.is_active, false) = true
  )
);

drop policy if exists "ayo_mitra_services_delete_own" on public.mitra_services;
create policy "ayo_mitra_services_delete_own"
on public.mitra_services for delete
to authenticated
using (mitra_id = auth.uid());

grant select, insert, update, delete on public.mitra_services to authenticated;

-- Job yang berasal dari sebuah katalog jasa dapat ditujukan terlebih dahulu ke
-- mitra pemilik jasa. Lifecycle job/bid/payment tetap memakai engine yang sama.
alter table public.jobs
  add column if not exists preferred_mitra_id uuid
    references public.users(id) on delete set null;

create index if not exists jobs_preferred_mitra_open_idx
  on public.jobs(preferred_mitra_id, status, created_at desc);

-- Job terbuka yang ditujukan ke mitra tertentu tidak perlu diekspos ke semua
-- mitra. Customer pemilik dan mitra terpilih tetap dapat membacanya.
drop policy if exists "ayo_jobs_read_relevant" on public.jobs;
create policy "ayo_jobs_read_relevant"
on public.jobs for select
to authenticated
using (
  customer_id = auth.uid()
  or mitra_id = auth.uid()
  or (
    status in ('posted'::public.job_status, 'waiting_bid'::public.job_status)
    and (preferred_mitra_id is null or preferred_mitra_id = auth.uid())
  )
);

create or replace function public.enforce_preferred_mitra_bid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_preferred_mitra_id uuid;
begin
  select j.preferred_mitra_id
    into v_preferred_mitra_id
  from public.jobs j
  where j.id = new.job_id;

  if v_preferred_mitra_id is not null
     and new.mitra_id <> v_preferred_mitra_id then
    raise exception 'Pekerjaan ini ditujukan ke mitra lain.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_preferred_mitra_bid on public.bids;
create trigger trg_enforce_preferred_mitra_bid
before insert or update of job_id, mitra_id
on public.bids
for each row execute function public.enforce_preferred_mitra_bid();

commit;
