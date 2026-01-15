/// App configuration based on flavor
class AppConfig {
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'prod',
  );

  static bool get isDev => flavor == 'dev';
  static bool get isProd => flavor == 'prod';

  // API endpoints (example)
  static String get baseUrl {
    if (isDev) {
      return 'https://api-dev.example.com';
    }
    return 'https://api.example.com';
  }

  // App name
  static String get appName {
    if (isDev) {
      return 'Bargain Wiz (Dev)';
    }
    return 'Bargain Wiz';
  }

  // Enable debug features
  static bool get enableDebugFeatures => isDev;

  // Logging level
  static bool get verboseLogging => isDev;

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

