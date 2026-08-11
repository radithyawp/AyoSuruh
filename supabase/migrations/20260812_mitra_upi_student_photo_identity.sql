-- =============================================================================
-- AYO SURUH - VERIFIKASI MITRA MAHASISWA UPI + IDENTITAS BERFOTO
--
-- KTM UPI tetap menjadi bukti eligibility mahasiswa UPI.
-- Dokumen identitas berfoto disimpan terpisah untuk pencocokan manual dengan
-- selfie verifikasi oleh admin. Nomor identitas tidak disalin ke kolom terpisah.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Schema dokumen: KTM UPI + identitas berfoto + selfie adalah tiga bukti
--    yang berbeda dan memiliki tujuan verifikasi yang berbeda.
-- -----------------------------------------------------------------------------
alter table public.mitra_documents
  add column if not exists identity_document text,
  add column if not exists identity_document_type text;

alter table public.mitra_documents
  drop constraint if exists mitra_documents_identity_document_type_check;

alter table public.mitra_documents
  add constraint mitra_documents_identity_document_type_check
  check (
    identity_document_type is null
    or identity_document_type in ('ktp', 'sim', 'passport', 'kitas_kitap', 'other')
  );

comment on column public.mitra_documents.ktm is
  'Path KTM UPI untuk membuktikan eligibility pendaftar sebagai mahasiswa UPI. Pas foto tidak diwajibkan pada KTM.';
comment on column public.mitra_documents.identity_document is
  'Path identitas legal berfoto yang dipakai admin untuk pencocokan manual dengan selfie verifikasi.';
comment on column public.mitra_documents.identity_document_type is
  'Jenis identitas berfoto: ktp, sim, passport, kitas_kitap, atau other.';

-- -----------------------------------------------------------------------------
-- 2. Kontrak Mitra versi 1.1: scope mahasiswa UPI + dokumen verifikasi baru.
--    Simpan versi Bahasa Indonesia dan English agar halaman kontrak mengikuti
--    bahasa aplikasi tanpa menerjemahkan dokumen hukum secara heuristik.
-- -----------------------------------------------------------------------------
alter table public.mitra_contract_versions
  add column if not exists title_en text,
  add column if not exists content_en text;

