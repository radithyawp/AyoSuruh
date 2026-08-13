# Ayo Suruh iOS Phase 5 — iOS Ready Polish

This phase follows the first successful unsigned native iOS build on Codemagic/macOS/Xcode.

## Changes

- Hides the Google Play promotional banner when Ayo Suruh is running on iOS. Android keeps the existing Play Store banner unchanged.
- Makes Version Information explicit about iOS status: the native build is validated, while public iOS distribution is not enabled yet.
- Adds full Indonesian/English copy for the version information and version history introduced in v1.1.0.
- Adds a second Codemagic workflow, `ios-release-validation`, that compiles Ayo Suruh in **Release** mode with code signing disabled.

## Why release validation?

The existing `ios-unsigned-ci` workflow proves that the application compiles for an iOS device in Debug mode. `ios-release-validation` verifies the production compiler path without requiring an Apple Developer Program membership or signing certificate.

Successful output should produce an unsigned `Runner.app` under `build/ios/iphoneos/`.

## Distribution status

A successful unsigned release build means the native iOS application is build-ready. It does not make the app publicly installable. Public TestFlight/App Store distribution still requires Apple code signing and the Apple Developer Program.
