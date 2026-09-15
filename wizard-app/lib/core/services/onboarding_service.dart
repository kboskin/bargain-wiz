import 'dart:convert';

import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';

/// Service for managing onboarding configuration.
/// Onboarding screens are always fetched fresh from Remote Config (not cached);
/// when Remote Config is unavailable the bundled `onboarding_screens` defaults are parsed.
class OnboardingService {
  OnboardingService(this._remoteConfigService, this._logger);

  final RemoteConfigService _remoteConfigService;
  final AppLogger _logger;

  /// Returns the polymorphic list of [OnboardingModel]s (empty when nothing is configured).
  Future<List<OnboardingModel>> getOnboardingConfig() async {
    try {
      final screens = await _remoteConfigService.getOnboardingScreensFresh();
      if (screens.isNotEmpty) {
        _logger.i('Loaded ${screens.length} onboarding screens from Remote Config');
        return screens;
      }
      final fallback = _parseFallback();
      if (fallback.isNotEmpty) {
        _logger.w('Remote onboarding_screens unavailable; using ${fallback.length} default screens');
        return fallback;
      }
      _logger.w('No onboarding config found, returning empty list');
      return [];
    } on Object catch (e, stackTrace) {
      _logger.e('Error loading onboarding config', e, stackTrace);
      return [];
    }
  }

  List<OnboardingModel> _parseFallback() {
    try {
      final raw = _remoteConfigService.getString('onboarding_screens');
      if (raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return json
          .whereType<Map>()
          .map((m) => OnboardingModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on Object catch (e, st) {
      _logger.e('Error parsing default onboarding_screens', e, st);
      return const [];
    }
  }
}