insert into public.mitra_contract_versions(
  version, title, content, title_en, content_en, is_active, effective_at
) values (
  '1.1',
  'Kontrak Kemitraan Ayo Suruh',
  $contract_id$
KONTRAK KEMITRAAN AYO SURUH — VERSI 1.1

1. Cakupan Mitra Saat Ini
Untuk rilis saat ini, pendaftaran Mitra Ayo Suruh dibatasi bagi mahasiswa aktif Universitas Pendidikan Indonesia (UPI). KTM UPI digunakan untuk membuktikan eligibility mahasiswa dan tidak diwajibkan memuat pas foto.

2. Kebenaran Data dan Verifikasi Identitas
Mitra wajib memberikan data pendaftaran yang benar. Pendaftar wajib mengunggah KTM UPI, satu identitas legal berfoto yang masih berlaku (misalnya KTP, SIM, Paspor, KITAS/KITAP, atau identitas sah lain), serta selfie verifikasi yang diambil langsung dengan kamera depan. Admin memeriksa KTM dan mencocokkan selfie secara manual dengan pas foto pada identitas yang dikirim. Alur ini tidak menggunakan pengenalan wajah otomatis.

3. Status Kemitraan
Mitra adalah pengguna independen yang menawarkan keterampilan/jasa melalui platform Ayo Suruh. Persetujuan ini tidak membentuk hubungan kerja, kepegawaian, atau agensi antara Mitra dan Ayo Suruh.

4. Standar Layanan
Mitra wajib menjalankan pekerjaan sesuai deskripsi yang disepakati, menjaga komunikasi yang sopan, hadir sesuai kesepakatan, menjaga keamanan, serta tidak melakukan tindakan yang melanggar hukum atau merugikan Customer.

5. Harga, Pembayaran, dan Biaya Platform
Harga pekerjaan mengikuti penawaran/kesepakatan pada aplikasi. Untuk transaksi yang menggunakan pembayaran platform, Ayo Suruh dapat mengenakan biaya platform sesuai informasi yang ditampilkan pada aplikasi. Pada versi layanan saat ini, acuan biaya platform adalah 6% dan dapat diperbarui secara transparan pada versi ketentuan berikutnya.

6. Pencairan dan Dana Tertahan
Pendapatan Mitra dapat melalui status pending, tersedia, ditahan, atau dicairkan. Dana dapat ditahan sementara jika terdapat pekerjaan aktif, refund/dispute, pemeriksaan transaksi, atau proses pencairan yang belum selesai.

7. Pembatalan, Refund, dan Dispute
Mitra memahami bahwa transaksi tertentu dapat dibatalkan atau direfund sesuai status pekerjaan, bukti transaksi, dan hasil peninjauan. Jika pendapatan sudah tercatat lalu transaksi direfund, penyesuaian ledger dapat dilakukan sesuai alur yang tampil pada aplikasi.

8. Data Customer dan Kerahasiaan
Mitra hanya boleh menggunakan alamat, nomor kontak, chat, dan data Customer untuk menyelesaikan pekerjaan terkait. Data tersebut tidak boleh disebarkan, dijual, atau digunakan untuk tujuan lain tanpa izin yang sah.

9. Perilaku yang Dilarang
Mitra dilarang melakukan penipuan, intimidasi, transaksi fiktif, manipulasi rating, penyalahgunaan data pribadi, pengalihan pembayaran yang melanggar kebijakan platform, atau tindakan lain yang membahayakan pengguna maupun reputasi layanan.

10. Penangguhan dan Pengakhiran Kemitraan
Ayo Suruh dapat menangguhkan akses Mitra ketika terdapat dugaan pelanggaran, eligibility mahasiswa tidak lagi terpenuhi, kewajiban transaksi belum selesai, atau terdapat kebutuhan pemeriksaan. Mitra dapat menghapus akun setelah pekerjaan aktif, refund/dispute, pencairan, dan saldo yang diwajibkan telah diselesaikan.

11. Persetujuan Elektronik dan Perubahan Versi
Dengan mencentang persetujuan dan mengirim pengajuan, Mitra menyatakan telah membaca serta menyetujui kontrak versi yang tampil. Waktu persetujuan dicatat oleh sistem. Jika kontrak berubah secara material, Ayo Suruh dapat meminta persetujuan terhadap versi baru.

Catatan: dokumen elektronik ini merupakan persetujuan operasional penggunaan platform Ayo Suruh dan bukan pengganti konsultasi hukum atau dokumen e-signature formal apabila di kemudian hari dibutuhkan untuk penggunaan komersial penuh.
  $contract_id$,
  'Ayo Suruh Partner Agreement',
  $contract_en$
AYO SURUH PARTNER AGREEMENT — VERSION 1.1

1. Current Partner Scope
For the current release, Ayo Suruh Partner registration is limited to active Universitas Pendidikan Indonesia (UPI) students. The UPI Student Card (KTM) is used to confirm student eligibility and is not required to contain a portrait photo.

2. Accurate Information and Identity Verification
Partners must provide accurate registration information. Applicants must upload a UPI Student Card, one valid legal photo identity document (for example KTP, SIM, Passport, KITAS/KITAP, or another valid legal photo ID), and a verification selfie taken directly with the front camera. The admin checks the KTM and manually compares the selfie with the portrait on the submitted photo ID. This flow does not use automated facial recognition.

3. Partnership Status
Partners are independent users who offer skills/services through the Ayo Suruh platform. This agreement does not create an employment, employee, or agency relationship between the Partner and Ayo Suruh.

4. Service Standards
Partners must perform jobs according to the agreed description, communicate professionally, arrive as agreed, maintain safety, and avoid unlawful actions or conduct that harms Customers.

5. Pricing, Payments, and Platform Fees
Job prices follow offers/agreements recorded in the app. For transactions using platform payments, Ayo Suruh may charge a platform fee as shown in the app. The current reference platform fee is 6% and may be transparently updated in a future terms version.

6. Withdrawals and Held Funds
Partner earnings may move through pending, available, held, or paid-out states. Funds may be held temporarily when there are active jobs, refunds/disputes, transaction reviews, or unfinished withdrawal processes.

7. Cancellation, Refund, and Dispute
Partners understand that certain transactions may be cancelled or refunded depending on job status, transaction evidence, and review outcomes. If earnings were already recorded before a refund, the ledger may be adjusted according to the flow shown in the app.

8. Customer Data and Confidentiality
Partners may only use Customer addresses, contact details, chat, and other Customer data to complete the relevant job. The data must not be distributed, sold, or used for other purposes without a lawful basis.

9. Prohibited Conduct
Partners must not engage in fraud, intimidation, fake transactions, rating manipulation, misuse of personal data, payment diversion that violates platform policy, or other conduct that endangers users or the service.

10. Suspension and Termination
Ayo Suruh may suspend Partner access when there is a suspected violation, student eligibility is no longer met, transaction obligations remain unresolved, or a review is required. Partners may delete their account after required active jobs, refunds/disputes, withdrawals, and balances have been resolved.

11. Electronic Acceptance and Version Changes
By checking the agreement box and submitting an application, the Partner confirms that they have read and accepted the displayed contract version. The acceptance time is recorded by the system. If the contract changes materially, Ayo Suruh may require acceptance of a new version.

Note: this electronic document is an operational agreement for use of the Ayo Suruh platform and is not a substitute for legal advice or a formal e-signature document if one is later required for full commercial use.
  $contract_en$,
  false,
  timezone('utc'::text, now())
)
on conflict (version) do update
set title = excluded.title,
    content = excluded.content,
    title_en = excluded.title_en,
    content_en = excluded.content_en,
    effective_at = excluded.effective_at;

