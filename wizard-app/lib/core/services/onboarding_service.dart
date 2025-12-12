import 'package:appwizard/data/models/onboarding_model.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'remote_config_service.dart';

/// Service for managing onboarding configuration
/// Onboarding screens are always fetched fresh from Remote Config (not cached)
class OnboardingService {
  final RemoteConfigService _remoteConfigService;
  final AppLogger _logger;

  OnboardingService(this._remoteConfigService, this._logger);

  /// Get onboarding screen models directly from Remote Config (not cached)
  /// Always fetches fresh data from Remote Config to ensure latest configuration
  /// Returns list of OnboardingModel instances (polymorphic)
  Future<List<OnboardingModel>> getOnboardingConfig() async {
    try {
      // Get directly from Remote Config (not from cache) - returns list of models
      final screens = await _remoteConfigService.getOnboardingScreensFresh();
      if (screens.isNotEmpty) {
        _logger.i('Loaded ${screens.length} onboarding screens directly from Remote Config');
        return screens;
      }

      // Return empty list if not found - no hardcoded defaults
      _logger.w('No onboarding config found in Remote Config, returning empty list');
      return [];
    } catch (e, stackTrace) {
      _logger.e('Error loading onboarding config', e, stackTrace);
      return [];
    }
  }
}

