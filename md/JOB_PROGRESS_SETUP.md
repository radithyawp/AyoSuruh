# Tahap 2 - Progres Pekerjaan Ayo Suruh

Tahap ini melanjutkan alur yang sudah berhasil sampai status `on_progress`.

## Fitur

- Halaman mitra `Update Status Pekerjaan` sesuai rancangan Figma.
- Tahapan berurutan:
  1. Menuju Lokasi
  2. Tiba di Lokasi
  3. Mulai Bekerja
  4. Pekerjaan Selesai / menunggu konfirmasi customer
- Foto bukti opsional dari kamera atau galeri.
- Catatan singkat pada setiap pembaruan.
- Timeline progres terlihat pada detail mitra dan customer.
- Customer mengonfirmasi pekerjaan selesai.
- Nama customer/mitra diambil melalui RPC aman jika relasi `users` terkena RLS.

## Wajib: jalankan SQL lebih dahulu

Buka Supabase > SQL Editor, lalu jalankan:

`supabase/migrations/20260805_job_progress_feature.sql`

SQL tersebut:

- menambahkan enum `job_progress_stage`;
- menambahkan `jobs.progress_stage`;
- menambahkan `job_timelines.progress_stage` dan `evidence_url`;
- memperbarui RPC `start_assigned_job`;
- membuat RPC `advance_job_progress`;
- membuat RPC `confirm_job_completion`;
- membuat bucket Storage publik `job-evidence` beserta policy upload;
- melakukan backfill job lama yang sudah `on_progress` menjadi `heading_to_location`.

## Setelah menyalin source

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Alur uji

1. Login mitra yang memiliki job `on_progress`.
2. Pekerjaan > Aktif > Detail > Update Status Pekerjaan.
3. Perbarui ke `Tiba di Lokasi`.
4. Perbarui ke `Mulai Bekerja`.
5. Tambahkan foto/catatan, lalu perbarui ke `Pekerjaan Selesai`.
6. Login customer pemilik job.
7. Detail pekerjaan menampilkan progres, bukti, dan tombol `Konfirmasi Pekerjaan Selesai`.
8. Konfirmasi; status job menjadi `completed`.

Foto dibatasi maksimal 5 MB oleh bucket Supabase.
