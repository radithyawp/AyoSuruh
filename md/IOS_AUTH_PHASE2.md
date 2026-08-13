# Ayo Suruh — iOS Auth Phase 2

## Current code state

- Native Sign in with Apple is wired to Supabase Auth using an ID token and nonce.
- Apple name metadata is stored immediately on first authorization when Apple provides it.
- The Apple button is shown only on iOS.
- `Runner.entitlements` is prepared with the Sign in with Apple entitlement; Xcode still needs to attach the capability to the Runner target during signing setup.
- Google remains native on Android.
- Google on iOS becomes native only after `GOOGLE_IOS_CLIENT_ID` is supplied; until then the existing Supabase OAuth browser flow remains the safe fallback.

## Google iOS setup (required before native Google testing)

1. In the Google Cloud project that owns the existing Supabase Web OAuth client, create an **iOS OAuth client**.
2. Bundle ID: `com.ayosuruh.app`.
3. In Supabase Dashboard > Authentication > Providers > Google, keep the Web client ID first and append the iOS client ID separated by a comma. Do not replace the Web client ID.
4. Add the iOS OAuth `REVERSED_CLIENT_ID` as an additional URL scheme in `ios/Runner/Info.plist` alongside `io.supabase.ayosuruh`.
5. Run/build with:

```bash
flutter run --dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID
```

For release builds, use the same define in the CI/build command. Do not put an OAuth client secret in the Flutter app.

## Apple setup (required before Apple button can authenticate)

1. Apple Developer > Identifiers > App IDs: register/modify `com.ayosuruh.app`.
2. Enable **Sign in with Apple** for the App ID.
3. In Xcode Runner > Signing & Capabilities, add **Sign in with Apple**. Xcode should attach `Runner/Runner.entitlements` to the Runner target; confirm the entitlement file is selected in Build Settings > Code Signing Entitlements and that signing uses the correct team.
4. Configure the Apple provider in Supabase Auth. For native sign-in, the native App ID / bundle ID must be accepted as a client ID. If web Apple OAuth is also configured, follow Supabase ordering requirements for Services ID vs native App ID.
5. Test first authorization with an Apple ID. Apple provides full name only on first authorization, so verify the user profile is populated.

## Verification

```bash
flutter pub get
flutter analyze
git diff --check
```

On macOS:

```bash
cd ios
pod install
cd ..
flutter build ios --debug --no-codesign
```


## Google iOS native client configured

The native iOS OAuth client is now configured for `com.ayosuruh.app`:

- iOS Client ID: `358694252315-0r01c963fpgr4kbehtg8l3fnslq2fdna.apps.googleusercontent.com`
- iOS URL scheme: `com.googleusercontent.apps.358694252315-0r01c963fpgr4kbehtg8l3fnslq2fdna`
- Server/Web Client ID remains: `358694252315-iv42egfmp2hviql1gnv2t2lk92ohjdtq.apps.googleusercontent.com`

`Info.plist` contains `GIDClientID`, `GIDServerClientID`, and the reversed iOS client ID URL scheme. `AuthService` initializes Google Sign-In natively on both Android and iOS.

Supabase Authentication > Providers > Google must allow both client IDs with the Web client first:

`358694252315-iv42egfmp2hviql1gnv2t2lk92ohjdtq.apps.googleusercontent.com,358694252315-0r01c963fpgr4kbehtg8l3fnslq2fdna.apps.googleusercontent.com`
