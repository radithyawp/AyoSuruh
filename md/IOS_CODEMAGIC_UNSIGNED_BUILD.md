# Ayo Suruh — Codemagic Unsigned iOS Build

Workflow `ios-unsigned-ci` is intended only to validate that Ayo Suruh compiles on macOS + Xcode before Apple code signing is configured.

## Environment

- Flutter 3.41.7
- Xcode 26.4
- Codemagic mac_mini_m2

## Build steps

1. flutter pub get
2. flutter analyze
3. flutter build ios --debug --no-codesign

## Expected artifact

`build/ios/iphoneos/Runner.app`

This artifact is unsigned. It is not for TestFlight, App Store, or direct installation on a physical iPhone.

## After this passes

1. Finish Apple Developer enrollment.
2. Register `com.ayosuruh.app`.
3. Enable Sign in with Apple.
4. Enable Push Notifications.
5. Configure APNs.
6. Configure Codemagic signing.
7. Build a signed IPA.
8. Upload to TestFlight.
9. Test on a physical iPhone.
