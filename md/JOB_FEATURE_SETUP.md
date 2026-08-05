# Fitur Pekerjaan Ayo Suruh

Implementasi pada paket ini mencakup alur:

1. Customer membuat dan memublikasikan pekerjaan.
2. Mitra melihat pekerjaan berstatus `posted` atau `waiting_bid`.
3. Mitra mengirim satu penawaran melalui tabel `bids`.
4. Customer melihat seluruh penawaran dan memilih satu mitra.
5. Penawaran terpilih menjadi `accepted`, penawaran lain menjadi `rejected`, dan `jobs.mitra_id` terisi.
6. Mitra dapat memulai pekerjaan sehingga status berubah menjadi `on_progress`.

## SQL wajib

Jalankan file berikut melalui Supabase SQL Editor:

```text
supabase/migrations/20260805_job_bidding_feature.sql
```

SQL tersebut menambahkan unique constraint pada `(job_id, mitra_id)` dan RPC `accept_job_bid` agar penerimaan mitra berlangsung dalam satu transaksi.

## File Flutter utama

```text
lib/jobs/job_service.dart
lib/jobs/create_job_page.dart
lib/jobs/customer_jobs_page.dart
lib/jobs/customer_job_detail_page.dart
lib/jobs/job_bids_page.dart
lib/jobs/mitra_jobs_page.dart
lib/jobs/mitra_job_detail_page.dart
lib/jobs/submit_bid_page.dart
```

## Pengujian manual

1. Login sebagai customer.
2. Tekan `Buat Pekerjaan`, isi seluruh form, lalu publish.
3. Login sebagai mitra yang sudah memiliki baris pada tabel `mitras`.
4. Buka tab `Jobs`, pilih pekerjaan, lalu kirim penawaran.
5. Login kembali sebagai customer.
6. Buka pekerjaan dan tekan `Lihat Penawaran`.
7. Terima satu mitra.
8. Login sebagai mitra, buka tab `Aktif`, lalu tekan `Mulai Pekerjaan`.

## Belum termasuk tahap ini

- GPS dan pemilihan titik OSM.
- Upload foto pekerjaan.
- Update status rinci: menuju lokasi, tiba, unggah bukti, selesai.
- Payment gateway, chat real-time, notifikasi push, dan rating.

## Konfigurasi Supabase

ZIP sumber awal tidak menyertakan `assets/.env`. Paket hasil pengerjaan berisi placeholder agar asset Flutter tidak hilang saat build. Sebelum menjalankan aplikasi, isi kembali:

```text
SUPABASE_URL=...
SUPABASE_ANONKEY=...
```

Jangan commit nilai asli `.env` ke repository publik.
