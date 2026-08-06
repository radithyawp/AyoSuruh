# Midtrans Stage 2 — Finalisasi Pembayaran

Tahap ini melanjutkan fondasi Midtrans Stage 1 dengan:

- status pembayaran realtime dari webhook;
- masa berlaku Snap 30 menit;
- retry aman untuk transaksi gagal/kedaluwarsa;
- riwayat setiap Snap order pada `payment_attempts`;
- halaman Riwayat Transaksi customer;
- notifikasi untuk status berhasil, gagal, dan kedaluwarsa;
- status `deny` tetap dianggap menunggu karena satu Snap order dapat memiliki beberapa attempt.

## 1. Jalankan migration

Jalankan file berikut di Supabase SQL Editor:

```text
supabase/migrations/20260806_midtrans_payment_stage2.sql
```

Migration membuat tabel `payment_attempts`, RPC riwayat pembayaran, RLS, dan mengaktifkan Realtime pada tabel `payments`.

## 2. Salin patch Flutter dan Edge Functions

Salin folder `lib` dan `supabase` dari patch ke root project, lalu pilih Replace.

## 3. Deploy ulang fungsi yang berubah

```powershell
npx supabase functions deploy create-midtrans-snap
npx supabase functions deploy refresh-midtrans-status
npx supabase functions deploy midtrans-payment-webhook --no-verify-jwt
```

`midtrans-payment-return` dari Stage 1 tetap dapat digunakan. Deploy ulang hanya jika file tersebut ikut diubah.

## 4. Jalankan Flutter

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

## 5. Pengujian

### Pembayaran berhasil

1. Buat job baru.
2. Mitra mengirim bid.
3. Customer menerima mitra.
4. Customer membuka pembayaran.
5. Selesaikan pembayaran melalui simulator Sandbox.
6. Status halaman berubah otomatis menjadi `Sudah Dibayar`.
7. Login mitra dan pastikan tombol mulai pekerjaan aktif.

### Retry

1. Buat transaksi pembayaran.
2. Biarkan kedaluwarsa atau simulasikan kegagalan.
3. Tekan `Buat Pembayaran Baru`.
4. Pastikan order ID baru dibuat.
5. Riwayat percobaan lama tetap tampil.

### Riwayat transaksi

```text
Profil customer → Riwayat Transaksi
```

Halaman menampilkan seluruh pembayaran job milik customer, filter status, metode pembayaran, dan jumlah percobaan.

## Catatan keamanan

- Server Key Midtrans tetap hanya berada di Supabase Secrets.
- Jangan commit `.env`, Server Key, atau output log yang mengandung credential.
- Status `paid` hanya diterima dari webhook Midtrans atau Get Status API server-side.
