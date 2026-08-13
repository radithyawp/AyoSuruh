# Ayo Suruh — iOS Production Readiness

## Prepared in this phase

- Bundle identifier standardized to `com.ayosuruh.app`.
- Display name standardized to `Ayo Suruh`.
- iOS privacy usage descriptions added for camera, photo library, microphone, foreground location, and background live tracking.
- Background modes declared for mobility live location, in-app voice audio, and remote notifications.
- iOS notification initialization and foreground local notifications added.
- Device token registration now sends `ios` on Apple devices.
- FCM token retrieval waits for APNs readiness on iOS.
- Mobility live tracking uses Apple-specific location settings.
- Firebase startup is tolerant while the iOS Firebase app has not yet been registered; notification initialization activates automatically once FlutterFire adds iOS options.
- iOS launcher icon assets and native launch image use Ayo Suruh branding instead of Flutter defaults.

## External setup still required

1. Register the explicit Apple Bundle ID `com.ayosuruh.app`.
2. Select the Apple Developer Team in Xcode and enable:
   - Push Notifications
   - Background Modes: Location updates
   - Background Modes: Audio, AirPlay, and Picture in Picture
   - Background Modes: Remote notifications
3. Register the iOS app in Firebase / run FlutterFire configure so `firebase_options.dart` gains an iOS configuration.
4. Upload an APNs authentication key (`.p8`) to Firebase Cloud Messaging.
5. Configure a Google iOS OAuth client and URL scheme before enabling native Google Sign-In on iOS.
6. Because Ayo Suruh offers Google Sign-In for the primary account, review Apple App Review Guideline 4.8 and add an equivalent privacy-preserving login option (normally Sign in with Apple) before App Store submission unless an exemption applies.
7. Build and test on a real iPhone from macOS/Xcode.

## macOS verification commands

```bash
flutter clean
flutter pub get
flutter build ios --config-only
open ios/Runner.xcworkspace
```

After signing/capabilities/Firebase configuration are complete:

```bash
flutter analyze
flutter build ios --release
flutter build ipa --release
```
