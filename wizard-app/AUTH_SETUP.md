# Authentication Setup Guide

This app uses Firebase Authentication with multiple sign-in methods.

## Sign-In Methods

1. **Email/Password** - Traditional email and password authentication
2. **Google Sign-In** - OAuth authentication with Google
3. **Apple Sign-In** - Available only on iOS devices

## Firebase Console Setup

### 1. Enable Authentication Methods

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`wizard-app-dev`)
3. Navigate to **Authentication** → **Sign-in method**
4. Enable the following providers:
   - ✅ **Email/Password**
   - ✅ **Google** (requires configuration)
   - ✅ **Apple** (for iOS)

### 2. Configure Google Sign-In

1. In Firebase Console → Authentication → Sign-in method
2. Click on **Google**
3. Enable it and save
4. Note the **Web client ID** (you'll need this for Android/iOS)

### 3. Configure Apple Sign-In (iOS only)

1. In Firebase Console → Authentication → Sign-in method
2. Click on **Apple**
3. Enable it
4. Configure in Apple Developer Console:
   - Create a Service ID
   - Configure OAuth redirect URLs
   - Add the domain to Firebase

## Android Configuration

### Google Sign-In

The `google-services.json` file already includes Google configuration. Ensure:
- SHA-1 certificate fingerprint is added in Firebase Console
- OAuth client ID is configured

To get SHA-1:
```bash
cd android
./gradlew signingReport
```

Add the SHA-1 fingerprint to Firebase Console → Project Settings → Your Android app

## iOS Configuration

### Apple Sign-In

1. **Info.plist** - Already configured ✅
   - Added `com.apple.developer.applesignin` capability

2. **Xcode Configuration**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target
   - Go to **Signing & Capabilities**
   - Add **Sign in with Apple** capability
   - Ensure it's enabled for both dev and prod configurations

3. **Apple Developer Console**:
   - Create a Service ID for Sign in with Apple
   - Configure redirect URLs
   - Add domain verification in Firebase

## Usage

Everyone starts signed in anonymously; signing in links Google or Apple to that account
(`AuthService`, driven by `AuthBloc`). There are two entry points:

- **Sign-in sheet** (`SignInModal`) — opened from the onboarding welcome screen, the home
  drawer and the profile page. Google always; Apple on iOS. The Terms / Privacy links open the
  Remote Config URLs.
- **`create_account` onboarding screen** — labels and per-platform visibility come from the
  Remote Config template.
- **`SignInPage`** — full-page variant (glass card, Google + Apple on iOS). Its Terms / Privacy
  links are still placeholders (`// TODO` in `sign_in_page.dart`); wire them to
  `RemoteConfigService.getTermsOfUseUrl()` / `getPrivacyPolicyUrl()` as `SignInModal` does.

All three use the shared buttons in `lib/features/auth/presentation/widgets/auth_button.dart`:
`GoogleSignInButton` and `AppleSignInButton`, built on `AuthButton`. Use those for any new
entry point rather than styling a button by hand.

## Testing

### Test Email/Password
1. Create account with email/password
2. Sign in with existing account
3. Test password reset functionality

### Test Google Sign-In
1. Click "Continue with Google"
2. Select Google account
3. Grant permissions

### Test Apple Sign-In (iOS only)
1. Click "Continue with Apple"
2. Use Face ID/Touch ID or Apple ID password
3. Grant permissions

## Troubleshooting

### Google Sign-In not working
- Check SHA-1 fingerprint is added to Firebase
- Verify `google-services.json` is correct
- Ensure OAuth consent screen is configured

### Apple Sign-In not working
- Verify Sign in with Apple capability is enabled in Xcode
- Check Service ID is configured in Apple Developer
- Ensure bundle ID matches Firebase configuration

### Email/Password not working
- Verify Email/Password is enabled in Firebase Console
- Check email format is valid
- Ensure password meets minimum requirements (6 characters)

