# Quick Guide: Switching Between Flavors

## Command Line (Flutter CLI)

### Running the App

```bash
# Run DEV flavor (debuggable, with .dev bundle ID)
flutter run --flavor dev

# Run PROD flavor
flutter run --flavor prod

# Run with specific mode
flutter run --flavor dev --debug      # Dev flavor, debug mode
flutter run --flavor dev --release    # Dev flavor, release mode
flutter run --flavor prod --debug     # Prod flavor, debug mode
flutter run --flavor prod --release   # Prod flavor, release mode
```

### Building APKs

```bash
# Build DEV APK (debug)
flutter build apk --flavor dev --debug

# Build DEV APK (release)
flutter build apk --flavor dev --release

# Build PROD APK (debug)
flutter build apk --flavor prod --debug

# Build PROD APK (release)
flutter build apk --flavor prod --release
```

### Building App Bundles (for Play Store)

```bash
# Build DEV App Bundle
flutter build appbundle --flavor dev

# Build PROD App Bundle
flutter build appbundle --flavor prod
```

### iOS (requires dart-define)

```bash
# Run DEV flavor on iOS
flutter run --flavor dev --dart-define=FLAVOR=dev -d <device_id>

# Run PROD flavor on iOS
flutter run --flavor prod --dart-define=FLAVOR=prod -d <device_id>

# Build iOS for DEV
flutter build ios --flavor dev --dart-define=FLAVOR=dev

# Build iOS for PROD
flutter build ios --flavor prod --dart-define=FLAVOR=prod
```

## VS Code / IDE

### Using Launch Configurations

1. Open the **Run and Debug** panel (Cmd+Shift+D / Ctrl+Shift+D)
2. Select from the dropdown:
   - **Dev (Debug)** - Dev flavor in debug mode
   - **Dev (Profile)** - Dev flavor in profile mode
   - **Prod (Debug)** - Prod flavor in debug mode
   - **Prod (Release)** - Prod flavor in release mode
3. Click the play button or press F5

### Creating Custom Launch Configurations

Edit `.vscode/launch.json` to add more configurations:

```json
{
  "name": "Dev (Hot Reload)",
  "request": "launch",
  "type": "dart",
  "flutterMode": "debug",
  "args": ["--flavor", "dev"]
}
```

## Android Studio / IntelliJ

1. Open **Run** → **Edit Configurations...**
2. Create a new **Flutter** configuration
3. Set:
   - **Name**: `Dev Debug`
   - **Additional run args**: `--flavor dev`
   - **Build mode**: Debug/Release/Profile
4. Repeat for other flavors

## Quick Reference

| Command | Flavor | Bundle ID | Debuggable |
|---------|--------|-----------|------------|
| `flutter run --flavor dev` | Dev | `com.bargain.wiz.dev` | ✅ Yes (debug mode) |
| `flutter run --flavor prod` | Prod | `com.bargain.wiz` | ❌ No (release mode) |
| `flutter build apk --flavor dev` | Dev | `com.bargain.wiz.dev` | ✅ Yes |
| `flutter build apk --flavor prod` | Prod | `com.bargain.wiz` | ❌ No |

## Troubleshooting

### Flavor not found error
- Make sure you're using `--flavor` (not `--flavour`)
- Ensure flavors are defined in `android/app/build.gradle.kts`

### iOS flavor not working
- iOS requires `--dart-define=FLAVOR=<flavor>` in addition to `--flavor`
- Example: `flutter run --flavor dev --dart-define=FLAVOR=dev`

### Both flavors installed at once
- ✅ This is normal! Different bundle IDs allow both to be installed
- Dev: `com.bargain.wiz.dev`
- Prod: `com.bargain.wiz`

## Tips

1. **Quick Switch**: Use VS Code launch configurations for fastest switching
2. **Verify Flavor**: Check app name in app drawer - "Bargain Wiz Dev" vs "Bargain Wiz"
3. **Check Bundle ID**: Settings → Apps → App info → Package name
4. **Debug Mode**: Dev flavor is debuggable when using `--debug` or default debug mode

