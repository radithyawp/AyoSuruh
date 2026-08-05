-- Ayo Suruh - progres pekerjaan mitra dan konfirmasi customer
-- Jalankan setelah 20260805_job_bidding_feature.sql.

-- ---------------------------------------------------------------------------
-- 1. Struktur progres dan bukti pekerjaan
-- ---------------------------------------------------------------------------
do $$
begin
  create type public.job_progress_stage as enum (
    'heading_to_location',
    'arrived',
    'working',
    'completion_submitted'
  );
exception
  when duplicate_object then null;
end
$$;

alter table public.jobs
  add column if not exists progress_stage public.job_progress_stage;

alter table public.job_timelines
  add column if not exists progress_stage public.job_progress_stage,
  add column if not exists evidence_url text;

-- Job yang sudah terlanjur dimulai sebelum migration dianggap sedang menuju lokasi.
update public.jobs
set progress_stage = 'heading_to_location'::public.job_progress_stage
where status = 'on_progress'::public.job_status
  and progress_stage is null;

-- ---------------------------------------------------------------------------
-- 2. Perbarui RPC mulai pekerjaan agar tahap awal langsung tercatat
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
-- 3. RPC mitra memperbarui progres secara berurutan
-- ---------------------------------------------------------------------------
create or replace function public.advance_job_progress(
  p_job_id uuid,
  p_progress_stage public.job_progress_stage,
  p_note text default null,
  p_evidence_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.job_status;
  v_current public.job_progress_stage;
  v_default_description text;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select
    j.status,
    coalesce(
      j.progress_stage,
      'heading_to_location'::public.job_progress_stage
    )
  into v_status, v_current
  from public.jobs j
  where j.id = p_job_id
    and j.mitra_id = auth.uid()
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan atau bukan milik mitra ini.';
  end if;

  if v_status <> 'on_progress'::public.job_status then
    raise exception 'Pekerjaan belum dalam status sedang dikerjakan.';
  end if;

  if v_current = 'heading_to_location'::public.job_progress_stage
     and p_progress_stage <> 'arrived'::public.job_progress_stage then
    raise exception 'Tahap berikutnya harus Tiba di Lokasi.';
  elsif v_current = 'arrived'::public.job_progress_stage
     and p_progress_stage <> 'working'::public.job_progress_stage then
    raise exception 'Tahap berikutnya harus Mulai Bekerja.';
  elsif v_current = 'working'::public.job_progress_stage
     and p_progress_stage <> 'completion_submitted'::public.job_progress_stage then
    raise exception 'Tahap berikutnya harus Pekerjaan Selesai.';
  elsif v_current = 'completion_submitted'::public.job_progress_stage then
    raise exception 'Pekerjaan sudah diajukan selesai dan menunggu konfirmasi customer.';
  end if;

  v_default_description := case p_progress_stage
    when 'arrived'::public.job_progress_stage
      then 'Mitra sudah tiba di lokasi pekerjaan.'
    when 'working'::public.job_progress_stage
      then 'Mitra mulai melaksanakan pekerjaan.'
    when 'completion_submitted'::public.job_progress_stage
      then 'Mitra telah menyelesaikan pekerjaan dan menunggu konfirmasi customer.'
    else 'Progres pekerjaan diperbarui.'
  end;

  update public.jobs
  set progress_stage = p_progress_stage
  where id = p_job_id;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description,
    evidence_url
  ) values (
    p_job_id,
    'on_progress'::public.job_status,
    p_progress_stage,
    coalesce(nullif(trim(p_note), ''), v_default_description),
    nullif(trim(p_evidence_url), '')
  );
end;
$$;

revoke all on function public.advance_job_progress(
  uuid,
  public.job_progress_stage,
  text,
  text
) from public;
grant execute on function public.advance_job_progress(
  uuid,
  public.job_progress_stage,
  text,
  text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC customer mengonfirmasi pekerjaan selesai
-- ---------------------------------------------------------------------------
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
end;
$$;

revoke all on function public.confirm_job_completion(uuid) from public;
grant execute on function public.confirm_job_completion(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC profil peserta job yang aman untuk mengatasi relasi users terkena RLS
-- ---------------------------------------------------------------------------
create or replace function public.get_job_participant_profile(
  p_job_id uuid,
  p_participant text
)
returns table (
  id uuid,
  fullname text,
  avatar_url text,
  phone text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if lower(p_participant) = 'customer' then
    return query
    select u.id, u.fullname, u.avatar_url, u.phone
    from public.jobs j
    join public.users u on u.id = j.customer_id
    where j.id = p_job_id
      and (
        j.customer_id = auth.uid()
        or j.mitra_id = auth.uid()
        or j.status in (
          'posted'::public.job_status,
          'waiting_bid'::public.job_status
        )
      );
  elsif lower(p_participant) = 'mitra' then
    return query
    select u.id, u.fullname, u.avatar_url, u.phone
    from public.jobs j
    join public.users u on u.id = j.mitra_id
    where j.id = p_job_id
      and j.mitra_id is not null
      and (j.customer_id = auth.uid() or j.mitra_id = auth.uid());
  else
    raise exception 'Jenis peserta tidak dikenali.';
  end if;
end;
$$;

revoke all on function public.get_job_participant_profile(uuid, text) from public;
grant execute on function public.get_job_participant_profile(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Bucket dan policy bukti pekerjaan
-- ---------------------------------------------------------------------------
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'job-evidence',
  'job-evidence',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "ayo_job_evidence_read" on storage.objects;
create policy "ayo_job_evidence_read"
on storage.objects for select
to authenticated
using (bucket_id = 'job-evidence');

drop policy if exists "ayo_job_evidence_insert_own" on storage.objects;
create policy "ayo_job_evidence_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'job-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "ayo_job_evidence_update_own" on storage.objects;
create policy "ayo_job_evidence_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'job-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'job-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "ayo_job_evidence_delete_own" on storage.objects;
create policy "ayo_job_evidence_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'job-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);
