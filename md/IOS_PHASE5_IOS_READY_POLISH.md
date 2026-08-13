# Ayo Suruh iOS Phase 5 — Final iOS Readiness

This phase closes the current iOS-readiness work after both unsigned Debug and unsigned Release builds succeeded on Codemagic using a real macOS/Xcode environment.

## Validated build milestones

- Bundle ID: `com.ayosuruh.app`
- Minimum target: iOS 15.0
- Codemagic machine: Mac mini M2
- Unsigned Debug build: **PASSED**
- Unsigned Release build: **PASSED**
- Release-validation commit: `799d3e3`
- Release artifact: `Runner.app.zip` (unsigned)

## Platform integration compiled successfully

The successful native build path includes Firebase Core/Messaging, Google Sign-In iOS, Sign in with Apple plugin, Camera AVFoundation, Image Picker iOS, Geolocator Apple, LiveKit/WebRTC, secure storage for Darwin, local notifications, and the Flutter application itself.

## Banner / platform communication

Home banner slot 4 now uses the supplied final Indonesian and English artwork **without image editing**. The artwork communicates:

- Android: available
- iOS: ready

The same platform-readiness banner is visible on both Android and iOS. On Android, tapping it may open Google Play. On iOS, tapping it only explains that the native build has been validated and that public iOS distribution is not open yet.

## Public distribution status

A successful unsigned Release build validates native source/build readiness, but it is not an App Store/TestFlight release. Public iOS installation remains deferred because Apple code signing/distribution has not been enabled.

Safe public wording:

- Indonesia: **Tersedia di Android · Siap untuk iOS**
- English: **Available on Android · iOS Ready**

Do not use an App Store download badge or claim public App Store availability until Apple distribution is actually enabled.
