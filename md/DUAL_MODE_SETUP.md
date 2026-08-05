# Dual Mode Customer–Mitra

Fitur ini memungkinkan satu akun aktif sebagai customer sekaligus mitra.

## Aturan akses

- Semua akun terautentikasi dapat menggunakan Mode Customer.
- Mode Mitra hanya tersedia bila `public.mitras.id = auth.uid()` dan `is_active = true`.
- Berpindah mode tidak mengubah `jobs.customer_id`, `jobs.mitra_id`, atau `users.role`.
- Preferensi mode disimpan pada Supabase Auth user metadata dengan key `active_mode`.
- Mitra tetap tidak dapat menawar pekerjaan miliknya sendiri. Validasi sudah berada pada RPC `submit_job_bid` dan daftar job tersedia juga mengecualikan `customer_id = auth.uid()`.

## Cara menggunakan

1. Login menggunakan akun yang sudah disetujui sebagai mitra.
2. Buka navbar **Profile**.
3. Gunakan kartu **Mode Customer Aktif / Mode Mitra Aktif**.
4. Tekan **Ke Customer** atau **Ke Mitra**.
5. Aplikasi kembali ke Home dan mengganti Dashboard serta halaman Jobs sesuai mode yang dipilih.

## Instalasi

Tidak ada SQL migration baru dan tidak ada dependency baru.

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Pengujian akun dual-mode

Untuk akun customer yang kemudian disetujui menjadi mitra:

- Mode Customer harus menampilkan pekerjaan yang dibuat akun tersebut.
- Mode Mitra harus menampilkan pekerjaan tersedia milik user lain.
- Job milik akun sendiri tidak boleh muncul pada tab Tersedia.
- Pekerjaan yang diberikan kepada akun tersebut harus muncul pada tab Aktif di Mode Mitra.
- Preferensi mode harus tetap sama setelah aplikasi dibuka kembali selama metadata Auth berhasil disimpan.
