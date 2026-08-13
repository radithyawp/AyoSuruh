param(
    [switch]$SkipClean,
    [switch]$SkipBundle
)

$ErrorActionPreference = 'Stop'

# Script is intended to live in <project>\tools\release_android.ps1.
# If executed elsewhere, fall back to the current directory when pubspec.yaml exists.
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $projectRoot 'pubspec.yaml'))) {
    if (Test-Path (Join-Path (Get-Location) 'pubspec.yaml')) {
        $projectRoot = (Get-Location).Path
    } else {
        throw 'Project root tidak ditemukan. Jalankan script dari project AyoSuruh atau simpan di folder tools.'
    }
}

Set-Location $projectRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter tidak ditemukan di PATH.'
}

$pubspec = Get-Content '.\pubspec.yaml' -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*([^\r\n]+)')
if (-not $versionMatch.Success) {
    throw 'Versi aplikasi tidak ditemukan di pubspec.yaml.'
}

$fullVersion = $versionMatch.Groups[1].Value.Trim()
$parts = $fullVersion -split '\+'
$versionName = $parts[0]
$buildNumber = if ($parts.Count -gt 1) { $parts[1] } else { '0' }

Write-Host "Ayo Suruh Android Release" -ForegroundColor Cyan
Write-Host "Version : $versionName"
Write-Host "Build   : $buildNumber"
Write-Host "Package : com.ayosuruh.app"

if (-not (Test-Path '.\android\key.properties')) {
    throw @'
android/key.properties tidak ditemukan.
Release Play Store harus ditandatangani dengan keystore PRODUKSI YANG SAMA dengan rilis sebelumnya.
Jangan membuat keystore baru jika Ayo Suruh sudah pernah dipublikasikan dengan signing key lama.
'@
}

if (-not $SkipClean) {
    Write-Host "`n[1/6] flutter clean" -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'flutter clean gagal.' }
}

Write-Host "`n[2/6] flutter pub get" -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get gagal.' }

Write-Host "`n[3/6] flutter analyze" -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze belum bersih. Release dibatalkan.' }

Write-Host "`n[4/6] Build signed release APK" -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Build APK release gagal.' }

if (-not $SkipBundle) {
    Write-Host "`n[5/6] Build signed release App Bundle" -ForegroundColor Yellow
    flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) { throw 'Build AAB release gagal.' }
} else {
    Write-Host "`n[5/6] App Bundle dilewati (-SkipBundle)" -ForegroundColor DarkGray
}

Write-Host "`n[6/6] Packaging artifacts" -ForegroundColor Yellow
$releaseDir = Join-Path $projectRoot "release\android\v$versionName-build$buildNumber"
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$apkSource = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apkSource)) { throw "APK hasil build tidak ditemukan: $apkSource" }

$apkFriendly = Join-Path $releaseDir 'AyoSuruh.apk'
$apkVersioned = Join-Path $releaseDir "AyoSuruh-v$versionName-build$buildNumber.apk"
Copy-Item $apkSource $apkFriendly -Force
Copy-Item $apkSource $apkVersioned -Force

$artifactLines = @()
$artifactLines += "Ayo Suruh Android Release"
$artifactLines += "Version: $versionName"
$artifactLines += "Build: $buildNumber"
$artifactLines += "Package: com.ayosuruh.app"
$artifactLines += "Created: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss K'))"
$artifactLines += ''

$apkHash = (Get-FileHash $apkFriendly -Algorithm SHA256).Hash
$artifactLines += "AyoSuruh.apk  SHA256  $apkHash"

if (-not $SkipBundle) {
    $aabSource = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
    if (-not (Test-Path $aabSource)) { throw "AAB hasil build tidak ditemukan: $aabSource" }
    $aabTarget = Join-Path $releaseDir "AyoSuruh-v$versionName-build$buildNumber.aab"
    Copy-Item $aabSource $aabTarget -Force
    $aabHash = (Get-FileHash $aabTarget -Algorithm SHA256).Hash
    $artifactLines += "$(Split-Path $aabTarget -Leaf)  SHA256  $aabHash"
}

$artifactLines | Set-Content (Join-Path $releaseDir 'RELEASE-INFO.txt') -Encoding UTF8

Write-Host "`nRelease selesai." -ForegroundColor Green
Write-Host "APK direct install : $apkFriendly" -ForegroundColor Green
if (-not $SkipBundle) {
    Write-Host "AAB Play Store      : $(Join-Path $releaseDir "AyoSuruh-v$versionName-build$buildNumber.aab")" -ForegroundColor Green
}
Write-Host "SHA256              : $(Join-Path $releaseDir 'RELEASE-INFO.txt')" -ForegroundColor Green
Write-Host "`nCatatan: untuk update Google Play, upload file .aab dan gunakan signing key yang sama dengan rilis sebelumnya." -ForegroundColor Cyan
