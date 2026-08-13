-- Ayo Suruh - device-based phone confirmation (free launch flow)
-- Phone Number Hint is a SIM/device hint, not SMS OTP and not legal identity proof.
-- Safe to run once on the target project; statements are idempotent where possible.

alter table public.users
  add column if not exists phone_verification_level text not null default 'unverified',
  add column if not exists phone_confirmation_method text,
  add column if not exists phone_confirmed_at timestamp with time zone;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_phone_verification_level_check'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_phone_verification_level_check
      check (phone_verification_level in ('unverified', 'device_confirmed', 'verified'));
  end if;
end
$$;

comment on column public.users.phone_verification_level is
  'Phone trust level: unverified (manual), device_confirmed (Android Phone Number Hint), verified (reserved for future SMS/carrier verification).';
comment on column public.users.phone_confirmation_method is
  'How the current phone number trust state was obtained, e.g. manual, phone_number_hint, sms_or_carrier.';
comment on column public.users.phone_confirmed_at is
  'Timestamp when the current phone number reached device_confirmed or verified state.';

-- If Supabase Auth already has a genuinely confirmed phone, preserve that
-- stronger signal as VERIFIED. Most existing Ayo Suruh accounts will remain
-- unverified until they use the new device-confirmation flow.
update public.users u
set
  phone_verification_level = 'verified',
  phone_confirmation_method = 'sms_or_carrier',
  phone_confirmed_at = coalesce(u.phone_confirmed_at, au.phone_confirmed_at)
from auth.users au
where au.id = u.id
  and au.phone_confirmed_at is not null
  and nullif(trim(au.phone), '') is not null
  and regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g') =
      regexp_replace(coalesce(au.phone, ''), '[^0-9]', '', 'g');

create or replace function public.guard_user_phone_confirmation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  -- Legacy updates that change only the phone must never retain a confirmation
  -- state that belonged to the previous number.
  if new.phone is distinct from old.phone
     and new.phone_verification_level is not distinct from old.phone_verification_level then
    new.phone_verification_level := 'unverified';
    new.phone_confirmation_method := 'manual';
    new.phone_confirmed_at := null;
  end if;

  if new.phone_verification_level = 'unverified' then
    new.phone_confirmation_method := coalesce(new.phone_confirmation_method, 'manual');
    new.phone_confirmed_at := null;
  elsif new.phone_verification_level = 'device_confirmed' then
    new.phone_confirmation_method := 'phone_number_hint';
    new.phone_confirmed_at := coalesce(new.phone_confirmed_at, timezone('utc', now()));
  elsif new.phone_verification_level = 'verified' then
    new.phone_confirmation_method := coalesce(new.phone_confirmation_method, 'sms_or_carrier');
    new.phone_confirmed_at := coalesce(new.phone_confirmed_at, timezone('utc', now()));
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_user_phone_confirmation on public.users;
create trigger trg_guard_user_phone_confirmation
before update of phone, phone_verification_level, phone_confirmation_method, phone_confirmed_at
on public.users
for each row
execute function public.guard_user_phone_confirmation();

-- Current rows with an existing phone but no method are legacy/manual entries.
update public.users
set phone_confirmation_method = 'manual'
where nullif(trim(phone), '') is not null
  and phone_verification_level = 'unverified'
  and phone_confirmation_method is null;

-- Partner applications are a higher-trust action. Enforce the confirmation
-- state at the database boundary as well, so a modified client cannot bypass
-- the Android UI check.
create or replace function public.enforce_mitra_phone_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_level text;
begin
  if new.status = 'applied'::public.application_status then
    select u.phone_verification_level
    into v_level
    from public.users u
    where u.id = new.user_id;

    if coalesce(v_level, 'unverified') not in ('device_confirmed', 'verified') then
      raise exception 'Konfirmasi nomor HP dari perangkat sebelum mengirim pengajuan Mitra.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_mitra_phone_confirmation on public.mitra_applications;
create trigger trg_enforce_mitra_phone_confirmation
before insert or update of status
on public.mitra_applications
for each row
execute function public.enforce_mitra_phone_confirmation();

-- Partner Agreement v1.2 adds the phone-confirmation requirement and reflects
-- the current Cash commission settlement model while preserving the existing
-- UPI-student identity verification requirements.
-- Deactivate the previous contract first. The schema intentionally enforces
-- exactly one active contract through mitra_contract_one_active_idx.
update public.mitra_contract_versions
set is_active = false
where is_active = true;

