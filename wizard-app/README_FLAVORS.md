# Flavor Configuration Guide

Startup sequence and its rules: `STARTUP.md`.

This project supports three flavors: **dev**, **prod** and **local** (local points Firebase at the emulator suite).

## Bundle IDs

- **Prod**: `com.bargain.wiz`
- **Dev**: `com.bargain.wiz.dev` (adds `.dev` suffix)

## Running the App

### Android

Android flavors are fully configured and automatically handle bundle IDs:

```bash
# Run dev flavor (debuggable, with .dev suffix)
flutter run --flavor dev -t lib/main.dart

# Run prod flavor
flutter run --flavor prod -t lib/main.dart

# Build APK for dev
flutter build apk --flavor dev

# Build APK for prod
flutter build apk --flavor prod

# Build App Bundle for dev
flutter build appbundle --flavor dev

# Build App Bundle for prod
flutter build appbundle --flavor prod
```

### iOS

For iOS, you need to pass the flavor via `--dart-define`:

```bash
# Run dev flavor (the Xcode scheme is named after the flavour)
flutter run --flavor dev --dart-define=FLAVOR=dev -t lib/main.dart

# Run prod flavor
flutter run --flavor prod --dart-define=FLAVOR=prod -t lib/main.dart

# Run against the Firebase emulators
flutter run --flavor local --dart-define=FLAVOR=local -t lib/main.dart

# Build iOS for dev (requires manual bundle ID update in Xcode or use scheme)
flutter build ios --dart-define=FLAVOR=dev

# Build iOS for prod
flutter build ios --dart-define=FLAVOR=prod
```

**Note**: For iOS, you may need to manually configure schemes in Xcode to fully support automatic bundle ID switching, or use the provided script in `ios/Runner/update_bundle_id.sh` as a build phase.

### App name

One convention on both platforms and in Dart:

| flavour | home-screen label |
| --- | --- |
| prod | Bargain Wiz |
| dev | Bargain Wiz Dev |
| local | Bargain Wiz Local |

Android takes it from `resValue("string", "app_name", …)` per product flavour, iOS from the
`APP_DISPLAY_NAME` build setting per configuration (`Info.plist` reads
`$(APP_DISPLAY_NAME)` for `CFBundleDisplayName`; `CFBundleName` stays the short "Bargain Wiz",
which Apple caps at 16 characters). `AppConfig.appName` matches, and feeds `MaterialApp.title`
(the Android task switcher). Change a name in all three places, or they drift.

### iOS flavours

iOS now has the same three flavours as Android, so `--flavor` works on both platforms and one
IDE run configuration serves either device. Each flavour is an Xcode **scheme** (`dev`, `prod`,
`local`, shared in `ios/Runner.xcodeproj/xcshareddata/xcschemes/`) plus three **build
configurations** named `Debug-<flavour>`, `Profile-<flavour>` and `Release-<flavour>`; Flutter
requires both, and the Podfile maps every one of them to a pod build type.

All three currently build the same bundle id (`com.bargain.wiz`) and the same Firebase app,
because only the dev Firebase project exists. When a prod project is added, give `*-prod` its
own `PRODUCT_BUNDLE_IDENTIFIER` and `GoogleService-Info.plist`.

To add another flavour: duplicate the configurations (the `xcodeproj` gem that ships with
CocoaPods can do it), copy `Runner.xcscheme` to `<flavour>.xcscheme` with the configuration
names rewritten, add it to the Podfile list, and run `pod install`.

### Local (Firebase emulators)

