# Setup Rating Mitra

Tahap ini menambahkan alur rating setelah pekerjaan selesai.

## 1. Jalankan migration

Buka Supabase Dashboard > SQL Editor, lalu jalankan:

`supabase/migrations/20260805_job_review_feature.sql`

Migration menambahkan:

- `reviews.tags`
- satu review per pekerjaan
- RPC `submit_job_review`
- RPC `get_job_review`
- trigger pembaruan rata-rata `mitras.rating`
- RLS review untuk customer dan mitra yang terlibat
- pencatatan pendapatan dari harga bid yang diterima saat job selesai

## 2. Jalankan Flutter

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

## 3. Alur pengujian

1. Login sebagai customer yang memiliki job berstatus `completed`.
2. Buka Jobs > Riwayat > pilih job.
3. Tekan **Beri Penilaian untuk Mitra**.
4. Pilih 1-5 bintang, tag layanan, dan isi ulasan.
5. Kirim penilaian.
6. Login sebagai mitra.
7. Buka Profil untuk memastikan rating berubah.
8. Buka Riwayat Pekerjaan Mitra untuk melihat rating pada pekerjaan tersebut.

Catatan: pekerjaan lama yang sudah `completed` juga dapat langsung diberi rating setelah migration dijalankan.

## Catatan enum pendapatan

Migration mengenali label enum pemasukan berikut pada `earnings.type`:
`income`, `job_income`, `earning`, `credit`, `pendapatan`, atau `job`.

Jika SQL Editor menampilkan notice bahwa label pemasukan tidak dikenali, jalankan:

```sql
select t.typname as enum_name, e.enumlabel as enum_value, e.enumsortorder
from pg_type t
join pg_enum e on e.enumtypid = t.oid
join pg_attribute a on a.atttypid = t.oid
join pg_class c on c.oid = a.attrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'earnings'
  and a.attname = 'type'
order by e.enumsortorder;
```

Kirim hasilnya agar label pemasukan dapat disesuaikan tanpa menebak.
