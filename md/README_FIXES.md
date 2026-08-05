# Perbaikan progres dan riwayat mitra

Perubahan:

1. Foto bukti menggunakan `BoxFit.contain`, sehingga gambar tidak terpotong.
2. Bid berstatus `accepted` tidak lagi tampil pada tab **Pengajuan**. Job aktif berada di tab **Aktif**, sedangkan job selesai/dibatalkan berada di riwayat.
3. Menu **Riwayat Pekerjaan Mitra** sudah dapat dibuka.
4. Profil mitra mengambil statistik aktual: jumlah pekerjaan selesai, rating, dan total pendapatan.
5. Halaman baru `mitra_job_history_page.dart` menampilkan job `completed` dan `cancelled`.

Tidak ada SQL migration tambahan untuk patch ini.

Setelah menyalin patch:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```
