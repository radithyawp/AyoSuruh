# Refund Midtrans + Dompet dan Pencairan Mitra

Tahap ini menambahkan dua alur:

1. Pembatalan transaksi atau refund Midtrans dari sisi customer.
2. Dompet mitra, saldo pending/available, dan pencairan **mock**.

> Pencairan mock hanya mensimulasikan approval dan perubahan ledger. Belum ada transfer uang nyata ke rekening mitra sampai produk payout/penyedia transfer resmi tersedia.

## 1. Jalankan migration

Buka **Supabase Dashboard → SQL Editor**, lalu jalankan:

```text
supabase/migrations/20260806_refund_wallet_payout.sql
```

Migration menambahkan:

- status pembayaran `refunded` dan `cancelled`;
- tabel `refund_requests`;
- tabel `mitra_wallet_ledger`;
- tabel `payout_requests`;
- RPC ringkasan dompet, ledger, pengajuan/cancel pencairan;
- RPC admin untuk simulasi payout;
- trigger kredit pendapatan setelah job `completed` dan pembayaran `paid`;
- hold saldo selama 1 hari;
- adjustment otomatis jika pembayaran direfund/dibatalkan setelah earning tercatat.

## 2. Deploy Edge Functions

Tidak ada secret baru. Secret Midtrans Sandbox dari tahap pembayaran sebelumnya tetap digunakan.

```powershell
npx supabase functions deploy request-midtrans-refund
npx supabase functions deploy refresh-midtrans-status
npx supabase functions deploy midtrans-payment-webhook --no-verify-jwt
```

`request-midtrans-refund` harus memakai JWT karena hanya customer pemilik pekerjaan yang boleh memanggilnya.

## 3. Jalankan Flutter

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

## 4. Uji pembatalan/refund

### Transaksi masih pending

```text
Customer menerima mitra
→ membuka Pembayaran
→ Snap/order sudah dibuat tetapi belum dibayar
→ Batalkan Transaksi & Pekerjaan
```

Backend akan mencoba Midtrans Cancel API. Jika berhasil:

```text
payments.status = cancelled
jobs.status = cancelled
refund_requests.status = cancelled
```

### Transaksi sudah settlement/paid dan pekerjaan belum dimulai

```text
Customer membuka detail pekerjaan
→ Pembayaran
→ Ajukan Pembatalan & Refund
→ memilih alasan
→ Ajukan Refund
```

Backend akan mencoba refund penuh melalui Midtrans Sandbox. Status `refund` berarti permintaan refund sudah diterima/diproses oleh Midtrans; waktu dana benar-benar kembali mengikuti metode pembayaran. Untuk GoPay Static QRIS, backend memprioritaskan `transaction_id` sesuai ketentuan Midtrans.

### Pekerjaan sudah berjalan atau selesai

Status `on_progress` dan `completed` tidak direfund otomatis. Permintaan masuk:

```text
refund_requests.status = manual_review
```

Hal ini mencegah dana dikembalikan otomatis ketika jasa sudah mulai diberikan.

### Catatan Sandbox

Kapabilitas refund dapat berbeda menurut metode pembayaran dan konfigurasi merchant Sandbox. Jika Midtrans menolak refund API, aplikasi menyimpan permintaan sebagai `manual_review` agar tidak kehilangan jejak permintaan.

## 5. Menyelesaikan refund manual dari SQL Editor

Gunakan ini hanya setelah admin benar-benar memeriksa atau memproses refund pada dashboard Midtrans.

Lihat antrean manual:

```sql
select
  id,
  job_id,
  amount,
  reason,
  status,
  status_message,
  created_at
from public.refund_requests
where status in ('manual_review', 'processing', 'failed')
order by created_at desc;
```

Tandai refund selesai setelah dikonfirmasi di Midtrans:

```sql
select public.process_manual_refund(
  'REFUND_REQUEST_UUID'::uuid,
  'refunded',
  'Refund sudah dikonfirmasi pada dashboard Midtrans.'
);
```

Tolak permintaan:

```sql
select public.process_manual_refund(
  'REFUND_REQUEST_UUID'::uuid,
  'reject',
  'Permintaan tidak memenuhi ketentuan pembatalan.'
);
```

Fungsi ini tidak diberikan kepada aplikasi Flutter dan hanya dapat dijalankan dari konteks admin/SQL Editor.

## 6. Uji dompet mitra

Pendapatan masuk setelah kedua syarat terpenuhi:

```text
jobs.status = completed
payments.status = paid
```

Saldo pertama kali masuk ke bucket `pending` dan otomatis tersedia setelah hold 1 hari.

Untuk mempercepat pengujian Sandbox, jalankan di SQL Editor:

```sql
select public.force_release_wallet_for_testing(
  'JOB_UUID_DI_SINI'::uuid
);
```

Lalu pada aplikasi:

```text
Mode Mitra
→ Profil
→ Dompet & Rekening / Cairkan
→ isi nominal
→ Ajukan Pencairan
```

Minimum pencairan mock adalah Rp10.000.

## 7. Proses payout mock dari SQL Editor

Lihat antrean:

```sql
select
  id,
  mitra_id,
  amount,
  bank_name,
  account_number,
  account_holder,
  status,
  created_at
from public.payout_requests
order by created_at desc;
```

Gunakan UUID request pada perintah berikut.

### Masuk pemeriksaan

```sql
select public.process_mock_payout(
  'PAYOUT_REQUEST_UUID'::uuid,
  'review',
  'Data rekening sedang diperiksa.'
);
```

### Setujui

```sql
select public.process_mock_payout(
  'PAYOUT_REQUEST_UUID'::uuid,
  'approve',
  'Pencairan disetujui.'
);
```

### Tandai dibayar

```sql
select public.process_mock_payout(
  'PAYOUT_REQUEST_UUID'::uuid,
  'paid',
  'Simulasi transfer Sandbox selesai.'
);
```

### Tolak

```sql
select public.process_mock_payout(
  'PAYOUT_REQUEST_UUID'::uuid,
  'reject',
  'Data rekening tidak sesuai.'
);
```

Mitra juga dapat membatalkan sendiri selama request masih `requested` atau `under_review`.

## 8. Aturan saldo dan refund

- Job belum selesai: belum ada earning mitra.
- Job selesai dan pembayaran paid: earning masuk pending.
- Hold selesai: earning menjadi available.
- Payout diajukan: saldo dipindahkan dari available ke held.
- Payout mock berhasil: held dipindahkan ke withdrawn.
- Pembayaran direfund setelah earning dibuat: ledger menambahkan adjustment negatif.
- Jika dana sudah sempat dicairkan, saldo available dapat menjadi negatif dan wajib ditinjau admin.

## 9. File credential

Jangan commit:

```text
MIDTRANS_SERVER_KEY
SUPABASE_SERVICE_ROLE_KEY
assets/.env
supabase/.env
```

Secret tetap disimpan di Supabase Edge Function Secrets.

## Commit yang disarankan

```bash
git add .
git commit -m "feat: add Midtrans refunds and mitra wallet payout flow"
```
