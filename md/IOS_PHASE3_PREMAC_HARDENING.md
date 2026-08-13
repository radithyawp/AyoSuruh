# Ayo Suruh iOS — Phase 3 Pre-Mac Hardening

This checkpoint prepares the current iOS project for the first Mac/Xcode build without requiring Apple Developer enrollment to be completed yet.

## Included

- Wires `Runner/Runner.entitlements` into Runner Debug, Profile, and Release build configurations.
- Keeps the prepared Sign in with Apple entitlement in one shared entitlement file.
- Adds the Keychain Sharing entitlement required by `flutter_secure_storage` on iOS.
- Adds the `fetch` background mode alongside location, audio, and remote notifications.
- Keeps iOS deployment target at 13.0.

## Still requires Apple Developer / Xcode

Do not add fake signing values on Windows. On Mac/Xcode, configure the real team and capabilities:

1. Signing & Capabilities -> Team.
2. Sign in with Apple.
3. Push Notifications.
4. Background Modes:
   - Location updates
   - Audio, AirPlay, and Picture in Picture
   - Background fetch
   - Remote notifications
5. Create/upload an APNs authentication key to Firebase Cloud Messaging.

The physical iPhone build should only be attempted after the provisioning profile contains the capabilities used by the app.