`local` is the dev app pointed at the emulators (Auth, Firestore, Storage, Functions). Start
them first from `wizard-backend/` (`firebase emulators:start --import=.emulator-data
--export-on-exit`, UI at http://127.0.0.1:4000) — without the import/export flags the Auth
emulator forgets its users on every restart. Then:

`local` and `dev` share the applicationId `com.bargain.wiz.dev`, so they also share one
Firebase Auth session store: switching between them hands the emulator a session the dev
project issued, or vice versa. `FirebaseService._useEmulators` logs an `[ERROR]` line when it
sees one; the cure either way is to clear the app data once
(`adb shell pm clear com.bargain.wiz.dev`).

```bash
# Android emulator (reaches the host through 10.0.2.2)
flutter run --flavor local --dart-define=FLAVOR=local -d emulator-5554

# iOS simulator (no Xcode flavor needed; shares the host's loopback)
flutter run --dart-define=FLAVOR=local -d <simulator-udid>

# Physical device on the same Wi-Fi: point at your machine
flutter run --flavor local --dart-define=FLAVOR=local --dart-define=EMULATOR_HOST=192.168.1.20
```

On both platforms `--dart-define=FLAVOR=local` is what selects the emulators; in **debug** builds it
works with any Gradle flavor because `src/debug/res/xml/network_security_config.xml` allows
plain HTTP (debug builds only). Release and profile builds allow it only in the `local`
Gradle flavor (`--flavor local`); anything else fails with "Cleartext HTTP traffic to
10.0.2.2 not permitted" and the app logs an error at startup.

What changes in `local`: Auth, Firestore and Storage use the emulators; `api_url` is replaced by
the Functions emulator (`http://<host>:5001/wizard-app-dev/us-central1`); Crashlytics and
Analytics collection are off. Remote Config has no emulator and still reads the dev project.
The Android flavor shares dev's applicationId (`com.bargain.wiz.dev`) so `google-services.json`
matches, which means dev and local cannot be installed side by side. Ports follow
`wizard-backend/firebase.json`; override with `EMULATOR_*_PORT` dart-defines if you change them.

### VS Code / IDE

Use the launch configurations in `.vscode/launch.json`:
- **Dev (Debug)** - Debug mode with dev flavor
- **Dev (Profile)** - Profile mode with dev flavor
- **Prod (Debug)** - Debug mode with prod flavor
- **Prod (Release)** - Release mode with prod flavor

## Differences Between Flavors

### Dev
- ✅ Bundle ID: `com.bargain.wiz.dev` (adds `.dev` suffix)
- ✅ App name: "Bargain Wiz Dev"
- ✅ **Debuggable: Yes** (as requested)
- ✅ Version name suffix: "-dev"
- ✅ Debug banner: Enabled (shows in top-right corner)
- ✅ Verbose logging enabled

### Prod
- ✅ Bundle ID: `com.bargain.wiz` (standard)
- ✅ App name: "Bargain Wiz"
- ✅ **Debuggable: No**
- ✅ Version name: Standard (1.0.0)
- ✅ Debug banner: Disabled
- ✅ Production logging

## Accessing Flavor in Code

Use `AppConfig` to access flavor-specific settings:

```dart
import 'package:appwizard/core/config/app_config.dart';

// Check flavor
if (AppConfig.isDev) {
  // Dev-specific code
  print('Running in dev mode');
}

// Get configuration values
String apiUrl = AppConfig.baseUrl;
String appName = AppConfig.appName;
bool enableDebug = AppConfig.enableDebugFeatures;
```

## Configuration Files

- **Android**: `android/app/build.gradle.kts` - Flavor configuration
- **iOS**: `ios/Flutter/Dev.xcconfig` and `ios/Flutter/Prod.xcconfig` - Build configs
- **Dart**: `lib/core/config/app_config.dart` - Runtime flavor detection
- **VS Code**: `.vscode/launch.json` - Launch configurations

## Versioning

Versioning is synchronized between Android and iOS:

- **Dev**: Adds `-dev` suffix to version name (e.g., `1.0.0-dev`)
- **Prod**: Standard version name (e.g., `1.0.0`)
- **Build Number**: Same for both flavors and platforms

See `VERSIONING.md` for detailed versioning information.

## Notes

- Both flavors can be installed simultaneously on the same device (different bundle IDs)
- Dev flavor is automatically debuggable on Android
- For iOS, you may need to configure code signing for the dev bundle ID in Xcode
- Versions are synchronized across platforms - see `VERSIONING.md` for details

