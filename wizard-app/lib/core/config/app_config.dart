import 'dart:io' show Platform;

/// App configuration based on flavor (`--dart-define=FLAVOR=dev|prod|local`, plus the
/// matching Android `--flavor`).
///
/// `local` is `dev` pointed at the Firebase emulators (Auth, Firestore, Storage, Functions)
/// started with `firebase emulators:start` in `wizard-backend/`; see README_FLAVORS.md.
class AppConfig {
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'prod',
  );

  static bool get isDev => flavor == 'dev';
  static bool get isProd => flavor == 'prod';

  /// Everything against the local Firebase emulators.
  static bool get isLocal => flavor == 'local';

  // App name
  /// Shown in the task switcher and as `MaterialApp.title`. Kept identical to the platform
  /// labels: Android `app_name` per product flavour, iOS `APP_DISPLAY_NAME` per build
  /// configuration.
  static String get appName {
    if (isLocal) return 'Bargain Wiz Local';
    if (isDev) return 'Bargain Wiz Dev';
    return 'Bargain Wiz';
  }

  // Enable debug features
  static bool get enableDebugFeatures => isDev || isLocal;

  // Logging level
  static bool get verboseLogging => isDev || isLocal;

  /// `--dart-define=MOCK_AI=true` keeps the canned Express / Pro answers (UI work without
  /// the Cloud Functions). Default: real `express_dealmaker` / `pro_deal_closer` functions.
  static const bool useMockAi = bool.fromEnvironment('MOCK_AI');

  // ── Firebase emulators (local flavor) ────────────────────────────────────

  /// Host the emulators listen on, as seen from the device. The Android emulator reaches the
  /// host machine through 10.0.2.2; the iOS simulator shares the host's loopback. Override
  /// with `--dart-define=EMULATOR_HOST=192.168.x.x` for a physical device.
  static String get emulatorHost {
    const configured = String.fromEnvironment('EMULATOR_HOST');
    if (configured.isNotEmpty) return configured;
    return Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
  }

  /// Ports from `wizard-backend/firebase.json`.
  static const int emulatorAuthPort = int.fromEnvironment('EMULATOR_AUTH_PORT', defaultValue: 9099);
  static const int emulatorFirestorePort = int.fromEnvironment('EMULATOR_FIRESTORE_PORT', defaultValue: 8080);
  static const int emulatorStoragePort = int.fromEnvironment('EMULATOR_STORAGE_PORT', defaultValue: 9199);
  static const int emulatorFunctionsPort = int.fromEnvironment('EMULATOR_FUNCTIONS_PORT', defaultValue: 5001);

  /// Base URL of the Functions emulator for [projectId] (replaces the Remote Config `api_url`
  /// in the local flavor): `http://<host>:5001/<project>/us-central1`.
  static String localApiUrl(String projectId, {String region = 'us-central1'}) =>
      'http://$emulatorHost:$emulatorFunctionsPort/$projectId/$region';

  // Payment provider type
  static PaymentProviderType get paymentProviderType {
    // Can be overridden via environment variable
    const provider = String.fromEnvironment(
      'PAYMENT_PROVIDER',
      defaultValue: 'iap',
    );
    return provider == 'stripe'
        ? PaymentProviderType.stripe
        : PaymentProviderType.iap;
  }
}

/// Payment provider type enum
enum PaymentProviderType {
  iap,
  stripe,
}
