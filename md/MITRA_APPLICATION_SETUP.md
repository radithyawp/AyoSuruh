# Setup Fitur Daftar Jadi Mitra

## 1. Jalankan migration

Jalankan file berikut di Supabase SQL Editor:

```text
supabase/migrations/20260805_mitra_application_feature.sql
```

Migration menambahkan:

- data bank, nomor rekening, persetujuan syarat, dan catatan verifikasi;
- bucket privat `mitra-documents`;
- RPC pengiriman dan pengecekan pengajuan;
- helper approval dan rejection untuk admin;
- notifikasi status pengajuan;
- aktivasi otomatis record `public.mitras` ketika disetujui.

## 2. Alur pengujian user

```text
Login akun customer
→ Profil
→ Daftar Menjadi Mitra
→ isi formulir
→ unggah KTM dan selfie
→ Kirim Pendaftaran
→ status Menunggu Verifikasi
```

## 3. Lihat antrean admin

Jalankan:

```sql
select
  a.id,
  u.email,
  u.fullname,
  a.address,
  a.bank_name,
  a.account_number,
  a.status,
  a.created_at,
  d.ktm,
  d.selfie
from public.mitra_applications a
join public.users u on u.id = a.user_id
left join lateral (
  select md.ktm, md.selfie
  from public.mitra_documents md
  where md.application_id = a.id
  order by md.created_at desc
  limit 1
) d on true
order by a.created_at desc;
```

Dokumen berada pada Storage bucket privat `mitra-documents` dan dapat ditinjau lewat Supabase Dashboard.

## 4. Setujui pengajuan

```sql
select public.approve_mitra_application('APPLICATION_UUID');
```

Proses tersebut secara atomik:

- mengubah aplikasi menjadi `approved`;
- mengubah `users.role` menjadi `mitra`;
- membuat atau mengaktifkan record `mitras`;
- menandai dokumen terverifikasi;
- mengirim notifikasi kepada pendaftar.

User dapat menekan **Periksa Status Terbaru**, lalu **Masuk Dashboard Mitra**.

## 5. Tolak dan minta perbaikan

```sql
select public.reject_mitra_application(
  'APPLICATION_UUID',
  'Foto KTM kurang jelas. Silakan unggah ulang.'
);
```

User akan melihat alasan penolakan dan tombol **Perbaiki dan Ajukan Ulang**.

## 6. Menjalankan Flutter

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

Tidak ada dependency Flutter baru pada fitur ini.
