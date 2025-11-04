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
- Generate `lib/core/services/firebase_options.dart` with your project configuration
- Configure Android and iOS projects

## Step 3: Add Firebase Configuration Files

### Android

The configuration will automatically add `google-services.json` to:
- `android/app/google-services.json`

### iOS

The configuration will automatically add `GoogleService-Info.plist` to:
- `ios/Runner/GoogleService-Info.plist`

## Step 4: Verify Setup

After running `flutterfire configure`, verify:

1. ✅ `lib/core/services/firebase_options.dart` is generated with your project config
2. ✅ `android/app/google-services.json` exists
3. ✅ `ios/Runner/GoogleService-Info.plist` exists

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
- Run `flutterfire configure` to generate `firebase_options.dart`

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

