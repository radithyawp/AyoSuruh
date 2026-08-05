# Setup Fitur Notifikasi Ayo Suruh

## 1. Jalankan migration Supabase

Jalankan file berikut melalui **Supabase Dashboard > SQL Editor**:

```text
supabase/migrations/20260805_notification_feature.sql
```

Migration akan:

- menambahkan tujuan `job_id`, `room_id`, `actor_id`, dan metadata pada notifikasi;
- membuat notifikasi otomatis untuk bid, progres job, chat, penyelesaian, pembatalan, dan rating;
- menerapkan RLS agar pengguna hanya membaca/mengubah notifikasinya sendiri;
- menambahkan RPC untuk menandai notifikasi chat/job sebagai dibaca;
- mengaktifkan tabel `notifications` pada publication `supabase_realtime`.

Notifikasi hanya dibuat untuk aktivitas yang terjadi **setelah migration dijalankan**.

## 2. Jalankan aplikasi

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

## 3. Alur pengujian cepat

1. Login sebagai mitra dan kirim bid baru.
2. Login sebagai customer. Ikon lonceng harus menampilkan badge dan halaman notifikasi berisi **Penawaran Baru**.
3. Terima bid. Akun mitra mendapat notifikasi **Penawaran Diterima**.
4. Kirim chat dari customer. Akun mitra mendapat notifikasi pesan baru.
5. Tekan notifikasi untuk membuka detail pekerjaan atau percakapan terkait.
6. Uji menu **Tandai semua dibaca** dan **Hapus semua**.

Membuka room chat atau detail pekerjaan juga otomatis menandai notifikasi terkait sebagai dibaca.