insert into public.mitra_contract_versions(
  version, title, content, title_en, content_en, is_active, effective_at
) values (
  '1.2',
  'Kontrak Kemitraan Ayo Suruh',
  $contract_id$
KONTRAK KEMITRAAN AYO SURUH — VERSI 1.2

1. Cakupan Mitra Saat Ini
Untuk rilis saat ini, pendaftaran Mitra Ayo Suruh dibatasi bagi mahasiswa aktif Universitas Pendidikan Indonesia (UPI). KTM UPI digunakan untuk membuktikan eligibility mahasiswa dan tidak diwajibkan memuat pas foto.

2. Nomor HP dan Kebenaran Data
Mitra wajib memberikan data pendaftaran yang benar dan tidak menggunakan nomor telepon milik pihak lain tanpa hak. Pada aplikasi Android yang mendukung, nomor HP wajib dikonfirmasi melalui Phone Number Hint berbasis SIM sebelum pengajuan dikirim. Konfirmasi perangkat membantu mengurangi salah input nomor, tetapi bukan verifikasi OTP SMS dan bukan bukti identitas hukum.

3. Verifikasi Identitas
Pendaftar wajib mengunggah KTM UPI, satu identitas legal berfoto yang masih berlaku (misalnya KTP, SIM, Paspor, KITAS/KITAP, atau identitas sah lain), serta selfie verifikasi yang diambil langsung dengan kamera depan. Admin memeriksa KTM dan mencocokkan selfie secara manual dengan pas foto pada identitas yang dikirim. Alur ini tidak menggunakan pengenalan wajah otomatis.

4. Status Kemitraan
Mitra adalah pengguna independen yang menawarkan keterampilan/jasa melalui platform Ayo Suruh. Persetujuan ini tidak membentuk hubungan kerja, kepegawaian, atau agensi antara Mitra dan Ayo Suruh.

5. Standar Layanan
Mitra wajib menjalankan pekerjaan sesuai deskripsi yang disepakati, menjaga komunikasi yang sopan, hadir sesuai kesepakatan, menjaga keamanan, serta tidak melakukan tindakan yang melanggar hukum atau merugikan Customer.

6. Harga, Pembayaran, dan Komisi Platform
Harga pekerjaan mengikuti penawaran/kesepakatan pada aplikasi. Acuan komisi platform saat ini adalah 6% dari nilai jasa pada transaksi berhasil, termasuk transaksi Cash, kecuali aplikasi menyatakan lain. Pada transaksi Cash, Customer membayar langsung kepada Mitra dan komisi platform diselesaikan melalui saldo AyoPay Mitra; saldo atau pendapatan berikutnya dapat digunakan untuk menutup kewajiban komisi yang belum terselesaikan. Mitra baru yang memenuhi syarat dapat memperoleh bonus satu kali 0% komisi pada pekerjaan pertama yang memenuhi ketentuan.

7. Pencairan dan Dana Tertahan
Pendapatan Mitra dapat melalui status pending, tersedia, ditahan, atau dicairkan. Dana dapat ditahan sementara jika terdapat pekerjaan aktif, refund/dispute, pemeriksaan transaksi, kewajiban komisi, atau proses pencairan yang belum selesai.

8. Pembatalan, Refund, dan Dispute
Mitra memahami bahwa transaksi tertentu dapat dibatalkan atau direfund sesuai status pekerjaan, bukti transaksi, dan hasil peninjauan. Jika pendapatan sudah tercatat lalu transaksi direfund, penyesuaian ledger dapat dilakukan sesuai alur yang tampil pada aplikasi.

9. Data Customer dan Kerahasiaan
Mitra hanya boleh menggunakan alamat, data kontak yang diberikan secara sah, chat, dan data Customer untuk menyelesaikan pekerjaan terkait. Data tersebut tidak boleh disebarkan, dijual, atau digunakan untuk tujuan lain tanpa izin yang sah.

10. Perilaku yang Dilarang
Mitra dilarang melakukan penipuan, intimidasi, transaksi fiktif, manipulasi rating, penyalahgunaan data pribadi, pengalihan pembayaran yang melanggar kebijakan platform, atau tindakan lain yang membahayakan pengguna maupun reputasi layanan.

11. Penangguhan dan Pengakhiran Kemitraan
Ayo Suruh dapat menangguhkan akses Mitra ketika terdapat dugaan pelanggaran, eligibility mahasiswa tidak lagi terpenuhi, kewajiban transaksi belum selesai, atau terdapat kebutuhan pemeriksaan. Mitra dapat menghapus akun setelah pekerjaan aktif, refund/dispute, pencairan, saldo, dan kewajiban yang diwajibkan telah diselesaikan.

12. Persetujuan Elektronik dan Perubahan Versi
Dengan mencentang persetujuan dan mengirim pengajuan, Mitra menyatakan telah membaca serta menyetujui kontrak versi yang tampil. Waktu persetujuan dicatat oleh sistem. Jika kontrak berubah secara material, Ayo Suruh dapat meminta persetujuan terhadap versi baru.

Catatan: dokumen elektronik ini merupakan persetujuan operasional penggunaan platform Ayo Suruh dan bukan pengganti konsultasi hukum atau dokumen e-signature formal apabila di kemudian hari dibutuhkan untuk penggunaan komersial penuh.
  $contract_id$,
  'Ayo Suruh Partner Agreement',
  $contract_en$
AYO SURUH PARTNER AGREEMENT — VERSION 1.2

1. Current Partner Scope
For the current release, Ayo Suruh Partner registration is limited to active Universitas Pendidikan Indonesia (UPI) students. The UPI Student Card (KTM) is used to confirm student eligibility and is not required to contain a portrait photo.

2. Phone Number and Accurate Information
Partners must provide accurate registration information and must not use another person’s phone number without authorization. On supported Android builds, the submitted phone number must be confirmed through the SIM-based Phone Number Hint flow before the application is sent. Device confirmation helps reduce incorrect number entry, but it is not SMS OTP verification and is not legal identity proof.

3. Identity Verification
Applicants must upload a UPI Student Card, one valid legal photo identity document (for example KTP, SIM, Passport, KITAS/KITAP, or another valid legal photo ID), and a verification selfie taken directly with the front camera. The admin checks the KTM and manually compares the selfie with the portrait on the submitted photo ID. This flow does not use automated facial recognition.

4. Partnership Status
Partners are independent users who offer skills/services through the Ayo Suruh platform. This agreement does not create an employment, employee, or agency relationship between the Partner and Ayo Suruh.

5. Service Standards
Partners must perform jobs according to the agreed description, communicate professionally, arrive as agreed, maintain safety, and avoid unlawful actions or conduct that harms Customers.

6. Pricing, Payments, and Platform Commission
Job prices follow offers/agreements recorded in the app. The current reference platform commission is 6% of the service value on successful transactions, including Cash transactions, unless the app states otherwise. For Cash transactions, the Customer pays the Partner directly and the platform commission is settled through the Partner’s AyoPay balance; future balance or earnings may offset an unsettled commission obligation. Eligible new Partners may receive a one-time 0% commission bonus on their first qualifying job.

7. Withdrawals and Held Funds
Partner earnings may move through pending, available, held, or paid-out states. Funds may be held temporarily when there are active jobs, refunds/disputes, transaction reviews, commission obligations, or unfinished withdrawal processes.

8. Cancellation, Refund, and Dispute
Partners understand that certain transactions may be cancelled or refunded depending on job status, transaction evidence, and review outcomes. If earnings were already recorded before a refund, the ledger may be adjusted according to the flow shown in the app.

9. Customer Data and Confidentiality
Partners may only use Customer addresses, lawfully provided contact information, chat, and other Customer data to complete the relevant job. The data must not be distributed, sold, or used for other purposes without a lawful basis.

10. Prohibited Conduct
Partners must not engage in fraud, intimidation, fake transactions, rating manipulation, misuse of personal data, payment diversion that violates platform policy, or other conduct that endangers users or the service.

11. Suspension and Termination
Ayo Suruh may suspend Partner access when there is a suspected violation, student eligibility is no longer met, transaction obligations remain unresolved, or a review is required. Partners may delete their account after required active jobs, refunds/disputes, withdrawals, balances, and other required obligations have been resolved.

12. Electronic Acceptance and Version Changes
By checking the agreement box and submitting an application, the Partner confirms that they have read and accepted the displayed contract version. The acceptance time is recorded by the system. If the contract changes materially, Ayo Suruh may require acceptance of a new version.

Note: this electronic document is an operational agreement for use of the Ayo Suruh platform and is not a substitute for legal advice or a formal e-signature document if one is later required for full commercial use.
  $contract_en$,
  false,
  timezone('utc', now())
)
on conflict (version) do update
set
  title = excluded.title,
  content = excluded.content,
  title_en = excluded.title_en,
  content_en = excluded.content_en,
  effective_at = excluded.effective_at;

update public.mitra_contract_versions
set is_active = (version = '1.2');

-- Admin verification queue also exposes the phone trust level so reviewers can
-- distinguish a manual number from a device-confirmed/future verified number.
drop function if exists public.admin_list_mitra_applications();
create function public.admin_list_mitra_applications()
returns table (
  application_id uuid,
  user_id uuid,
  fullname text,
  email text,
  phone text,
  phone_verification_level text,
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
    u.phone_verification_level,
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