update public.mitra_contract_versions
set is_active = false
where is_active = true;

update public.mitra_contract_versions
set is_active = true
where version = '1.1';

drop function if exists public.get_active_mitra_contract();
create function public.get_active_mitra_contract()
returns table (
  version text,
  title text,
  content text,
  title_en text,
  content_en text,
  effective_at timestamp with time zone
)
language sql
security definer
set search_path = public
as $$
  select c.version, c.title, c.content, c.title_en, c.content_en, c.effective_at
  from public.mitra_contract_versions c
  where c.is_active = true
  order by c.effective_at desc
  limit 1;
$$;

revoke all on function public.get_active_mitra_contract() from public, anon;
grant execute on function public.get_active_mitra_contract() to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Pengajuan milik user: expose tiga dokumen secara terpisah.
-- -----------------------------------------------------------------------------
drop function if exists public.get_my_mitra_application();
create function public.get_my_mitra_application()
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
  identity_document text,
  identity_document_type text,
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
    document.identity_document,
    document.identity_document_type,
    document.selfie
  from public.mitra_applications application
  left join lateral (
    select
      docs.ktm,
      docs.identity_document,
      docs.identity_document_type,
      docs.selfie
    from public.mitra_documents docs
    where docs.application_id = application.id
    order by docs.created_at desc
    limit 1
  ) document on true
  where application.user_id = auth.uid()
  order by application.created_at desc
  limit 1;
$$;

revoke all on function public.get_my_mitra_application() from public, anon;
grant execute on function public.get_my_mitra_application() to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Submission baru mewajibkan KTM UPI + identitas legal berfoto + selfie.
-- -----------------------------------------------------------------------------
drop function if exists public.submit_mitra_application(
  text, text, text, text, text, text, text, boolean
);
drop function if exists public.submit_mitra_application(
  text, text, text, text, text, text, text, text, text, boolean
);

