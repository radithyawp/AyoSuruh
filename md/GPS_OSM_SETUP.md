# GPS + OpenStreetMap Setup

Fitur ini menambahkan pemilihan titik lokasi pekerjaan menggunakan OpenStreetMap dan GPS perangkat.

## Fitur

- Customer memilih titik lokasi saat membuat pekerjaan.
- Titik dapat dipilih manual dengan mengetuk peta.
- Tombol lokasi saat ini menggunakan GPS perangkat.
- Koordinat disimpan ke `jobs.latitude` dan `jobs.longitude`.
- Alamat baru juga menyimpan koordinat ke tabel `addresses`.
- Customer dan mitra dapat melihat preview peta pada detail pekerjaan.
- Tombol `Buka di OpenStreetMap` membuka lokasi pada browser/aplikasi peta.

## Instalasi

Jalankan:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

Tidak ada SQL migration baru karena kolom `latitude` dan `longitude` sudah tersedia pada tabel `jobs` dan `addresses`.

## Izin perangkat

Patch sudah menambahkan:

- Android: `ACCESS_COARSE_LOCATION` dan `ACCESS_FINE_LOCATION`.
- iOS: `NSLocationWhenInUseUsageDescription`.

## Pengujian

1. Login sebagai customer.
2. Buka `Buat Pekerjaan`.
3. Pilih alamat atau isi alamat baru.
4. Tekan `Pilih Titik di Peta`.
5. Ketuk titik tujuan atau tekan tombol lokasi saat ini.
6. Konfirmasi titik lalu publish pekerjaan.
7. Login sebagai mitra dan buka detail pekerjaan.
8. Pastikan peta dan tombol `Buka di OpenStreetMap` tampil.

Pekerjaan lama yang belum memiliki koordinat tetap dapat dibuka, tetapi kartu peta tidak akan ditampilkan.
