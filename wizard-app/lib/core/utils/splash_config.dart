/// Splash screen configuration constants
/// This file contains configuration for splash screen behavior
class SplashConfig {
  /// Minimum duration to show splash screen (in milliseconds)
  /// This ensures the splash screen is visible long enough for users to see it
  static const int minSplashDurationMs = 2000;

  /// Maximum duration to show splash screen (in milliseconds)
  /// After this time, the app will navigate away even if initialization isn't complete
  static const int maxSplashDurationMs = 5000;

  /// Whether to show splash screen during app initialization
  static const bool showSplashDuringInit = true;
}