create function public.submit_mitra_application(
  p_fullname text,
  p_phone text,
  p_address text,
  p_bank_name text,
  p_account_number text,
  p_ktm_path text,
  p_identity_document_path text,
  p_identity_document_type text,
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
  v_identity_type text := lower(trim(coalesce(p_identity_document_type, '')));
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

  if v_identity_type not in ('ktp', 'sim', 'passport', 'kitas_kitap', 'other') then
    raise exception 'Jenis kartu identitas berfoto tidak valid.';
  end if;

  v_prefix := v_user_id::text || '/';
  if position(v_prefix in coalesce(p_ktm_path, '')) <> 1
     or position(v_prefix in coalesce(p_identity_document_path, '')) <> 1
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
      identity_document,
      identity_document_type,
      selfie,
      verified,
      created_at,
      updated_at
    ) values (
      v_application_id,
      p_ktm_path,
      p_identity_document_path,
      v_identity_type,
      p_selfie_path,
      false,
      timezone('utc'::text, now()),
      timezone('utc'::text, now())
    );
  else
    update public.mitra_documents
    set ktm = p_ktm_path,
        identity_document = p_identity_document_path,
        identity_document_type = v_identity_type,
        selfie = p_selfie_path,
        verified = false,
        updated_at = timezone('utc'::text, now())
    where id = v_document_id;
  end if;

  perform public.enqueue_notification(
    v_user_id,
    'Pengajuan Mitra Terkirim',
    'KTM UPI, identitas berfoto, dan selfie verifikasi sudah diterima. Proses verifikasi membutuhkan waktu 1–3 hari kerja.',
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
  text, text, text, text, text, text, text, text, text, boolean
) from public, anon;
grant execute on function public.submit_mitra_application(
  text, text, text, text, text, text, text, text, text, boolean
) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Admin tidak boleh approve pengajuan baru jika salah satu bukti verifikasi
--    belum ada. Pengajuan lama yang sudah approved tidak diubah.
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
  v_has_complete_documents boolean := false;
begin
  select application.user_id
  into v_user_id
  from public.mitra_applications application
  where application.id = p_application_id
  for update;

  if v_user_id is null then
    raise exception 'Pengajuan mitra tidak ditemukan.';
  end if;

  select exists (
    select 1
    from public.mitra_documents docs
    where docs.application_id = p_application_id
      and nullif(trim(coalesce(docs.ktm, '')), '') is not null
      and nullif(trim(coalesce(docs.identity_document, '')), '') is not null
      and docs.identity_document_type in ('ktp', 'sim', 'passport', 'kitas_kitap', 'other')
      and nullif(trim(coalesce(docs.selfie, '')), '') is not null
  ) into v_has_complete_documents;

  if not v_has_complete_documents then
    raise exception 'Dokumen verifikasi belum lengkap. KTM UPI, identitas berfoto, dan selfie wajib tersedia.';
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

-- -----------------------------------------------------------------------------
-- 6. Antrean Admin: tampilkan KTM dan identitas berfoto sebagai dokumen berbeda.
--    Tetap sertakan bukti kontrak dari migration P1 sebelumnya.
-- -----------------------------------------------------------------------------
drop function if exists public.admin_list_mitra_applications();
create function public.admin_list_mitra_applications()
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
  identity_document_url text,
  identity_document_type text,
  selfie_url text,
  contract_version text,
  contract_accepted_at timestamp with time zone
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
    d.identity_document,
    d.identity_document_type,
    d.selfie,
    ca.contract_version,
    ca.accepted_at
  from public.mitra_applications a
  join public.users u on u.id = a.user_id
  left join lateral (
    select
      docs.ktm,
      docs.identity_document,
      docs.identity_document_type,
      docs.selfie
    from public.mitra_documents docs
    where docs.application_id = a.id
    order by docs.created_at desc
    limit 1
  ) d on true
  left join lateral (
    select acceptance.contract_version, acceptance.accepted_at
    from public.mitra_contract_acceptances acceptance
    where acceptance.user_id = a.user_id
    order by acceptance.accepted_at desc
    limit 1
  ) ca on true
  order by
    case when a.status = 'applied'::public.application_status then 0 else 1 end,
    a.created_at desc;
