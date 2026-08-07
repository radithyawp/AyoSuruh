# Google Sign-In / Registration — AyoSuruh

## Perubahan source

- Tombol Google pada Login dan Register memakai Supabase OAuth.
- Pengguna Google baru otomatis dibuat sebagai `public.users.role = user`.
- Nama dan avatar diambil dari metadata Google.
- Deep link Android/iOS: `io.supabase.ayosuruh://login-callback/`.
- Session lama otomatis masuk ke `MainNavigation` setelah splash.
- Email yang sama dapat ditautkan otomatis oleh Supabase bila identitasnya memenuhi ketentuan keamanan Supabase.

## 1. Jalankan migration

Jalankan `AyoSuruh-google-auth-migration.sql` melalui Supabase SQL Editor.

## 2. Buat Google OAuth Client

Di Google Auth Platform / Google Cloud Console:

1. Siapkan Branding, Audience, dan Data Access.
2. Gunakan scope `openid`, `userinfo.email`, dan `userinfo.profile`.
3. Buat OAuth Client ID bertipe **Web application**.
4. Authorized redirect URI:

```text
https://dgpamdziurfamnxmanvx.supabase.co/auth/v1/callback
```

5. Simpan Client ID dan Client Secret. Jangan commit Client Secret.

Jika status Audience masih Testing, tambahkan email penguji pada daftar Test users.

## 3. Aktifkan Google di Supabase

Supabase Dashboard → Authentication → Providers → Google:

- Enable Google provider.
- Isi Google Client ID.
- Isi Google Client Secret.
- Save.

## 4. Tambahkan redirect URL aplikasi

Supabase Dashboard → Authentication → URL Configuration → Redirect URLs:

```text
io.supabase.ayosuruh://login-callback/**
```

Untuk Flutter Web lokal, tambahkan URL yang benar-benar digunakan, misalnya:

```text
http://localhost:3000/**
http://localhost:5000/**
```

## 5. Jalankan Flutter

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

Tidak ada dependency Flutter baru.

## 6. Pengujian pengguna baru

1. Logout dari aplikasi.
2. Buka Register.
3. Tekan `Daftar dengan Google`.
4. Pilih akun Google yang belum pernah digunakan.
5. Setelah kembali ke aplikasi, pengguna harus masuk sebagai customer.
6. Periksa Profil: nama, email, dan avatar Google harus tampil.

Cek database:

```sql
select
  au.id,
  au.email,
  au.raw_app_meta_data ->> 'provider' as provider,
  pu.fullname,
  pu.avatar_url,
  pu.role
from auth.users au
left join public.users pu on pu.id = au.id
order by au.created_at desc;
```

## 7. Pengujian akun lama

Login Google menggunakan email yang sama dengan akun password yang sudah terverifikasi. Supabase dapat menautkan identitas Google ke user yang sama, sehingga UUID dan data pekerjaan tidak berubah.

Cek identities:

```sql
select
  user_id,
  provider,
  identity_data ->> 'email' as email,
  created_at
from auth.identities
order by created_at desc;
```

## Troubleshooting

### `redirect_uri_mismatch`

Authorized redirect URI Google harus persis:

```text
https://dgpamdziurfamnxmanvx.supabase.co/auth/v1/callback
```

### Browser selesai login tetapi aplikasi tidak terbuka

Pastikan Supabase Redirect URLs memuat custom scheme dan file AndroidManifest/Info.plist dari patch sudah tersalin.

### `Unsupported provider: provider is not enabled`

Google provider di Supabase belum diaktifkan atau Client ID/Secret belum disimpan.

### `Access blocked: app has not completed verification`

Tambahkan email sebagai Test user pada Google Auth Platform Audience, atau selesaikan konfigurasi consent screen.
