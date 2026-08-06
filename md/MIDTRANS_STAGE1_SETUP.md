# Midtrans Payment Gateway — Tahap 1

Tahap ini menyiapkan fondasi pembayaran Midtrans Snap tanpa memutus alur kerja aplikasi ketika akun Midtrans masih dalam proses pendaftaran.

## Perilaku aman selama pendaftaran

- Saat customer memilih mitra, aplikasi membuat record lokal pada `payments`.
- `payment_required` masih bernilai `false` sehingga mitra tetap dapat memulai pekerjaan seperti sebelumnya.
- Setelah Snap Token berhasil dibuat, `payment_required` berubah menjadi `true` dan mitra baru dapat memulai pekerjaan ketika status pembayaran `paid`.
- Server Key tidak disimpan di Flutter atau GitHub.

## 1. Jalankan migration SQL

Jalankan file:

```text
supabase/migrations/20260805_midtrans_payment_stage1.sql
```

melalui Supabase SQL Editor.

## 2. Jalankan Flutter

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

Tanpa Server Key Midtrans, halaman pembayaran tetap dapat dibuka tetapi tombol aktivasi akan menampilkan pesan bahwa `MIDTRANS_SERVER_KEY` belum tersedia. Alur pekerjaan lama tetap berjalan.

## 3. Setelah Sandbox Midtrans tersedia

Tambahkan secret Edge Function:

```powershell
npx supabase secrets set MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxx
npx supabase secrets set MIDTRANS_IS_PRODUCTION=false
npx supabase secrets set MIDTRANS_SERVICE_FEE_PERCENT=0
```

Jangan menaruh Server Key pada `assets/.env`.

Deploy fungsi:

```powershell
npx supabase functions deploy create-midtrans-snap
npx supabase functions deploy refresh-midtrans-status
npx supabase functions deploy midtrans-payment-webhook --no-verify-jwt
npx supabase functions deploy midtrans-payment-return --no-verify-jwt
```

Atau deploy seluruh fungsi sesuai konfigurasi `supabase/config.toml`.

## 4. URL konfigurasi Midtrans Sandbox

Payment Notification URL:

```text
https://PROJECT_REF.supabase.co/functions/v1/midtrans-payment-webhook
```

Finish, Unfinished, dan Error Redirect URL dapat diarahkan ke:

```text
https://PROJECT_REF.supabase.co/functions/v1/midtrans-payment-return
```

## 5. Alur pengujian nanti

```text
Customer memilih mitra
→ record payments dibuat, payment_required=false
→ customer membuka Pembayaran Midtrans
→ Edge Function membuat Snap Token
→ payment_required=true
→ customer membayar pada Snap Sandbox
→ webhook atau Cek Status mengubah payments.status=paid
→ mitra dapat memulai pekerjaan
```

## 6. Mapping status

| Midtrans | AyoSuruh |
|---|---|
| pending | pending |
| settlement | paid |
| capture + fraud accept | paid |
| deny/cancel/failure | failed |
| expire | expired |

## 7. Catatan tahap berikutnya

Belum termasuk:

- Refund dan pembatalan transaksi yang sudah dibayar.
- Split payment/payout otomatis ke mitra.
- Production switch dan audit konfigurasi.
- Deep link langsung kembali ke aplikasi.