end;
$$;

revoke all on function public.admin_list_mitra_applications() from public;
grant execute on function public.admin_list_mitra_applications() to authenticated;

-- -----------------------------------------------------------------------------
-- 7. Account deletion: dokumen identitas baru ikut dimasukkan ke daftar file
--    storage yang harus dihapus dan path-nya dinolkan dari database.
-- -----------------------------------------------------------------------------
create or replace function public.prepare_my_account_deletion(
  p_reason_code text default null,
  p_reason_label text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_readiness jsonb;
  v_role text := 'customer';
  v_paths jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  v_readiness := public.get_account_deletion_readiness();
  if not coalesce((v_readiness ->> 'can_delete')::boolean, false) then
    raise exception 'Akun belum dapat dihapus. Selesaikan pekerjaan, refund, pencairan, dan saldo terlebih dahulu.';
  end if;

  if exists (select 1 from public.mitras m where m.id = v_user_id) then
    v_role := 'mitra';
  end if;

  select coalesce(jsonb_agg(path), '[]'::jsonb)
  into v_paths
  from (
    select d.ktm as path
    from public.mitra_documents d
    join public.mitra_applications a on a.id = d.application_id
    where a.user_id = v_user_id and nullif(trim(coalesce(d.ktm, '')), '') is not null
    union all
    select d.identity_document as path
    from public.mitra_documents d
    join public.mitra_applications a on a.id = d.application_id
    where a.user_id = v_user_id and nullif(trim(coalesce(d.identity_document, '')), '') is not null
    union all
    select d.selfie as path
    from public.mitra_documents d
    join public.mitra_applications a on a.id = d.application_id
    where a.user_id = v_user_id and nullif(trim(coalesce(d.selfie, '')), '') is not null
  ) paths;

  insert into public.account_exit_surveys(
    user_id, action, reason_code, reason_label, note, role_snapshot
  ) values (
    v_user_id,
    'delete',
    nullif(trim(coalesce(p_reason_code, '')), ''),
    nullif(trim(coalesce(p_reason_label, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    v_role
  );

  delete from public.device_tokens where user_id = v_user_id;
  delete from public.notifications where user_id = v_user_id;

  update public.addresses
  set label = 'Alamat dihapus',
      address = 'Data alamat telah dihapus oleh pengguna',
      latitude = null,
      longitude = null,
      is_default = false
  where user_id = v_user_id;

  update public.mitra_documents d
  set ktm = null,
      identity_document = null,
      identity_document_type = null,
      selfie = null,
      verified = false,
      updated_at = timezone('utc'::text, now())
  from public.mitra_applications a
  where d.application_id = a.id
    and a.user_id = v_user_id;

  update public.mitra_applications
  set address = 'Data alamat telah dihapus oleh pengguna',
      bank_name = null,
      account_number = null,
      updated_at = timezone('utc'::text, now())
  where user_id = v_user_id;

  delete from public.mitra_bank_accounts where mitra_id = v_user_id;
  update public.mitra_services set is_active = false where mitra_id = v_user_id;
  update public.mitras set is_active = false where id = v_user_id;

  update public.users
  set email = null,
      fullname = 'Pengguna Dihapus',
      phone = null,
      avatar_url = null,
      alamat = null,
      account_state = 'deleted',
      deleted_at = timezone('utc'::text, now()),
      deactivated_at = null
  where id = v_user_id;

  return jsonb_build_object(
    'ok', true,
    'user_id', v_user_id,
    'mitra_document_paths', v_paths
  );
end;
$$;

revoke all on function public.prepare_my_account_deletion(text, text, text)
  from public, anon;
grant execute on function public.prepare_my_account_deletion(text, text, text)
  to authenticated;

commit;
