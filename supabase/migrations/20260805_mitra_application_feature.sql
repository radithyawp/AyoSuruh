-- =============================================================================
-- AYO SURUH - PENDAFTARAN DAN VERIFIKASI MITRA
-- Jalankan setelah migration fitur notifikasi.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Lengkapi data pengajuan mitra
-- -----------------------------------------------------------------------------
alter table public.mitra_applications
  add column if not exists bank_name text,
  add column if not exists account_number text,
  add column if not exists terms_accepted_at timestamp with time zone,
  add column if not exists review_notes text,
  add column if not exists reviewed_at timestamp with time zone,
  add column if not exists updated_at timestamp with time zone
    not null default timezone('utc'::text, now());

alter table public.mitra_documents
  add column if not exists updated_at timestamp with time zone
    not null default timezone('utc'::text, now());

create index if not exists mitra_applications_user_created_idx
  on public.mitra_applications (user_id, created_at desc);

create index if not exists mitra_applications_status_created_idx
  on public.mitra_applications (status, created_at desc);

create index if not exists mitra_documents_application_created_idx
  on public.mitra_documents (application_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 2. RLS: pendaftar hanya dapat membaca pengajuan dan dokumennya sendiri
-- -----------------------------------------------------------------------------
alter table public.mitra_applications enable row level security;
alter table public.mitra_documents enable row level security;

drop policy if exists "ayo_mitra_applications_read_own"
  on public.mitra_applications;
create policy "ayo_mitra_applications_read_own"
on public.mitra_applications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "ayo_mitra_documents_read_own"
  on public.mitra_documents;
create policy "ayo_mitra_documents_read_own"
on public.mitra_documents
for select
to authenticated
using (
  exists (
    select 1
    from public.mitra_applications application
    where application.id = mitra_documents.application_id
      and application.user_id = auth.uid()
  )
);

grant select on public.mitra_applications to authenticated;
grant select on public.mitra_documents to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Ambil pengajuan terbaru milik user yang sedang login
-- -----------------------------------------------------------------------------
create or replace function public.get_my_mitra_application()
returns table (
  id uuid,
  user_id uuid,
  address text,
  description text,
  status public.application_status,
  bank_name text,
  account_number text,
  terms_accepted_at timestamp with time zone,
  review_notes text,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  ktm text,
  selfie text
)
language sql
security definer
set search_path = public
as $$
  select
    application.id,
    application.user_id,
    application.address,
    application.description,
    application.status,
    application.bank_name,
    application.account_number,
    application.terms_accepted_at,
    application.review_notes,
    application.reviewed_at,
    application.created_at,
    application.updated_at,
    document.ktm,
    document.selfie
  from public.mitra_applications application
  left join lateral (
    select docs.ktm, docs.selfie
    from public.mitra_documents docs
    where docs.application_id = application.id
    order by docs.created_at desc
    limit 1
  ) document on true
  where application.user_id = auth.uid()
  order by application.created_at desc
  limit 1;
$$;

revoke all on function public.get_my_mitra_application()
  from public, anon;
grant execute on function public.get_my_mitra_application()
  to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Kirim atau kirim ulang pengajuan mitra secara atomik
-- -----------------------------------------------------------------------------
create or replace function public.submit_mitra_application(
  p_fullname text,
  p_phone text,
  p_address text,
  p_bank_name text,
  p_account_number text,
  p_ktm_path text,
  p_selfie_path text,
  p_terms_accepted boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_application_id uuid;
  v_document_id uuid;
  v_status public.application_status;
  v_prefix text;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not coalesce(p_terms_accepted, false) then
    raise exception 'Syarat & Ketentuan wajib disetujui.';
  end if;

  if char_length(trim(coalesce(p_fullname, ''))) < 3 then
    raise exception 'Nama lengkap wajib diisi.';
  end if;

  if char_length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) < 10 then
    raise exception 'Nomor WhatsApp belum valid.';
  end if;

  if char_length(trim(coalesce(p_address, ''))) < 10 then
    raise exception 'Alamat lengkap wajib diisi.';
  end if;

  if trim(coalesce(p_bank_name, '')) = ''
     or char_length(trim(coalesce(p_account_number, ''))) < 6 then
    raise exception 'Data rekening atau e-wallet belum lengkap.';
  end if;

  v_prefix := v_user_id::text || '/';
  if position(v_prefix in coalesce(p_ktm_path, '')) <> 1
     or position(v_prefix in coalesce(p_selfie_path, '')) <> 1 then
    raise exception 'Lokasi dokumen tidak valid.';
  end if;

  select application.id, application.status
  into v_application_id, v_status
  from public.mitra_applications application
  where application.user_id = v_user_id
  order by application.created_at desc
  limit 1
  for update;

  if v_status = 'approved'::public.application_status then
    raise exception 'Akun sudah disetujui sebagai mitra.';
  end if;

  if v_status = 'applied'::public.application_status then
    raise exception 'Pengajuan masih dalam proses verifikasi.';
  end if;

  update public.users
  set fullname = trim(p_fullname),
      phone = trim(p_phone),
      alamat = trim(p_address)
  where id = v_user_id;

  if v_application_id is null then
    insert into public.mitra_applications (
      user_id,
      address,
      description,
      status,
      bank_name,
      account_number,
      terms_accepted_at,
      created_at,
      updated_at
    ) values (
      v_user_id,
      trim(p_address),
      'Pengajuan menjadi Mitra Ayo Suruh',
      'applied'::public.application_status,
      trim(p_bank_name),
      trim(p_account_number),
      timezone('utc'::text, now()),
      timezone('utc'::text, now()),
      timezone('utc'::text, now())
    )
    returning id into v_application_id;
  else
    update public.mitra_applications
    set address = trim(p_address),
        description = 'Pengajuan menjadi Mitra Ayo Suruh',
        status = 'applied'::public.application_status,
        bank_name = trim(p_bank_name),
        account_number = trim(p_account_number),
        terms_accepted_at = timezone('utc'::text, now()),
        review_notes = null,
        reviewed_at = null,
        updated_at = timezone('utc'::text, now())
    where id = v_application_id;
  end if;

  select docs.id
  into v_document_id
  from public.mitra_documents docs
  where docs.application_id = v_application_id
  order by docs.created_at desc
  limit 1
  for update;

  if v_document_id is null then
    insert into public.mitra_documents (
      application_id,
      ktm,
      selfie,
      verified,
      created_at,
      updated_at
    ) values (
      v_application_id,
      p_ktm_path,
      p_selfie_path,
      false,
      timezone('utc'::text, now()),
      timezone('utc'::text, now())
    );
  else
    update public.mitra_documents
    set ktm = p_ktm_path,
        selfie = p_selfie_path,
        verified = false,
        updated_at = timezone('utc'::text, now())
    where id = v_document_id;
  end if;

  perform public.enqueue_notification(
    v_user_id,
    'Pengajuan Mitra Terkirim',
    'Data dan dokumenmu sudah diterima. Proses verifikasi membutuhkan waktu 1–3 hari kerja.',
    'mitra_application_submitted',
    null,
    null,
    null,
    jsonb_build_object('application_id', v_application_id)
  );

  return v_application_id;
end;
$$;

revoke all on function public.submit_mitra_application(
  text, text, text, text, text, text, text, boolean
) from public, anon;
grant execute on function public.submit_mitra_application(
  text, text, text, text, text, text, text, boolean
) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Helper approval admin. Fungsi ini tidak diberikan kepada authenticated.
--    Jalankan dari SQL Editor atau backend yang menggunakan service role.
-- -----------------------------------------------------------------------------
create or replace function public.approve_mitra_application(
  p_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  select application.user_id
  into v_user_id
  from public.mitra_applications application
  where application.id = p_application_id
  for update;

  if v_user_id is null then
    raise exception 'Pengajuan mitra tidak ditemukan.';
  end if;

  update public.mitra_applications
  set status = 'approved'::public.application_status,
      review_notes = null,
      reviewed_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  where id = p_application_id;

  update public.mitra_documents
  set verified = true,
      updated_at = timezone('utc'::text, now())
  where application_id = p_application_id;

  update public.users
  set role = 'mitra'::public.user_role
  where id = v_user_id;

  insert into public.mitras (id, rating, is_active)
  values (v_user_id, 0, true)
  on conflict (id) do update
  set is_active = true;

  perform public.enqueue_notification(
    v_user_id,
    'Pengajuan Mitra Disetujui',
    'Selamat! Akunmu sekarang aktif sebagai Mitra Ayo Suruh.',
    'mitra_application_approved',
    null,
    null,
    null,
    jsonb_build_object('application_id', p_application_id)
  );
end;
$$;

revoke all on function public.approve_mitra_application(uuid)
  from public, anon, authenticated;
grant execute on function public.approve_mitra_application(uuid)
  to service_role;

create or replace function public.reject_mitra_application(
  p_application_id uuid,
  p_review_notes text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_notes text := trim(coalesce(p_review_notes, ''));
begin
  if v_notes = '' then
    raise exception 'Catatan penolakan wajib diisi.';
  end if;

  select application.user_id
  into v_user_id
  from public.mitra_applications application
  where application.id = p_application_id
  for update;

  if v_user_id is null then
    raise exception 'Pengajuan mitra tidak ditemukan.';
  end if;

  update public.mitra_applications
  set status = 'rejected'::public.application_status,
      review_notes = v_notes,
      reviewed_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  where id = p_application_id;

  update public.mitra_documents
  set verified = false,
      updated_at = timezone('utc'::text, now())
  where application_id = p_application_id;

  perform public.enqueue_notification(
    v_user_id,
    'Pengajuan Mitra Perlu Diperbaiki',
    v_notes,
    'mitra_application_rejected',
    null,
    null,
    null,
    jsonb_build_object('application_id', p_application_id)
  );
end;
$$;

revoke all on function public.reject_mitra_application(uuid, text)
  from public, anon, authenticated;
grant execute on function public.reject_mitra_application(uuid, text)
  to service_role;

-- -----------------------------------------------------------------------------
-- 6. Storage dokumen mitra bersifat privat
-- -----------------------------------------------------------------------------
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'mitra-documents',
  'mitra-documents',
  false,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "ayo_mitra_documents_storage_read_own"
  on storage.objects;
create policy "ayo_mitra_documents_storage_read_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'mitra-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "ayo_mitra_documents_storage_insert_own"
  on storage.objects;
create policy "ayo_mitra_documents_storage_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'mitra-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "ayo_mitra_documents_storage_update_own"
  on storage.objects;
create policy "ayo_mitra_documents_storage_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'mitra-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'mitra-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "ayo_mitra_documents_storage_delete_own"
  on storage.objects;
create policy "ayo_mitra_documents_storage_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'mitra-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;

-- =============================================================================
-- CONTOH OPERASI ADMIN DI SQL EDITOR
-- =============================================================================
-- 1. Lihat antrean pengajuan:
-- select a.id, u.email, u.fullname, a.address, a.bank_name,
--        a.account_number, a.status, a.created_at, d.ktm, d.selfie
-- from public.mitra_applications a
-- join public.users u on u.id = a.user_id
-- left join lateral (
--   select md.ktm, md.selfie
--   from public.mitra_documents md
--   where md.application_id = a.id
--   order by md.created_at desc
--   limit 1
-- ) d on true
-- order by a.created_at desc;
--
-- 2. Setujui:
-- select public.approve_mitra_application('APPLICATION_UUID');
--
-- 3. Tolak dan berikan alasan:
-- select public.reject_mitra_application(
--   'APPLICATION_UUID',
--   'Foto KTM kurang jelas. Silakan unggah ulang.'
-- );
