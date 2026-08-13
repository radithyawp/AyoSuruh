# Ayo Suruh - Android Release Toolkit

Toolkit ini membuat release Android yang ditandatangani sesuai konfigurasi project dan menghasilkan nama APK ramah pengguna `AyoSuruh.apk` tanpa mengubah perilaku Gradle Flutter.

## Cara pasang

Salin `release_android.ps1` ke:

```text
tools/release_android.ps1
```

pada root project AyoSuruh.

## Persyaratan penting

1. `android/key.properties` harus tersedia.
2. Keystore release harus merupakan keystore yang sama dengan rilis Ayo Suruh sebelumnya jika package `com.ayosuruh.app` sudah pernah dipublikasikan.
3. Pastikan `version:` di `pubspec.yaml` memiliki build number yang lebih tinggi daripada build terakhir di Play Console.
4. Jalankan dari working tree yang sudah di-commit dan sudah lolos QA.

## Menjalankan

```powershell
cd C:\src\AyoSuruh
powershell -ExecutionPolicy Bypass -File .\tools\release_android.ps1
```

Output dibuat di:

```text
release\android\v<version>-build<build>\
```

Contoh untuk `1.1.0+2`:

```text
release\android\v1.1.0-build2\AyoSuruh.apk
release\android\v1.1.0-build2\AyoSuruh-v1.1.0-build2.apk
release\android\v1.1.0-build2\AyoSuruh-v1.1.0-build2.aab
release\android\v1.1.0-build2\RELEASE-INFO.txt
```

`AyoSuruh.apk` adalah file direct-install/share. Untuk Google Play gunakan file `.aab`.
