import '../../data/models/onboarding_screen_config.dart';
import '../utils/app_logger.dart';
import 'remote_config_service.dart';

/// Service for managing onboarding configuration
/// Onboarding screens are always fetched fresh from Remote Config (not cached)
class OnboardingService {
  final RemoteConfigService _remoteConfigService;
  final AppLogger _logger;

  OnboardingService(this._remoteConfigService, this._logger);

  /// Get onboarding screen configuration directly from Remote Config (not cached)
  /// Always fetches fresh data from Remote Config to ensure latest configuration
  /// Returns empty config if not found in Remote Config
  Future<OnboardingConfig> getOnboardingConfig() async {
    try {
      // Get directly from Remote Config (not from cache)
      final remoteConfigString = await _remoteConfigService.getOnboardingScreensFresh();
      if (remoteConfigString.isNotEmpty) {
        try {
          final config = OnboardingConfig.fromJsonString(remoteConfigString);
          _logger.i('Loaded onboarding config directly from Remote Config');
          return config;
        } catch (e, stackTrace) {
          _logger.e('Error parsing Remote Config onboarding config', e, stackTrace);
        }
      }

      // Return empty config if not found - no hardcoded defaults
      _logger.w('No onboarding config found in Remote Config, returning empty config');
      return OnboardingConfig(screens: []);
    } catch (e, stackTrace) {
      _logger.e('Error loading onboarding config', e, stackTrace);
      return OnboardingConfig(screens: []);
    }
  }
}

