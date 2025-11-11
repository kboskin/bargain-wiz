import 'package:flutter/services.dart';
import 'dart:convert';
import '../utils/app_logger.dart';
import 'firebase_service.dart';
import '../../data/models/onboarding_model.dart';
import '../../data/models/json_serializable.dart';
import '../../data/models/gradient_background_config.dart';
import '../../data/models/welcome_screen_config.dart';

/// Service for managing Firebase Remote Config values
/// Always fetches fresh values from Remote Config (no caching)
class RemoteConfigService {
  final AppLogger _logger;

  RemoteConfigService(this._logger);

  /// Initialize Remote Config
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Remote Config Service...');

      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        _logger.w('Firebase Remote Config not available');
        return;
      }

      // Load defaults from asset file
      try {
        final defaultsJson = await rootBundle.loadString('assets/config/remote_config_defaults.json');
        final defaultsMap = jsonDecode(defaultsJson) as Map<String, dynamic>;
        
        // Remote Config setDefaults expects Map<String, dynamic> where values are strings
        // The values in remote_config_defaults.json are already JSON-encoded strings
        final defaults = <String, dynamic>{};
        defaultsMap.forEach((key, value) {
          // Values are already strings (JSON-encoded), so use them directly
          defaults[key] = value.toString();
        });
        
        await remoteConfig.setDefaults(defaults);
        _logger.i('Remote Config defaults loaded from asset file (${defaults.length} keys)');
      } catch (e) {
        _logger.w('Error loading Remote Config defaults: $e');
      }

      // Fetch fresh values from Remote Config
      try {
        await remoteConfig.fetchAndActivate();
        _logger.i('Remote Config fetched and activated');
      } catch (e) {
        _logger.w('Error fetching Remote Config: $e');
      }
      
      _logger.i('Remote Config Service initialized');
    } catch (e, stackTrace) {
      _logger.e('Error initializing Remote Config Service', e, stackTrace);
    }
  }

  /// Get a string value from Remote Config
  /// Returns empty string if not found
  String getString(String key, {String defaultValue = ''}) {
    try {
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        return defaultValue;
      }
      final value = remoteConfig.getString(key);
      return value.isEmpty ? defaultValue : value;
    } catch (e) {
      _logger.w('Error getting string value for key $key: $e');
      return defaultValue;
    }
  }

  /// Get onboarding screens from Remote Config
  /// Always fetches fresh from Remote Config
  /// Returns a list of OnboardingModel instances (polymorphic)
  Future<List<OnboardingModel>> getOnboardingScreensFresh() async {
    try {
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        _logger.w('Firebase Remote Config not available');
        return [];
      }

      // Get from Remote Config
      final jsonString = remoteConfig.getString('onboarding_screens');
      
      if (jsonString.isEmpty) {
        _logger.w('Onboarding screens config is empty');
        return [];
      }

      // Parse and return screens
      final json = jsonDecode(jsonString);
      
      if (json is! List) {
        throw FormatException(
          'Expected List for onboarding_screens, got ${json.runtimeType}',
        );
      }
      
      // Use strict parsing with validation - returns polymorphic OnboardingModel instances
      final screens = json.mapToModel<OnboardingModel>(
        (item) => OnboardingModel.fromJson(item),
      );
      
      _logger.i('Loaded ${screens.length} onboarding screens from Remote Config');
      return screens;
    } catch (e, stackTrace) {
      _logger.e('Error loading onboarding screens from Remote Config', e, stackTrace);
      return [];
    }
  }

  /// Get a boolean value from Remote Config
  bool getBool(String key, {bool defaultValue = false}) {
    try {
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        return defaultValue;
      }
      return remoteConfig.getBool(key);
    } catch (e) {
      _logger.w('Error getting bool value for key $key: $e');
      return defaultValue;
    }
  }

  /// Get an integer value from Remote Config
  int getInt(String key, {int defaultValue = 0}) {
    try {
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        return defaultValue;
      }
      return remoteConfig.getInt(key);
    } catch (e) {
      _logger.w('Error getting int value for key $key: $e');
      return defaultValue;
    }
  }

  /// Get a double value from Remote Config
  double getDouble(String key, {double defaultValue = 0.0}) {
    try {
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        return defaultValue;
      }
      return remoteConfig.getDouble(key);
    } catch (e) {
      _logger.w('Error getting double value for key $key: $e');
      return defaultValue;
    }
  }

  /// Get gradient background configuration from Remote Config
  /// Returns null if not configured
  GradientBackgroundConfig? getGradientBackgroundConfig() {
    try {
      final jsonString = getString('gradient_background_config');
      if (jsonString.isEmpty) {
        return null;
      }

      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        _logger.w('Invalid gradient_background_config format');
        return null;
      }

      return GradientBackgroundConfig.fromJson(json);
    } catch (e, stackTrace) {
      _logger.e('Error parsing gradient background config', e, stackTrace);
      return null;
    }
  }

  /// Get welcome screen configuration from Remote Config
  /// Returns null if not configured
  WelcomeScreenConfig? getWelcomeScreenConfig() {
    try {
      final jsonString = getString('welcome_screen_config');
      if (jsonString.isEmpty) {
        _logger.w('Welcome screen config is empty');
        return null;
      }

      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        _logger.w('Invalid welcome_screen_config format');
        return null;
      }

      return WelcomeScreenConfig.fromJson(json);
    } catch (e, stackTrace) {
      _logger.e('Error parsing welcome screen config', e, stackTrace);
      return null;
    }
  }
}

