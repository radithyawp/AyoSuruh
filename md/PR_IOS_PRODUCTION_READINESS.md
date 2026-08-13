# PR — iOS Production Readiness

## Overview

This PR completes the current iOS-readiness milestone for Ayo Suruh while preserving the existing Android release path. It validates that the same Flutter product can compile natively for iOS in both Debug and Release configurations on a real macOS/Xcode environment.

## Highlights

- Standardized iOS bundle ID to `com.ayosuruh.app`.
- Registered and configured Firebase for iOS.
- Prepared Firebase Messaging/APNs-aware client handling.
- Added native Google Sign-In configuration for iOS.
- Added Sign in with Apple implementation and entitlements preparation.
- Added iOS camera, photo library, microphone, and location permission descriptions.
- Prepared background location, audio, fetch, and remote-notification modes.
- Added iOS app icon and native launch-screen branding.
- Added Keychain Sharing configuration for secure storage.
- Raised the minimum iOS deployment target to 15.0 for Firebase compatibility.
- Added Codemagic macOS workflows for unsigned Debug and Release validation.
- Successfully validated both native Debug and native Release builds on a Codemagic Mac mini M2.
- Added final Android/iOS platform-readiness communication and documentation.
- Refreshed Home banner slot 4 with the supplied final Indonesian/English Android + iOS Ready artwork.

## Validation

- `flutter analyze`: clean
- Android release APK: passed
- Android release AAB: passed
- iOS unsigned Debug build: passed
- iOS unsigned Release build: passed
- iOS Release validation commit: `799d3e3`

## Current iOS Distribution Status

The native iOS source and Release compile path are validated. Public iOS distribution remains intentionally deferred; no App Store/TestFlight availability is claimed in this PR. Apple code signing and public distribution can be enabled in a later release phase.

## Public Platform Wording

- Indonesian: **Tersedia di Android · Siap untuk iOS**
- English: **Available on Android · iOS Ready**

## Notes

- No database migration is introduced by the final banner/readiness cleanup.
- Existing Android business logic and production package ID remain unchanged.
- Environment secrets remain excluded from Git; Codemagic unsigned validation uses a placeholder env only for compile validation.
