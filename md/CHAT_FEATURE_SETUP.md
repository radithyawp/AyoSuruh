# Setup Fitur Chat Ayo Suruh

## 1. Jalankan migration Supabase

Jalankan file berikut di **Supabase Dashboard > SQL Editor**:

```text
supabase/migrations/20260805_job_chat_feature.sql
```

Migration akan:

- menambahkan `chat_rooms.updated_at`;
- memastikan satu pekerjaan hanya mempunyai satu room;
- membuat room otomatis setelah mitra dipilih;
- membuat room untuk job lama yang sudah mempunyai mitra;
- menambahkan RPC daftar room, pembuka room, header room, dan pengiriman pesan;
- menerapkan RLS agar hanya customer dan mitra pekerjaan yang bisa membaca chat;
- mengaktifkan tabel `messages` pada publication `supabase_realtime`.

## 2. Jalankan aplikasi

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

## 3. Alur pengujian

1. Login sebagai customer.
2. Buka job yang sudah mempunyai mitra.
3. Tekan **Chat dengan Mitra** dan kirim pesan.
4. Login sebagai mitra pada perangkat atau sesi lain.
5. Buka navbar **Chat**.
6. Buka room job yang sama dan balas pesan.
7. Pastikan kedua sisi menerima pesan secara realtime.

Chat hanya tersedia setelah `jobs.mitra_id` terisi. Pekerjaan yang sudah selesai tetap mempunyai riwayat percakapan.
