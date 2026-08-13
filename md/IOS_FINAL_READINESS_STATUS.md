# Ayo Suruh — Final Platform Readiness Status

**Version:** 1.1.0 (Build 2)
**Package / Bundle ID:** `com.ayosuruh.app`
**Readiness checkpoint:** 13 August 2026

## Android

- Release APK build: passed
- Release AAB build: passed
- Direct-install artifact: `AyoSuruh.apk`
- Play artifact: `AyoSuruh-v1.1.0-build2.aab`
- Public Play Store upload can be handled separately.

## iOS

- Native Flutter/iOS project: ready
- Firebase iOS registration: ready
- Native Google Sign-In configuration: ready
- Sign in with Apple implementation/entitlement preparation: ready
- Camera, photo, microphone and location permissions: prepared
- Background location/audio/fetch/remote-notification configuration: prepared
- iOS minimum deployment target: 15.0
- CocoaPods resolution: passed
- Unsigned Debug build on macOS/Xcode: passed
- Unsigned Release build on macOS/Xcode: passed
- Codemagic release-validation commit: `799d3e3`

### Distribution boundary

The iOS application is **native-build validated**, but it is not publicly distributed. Apple signing, TestFlight and App Store distribution are intentionally deferred.

## Approved public wording

### Indonesian

**Android tersedia · iOS siap**

Ayo Suruh tersedia untuk Android. Native build iOS telah divalidasi pada macOS/Xcode, sementara distribusi publik iOS akan menyusul.

### English

**Android Available · iOS Ready**

Ayo Suruh is available for Android. The native iOS build has been validated on macOS/Xcode, while public iOS distribution will follow later.

## Revalidation rule

After meaningful Flutter dependency, iOS configuration, authentication, notification, location, camera or LiveKit changes, rerun at minimum:

1. `flutter analyze`
2. Codemagic `Ayo Suruh iOS - Unsigned Release Validation`

This keeps the `iOS Ready` claim grounded in an actual current native Release compile.
