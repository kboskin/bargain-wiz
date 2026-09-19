# Firebase Setup Guide

This project has Firebase SDK integrated. Follow these steps to complete the setup.

## Prerequisites

1. A Firebase project (create at https://console.firebase.google.com/)
2. FlutterFire CLI installed

## Step 1: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

## Step 2: Configure Firebase

Run the FlutterFire configuration command:

```bash
flutterfire configure
```

This will:
- Connect to your Firebase project
- Drop `google-services.json` into `android/app/`
- Drop `GoogleService-Info.plist` into `ios/Runner/`

**Delete the `lib/firebase_options.dart` it also generates.** The app calls
`Firebase.initializeApp()` with no options, so each platform reads its own config file and
there is nothing to keep in sync by hand:

- **Android** — the `com.google.gms.google-services` Gradle plugin compiles
  `android/app/google-services.json` into string resources at build time.
- **iOS** — `FirebaseApp.configure()` reads `GoogleService-Info.plist` out of the app bundle.
  The file must be a member of the **Runner** target (Xcode › Runner › Build Phases › Copy
  Bundle Resources); `flutterfire configure` usually adds it, but check after a project
  regeneration — a missing plist fails at launch, not at build.

## Step 3: Verify Setup

1. ✅ `android/app/google-services.json` exists and lists your `package_name`
   (the `dev`/`local` flavors add the `.dev` suffix to `com.bargain.wiz`)
2. ✅ `ios/Runner/GoogleService-Info.plist` exists and is in the Runner target's resources:
   `grep GoogleService-Info ios/Runner.xcodeproj/project.pbxproj` should show a
   `in Resources` entry
3. ✅ No `firebase_options.dart` anywhere in `lib/`

## Firebase Services Included

### 1. Firebase Core
- Base Firebase initialization
- Platform-specific configuration

### 2. Firebase Analytics
- Track user events and app usage
- Access via: `FirebaseService.analytics`

### 3. Firebase Crashlytics
- Automatic crash reporting
- Error tracking
- Access via: `FirebaseService.crashlytics`

### 4. Firebase Cloud Messaging (FCM)
- Push notifications
- Access via: `FirebaseService.messaging`

### 5. Firebase Remote Config
- Remote configuration management
- Feature flags
- Access via: `FirebaseService.remoteConfig`

## Usage Examples

### Analytics

```dart
import 'package:appwizard/core/services/firebase_service.dart';

// Log an event
await FirebaseService.analytics?.logEvent(
  name: 'button_click',
  parameters: {'button_name': 'submit'},
);
```

### Crashlytics

```dart
// Log a non-fatal error
await FirebaseService.crashlytics?.recordError(
  error,
  stackTrace,
  fatal: false,
);

// Log a message
await FirebaseService.crashlytics?.log('User performed action');
```

### Remote Config

```dart
// Get a value
final apiUrl = FirebaseService.remoteConfig?.getString('api_url');
final featureEnabled = FirebaseService.remoteConfig?.getBool('feature_enabled');

// Fetch and activate updates
await FirebaseService.remoteConfig?.fetchAndActivate();
```

### Cloud Messaging

```dart
// Get FCM token
final token = await FirebaseService.messaging?.getToken();
print('FCM Token: $token');

// Listen to messages
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Got a message: ${message.notification?.title}');
});
```

## Flavor Configuration

For different Firebase projects per flavor:

1. Create separate Firebase projects for dev and prod
2. Run `flutterfire configure` for each flavor
3. Update `firebase_service.dart` to select the correct options based on flavor

## Troubleshooting

### Error: "Firebase options not configured"
- Run `flutterfire configure` to refresh `google-services.json` / `GoogleService-Info.plist`

### Error: "google-services.json not found"
- Ensure `android/app/google-services.json` exists
- Re-run `flutterfire configure`

### Error: "GoogleService-Info.plist not found"
- Ensure `ios/Runner/GoogleService-Info.plist` exists
- Re-run `flutterfire configure`

### Build errors
- Run `flutter clean` and `flutter pub get`
- Ensure Google Services plugin is properly configured in `build.gradle.kts`

## Next Steps

1. Set up Firebase Console:
   - Enable Analytics
   - Configure Crashlytics
   - Set up Cloud Messaging (FCM)
   - Configure Remote Config parameters

2. Test Firebase services in your app

3. Monitor Firebase Console for:
   - Analytics events
   - Crash reports
   - Remote Config updates

