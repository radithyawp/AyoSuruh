-- Ayo Suruh - Media katalog kategori, foto pekerjaan Customer, dan foto katalog jasa Mitra
-- 2026-08-09

begin;

-- ---------------------------------------------------------------------------
-- 1. Foto pekerjaan yang diunggah Customer (maksimal 5 per job)
-- ---------------------------------------------------------------------------
create table if not exists public.job_images (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  storage_path text not null unique,
  sort_order integer not null default 0 check (sort_order between 0 and 4),
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists job_images_job_idx
  on public.job_images(job_id, sort_order, created_at);

create or replace function public.enforce_job_image_limit()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if (
    select count(*)
    from public.job_images ji
    where ji.job_id = new.job_id
  ) >= 5 then
    raise exception 'Maksimal 5 foto untuk satu pekerjaan.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_job_image_limit on public.job_images;
create trigger trg_enforce_job_image_limit
before insert on public.job_images
for each row execute function public.enforce_job_image_limit();

alter table public.job_images enable row level security;

drop policy if exists "ayo_job_images_read_relevant" on public.job_images;
create policy "ayo_job_images_read_relevant"
on public.job_images for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = job_images.job_id
      and (
        j.customer_id = auth.uid()
        or j.mitra_id = auth.uid()
        or (
          j.status::text in ('posted', 'waiting_bid')
          and (j.preferred_mitra_id is null or j.preferred_mitra_id = auth.uid())
        )
      )
  )
);

drop policy if exists "ayo_job_images_insert_customer" on public.job_images;
create policy "ayo_job_images_insert_customer"
on public.job_images for insert
to authenticated
with check (
  exists (
    select 1 from public.jobs j
    where j.id = job_images.job_id
      and j.customer_id = auth.uid()
  )
);

drop policy if exists "ayo_job_images_delete_customer" on public.job_images;
create policy "ayo_job_images_delete_customer"
on public.job_images for delete
to authenticated
using (
  exists (
    select 1 from public.jobs j
    where j.id = job_images.job_id
      and j.customer_id = auth.uid()
  )
);

grant select, insert, delete on public.job_images to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Foto katalog jasa Mitra (foto pertama menjadi cover, max 5)
-- ---------------------------------------------------------------------------
create table if not exists public.mitra_service_images (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.mitra_services(id) on delete cascade,
  storage_path text not null unique,
  sort_order integer not null default 0 check (sort_order between 0 and 4),
  is_cover boolean not null default false,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists mitra_service_images_service_idx
  on public.mitra_service_images(service_id, sort_order, created_at);
create unique index if not exists mitra_service_images_one_cover_idx
  on public.mitra_service_images(service_id)
  where is_cover = true;

create or replace function public.enforce_mitra_service_image_limit()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if (
    select count(*)
    from public.mitra_service_images msi
    where msi.service_id = new.service_id
  ) >= 5 then
    raise exception 'Maksimal 5 foto katalog untuk satu jasa.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_mitra_service_image_limit
on public.mitra_service_images;
create trigger trg_enforce_mitra_service_image_limit
before insert on public.mitra_service_images
for each row execute function public.enforce_mitra_service_image_limit();

alter table public.mitra_service_images enable row level security;

drop policy if exists "ayo_mitra_service_images_read" on public.mitra_service_images;
create policy "ayo_mitra_service_images_read"
on public.mitra_service_images for select
to authenticated
using (
  exists (
    select 1
    from public.mitra_services s
    left join public.mitras m on m.id = s.mitra_id
    where s.id = mitra_service_images.service_id
      and (
        s.mitra_id = auth.uid()
        or (s.is_active = true and coalesce(m.is_active, false) = true)
      )
  )
);

drop policy if exists "ayo_mitra_service_images_insert_own" on public.mitra_service_images;
create policy "ayo_mitra_service_images_insert_own"
on public.mitra_service_images for insert
to authenticated
with check (
  exists (
    select 1
    from public.mitra_services s
    where s.id = mitra_service_images.service_id
      and s.mitra_id = auth.uid()
  )
);

drop policy if exists "ayo_mitra_service_images_update_own" on public.mitra_service_images;
create policy "ayo_mitra_service_images_update_own"
on public.mitra_service_images for update
to authenticated
using (
  exists (
    select 1
    from public.mitra_services s
    where s.id = mitra_service_images.service_id
      and s.mitra_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.mitra_services s
    where s.id = mitra_service_images.service_id
      and s.mitra_id = auth.uid()
  )
);

drop policy if exists "ayo_mitra_service_images_delete_own" on public.mitra_service_images;
create policy "ayo_mitra_service_images_delete_own"
on public.mitra_service_images for delete
to authenticated
using (
  exists (
    select 1
    from public.mitra_services s
    where s.id = mitra_service_images.service_id
      and s.mitra_id = auth.uid()
  )
);

grant select, insert, update, delete on public.mitra_service_images to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Storage buckets. Foto pekerjaan bersifat privat dan dirender lewat
--    signed URL; foto katalog jasa bersifat publik untuk discovery marketplace.
--    Upload/delete tetap dibatasi folder UID user.
-- ---------------------------------------------------------------------------
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values
  (
    'job-images',
    'job-images',
    false,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  ),
  (
    'mitra-service-images',
    'mitra-service-images',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  )
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "ayo_job_images_storage_read" on storage.objects;
create policy "ayo_job_images_storage_read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'job-images'
  and exists (
    select 1
    from public.jobs j
    where j.id::text = (storage.foldername(name))[2]
      and (
        j.customer_id = auth.uid()
        or j.mitra_id = auth.uid()
        or (
          j.status::text in ('posted', 'waiting_bid')
          and (j.preferred_mitra_id is null or j.preferred_mitra_id = auth.uid())
        )
      )
  )
);

drop policy if exists "ayo_job_images_storage_insert_own" on storage.objects;
create policy "ayo_job_images_storage_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'job-images'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.jobs j
    where j.id::text = (storage.foldername(name))[2]
      and j.customer_id = auth.uid()
  )
);

drop policy if exists "ayo_job_images_storage_delete_own" on storage.objects;
create policy "ayo_job_images_storage_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'job-images'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.jobs j
    where j.id::text = (storage.foldername(name))[2]
      and j.customer_id = auth.uid()
  )
);

drop policy if exists "ayo_mitra_service_images_storage_read" on storage.objects;
create policy "ayo_mitra_service_images_storage_read"
on storage.objects for select
to authenticated
using (bucket_id = 'mitra-service-images');

drop policy if exists "ayo_mitra_service_images_storage_insert_own" on storage.objects;
create policy "ayo_mitra_service_images_storage_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'mitra-service-images'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.mitra_services s
    where s.id::text = (storage.foldername(name))[2]
      and s.mitra_id = auth.uid()
  )
);

drop policy if exists "ayo_mitra_service_images_storage_delete_own" on storage.objects;
create policy "ayo_mitra_service_images_storage_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'mitra-service-images'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.mitra_services s
    where s.id::text = (storage.foldername(name))[2]
      and s.mitra_id = auth.uid()
  )
);

commit;
