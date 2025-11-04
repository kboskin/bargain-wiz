# Flavor Configuration Guide

This project supports two flavors: **dev** and **prod**.

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
# Run dev flavor (with .dev bundle ID suffix)
flutter run --dart-define=FLAVOR=dev -t lib/main.dart

# Run prod flavor
flutter run --dart-define=FLAVOR=prod -t lib/main.dart

# Build iOS for dev (requires manual bundle ID update in Xcode or use scheme)
flutter build ios --dart-define=FLAVOR=dev

# Build iOS for prod
flutter build ios --dart-define=FLAVOR=prod
```

**Note**: For iOS, you may need to manually configure schemes in Xcode to fully support automatic bundle ID switching, or use the provided script in `ios/Runner/update_bundle_id.sh` as a build phase.

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

