import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/data/models/remote_config/gradient_background_config.dart';
import 'package:appwizard/data/models/remote_config/onboarding_config.dart';
import 'package:appwizard/data/models/remote_config/welcome_screen_config.dart';
import 'package:appwizard/data/models/remote_config/subscription_config.dart';
import 'package:appwizard/data/models/remote_config/main_page_config.dart';
import 'package:appwizard/data/models/remote_config/paywall_config.dart';
import 'package:appwizard/core/config/app_config.dart';

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

  /// Get onboarding screens from Remote Config (key: [onboarding_screens]).
  /// The upload progress screen config is inline: the data_upload entry in this
  /// list has [DataUploadScreenModel.visual] and metadata (texts, text_interval_seconds, progress_ramp_seconds).
  /// Always fetches fresh from Remote Config.
  /// Returns a list of OnboardingModel instances (polymorphic).
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
      final screens = json.map((final item) {
        if (item is! Map<String, dynamic>) {
          throw FormatException(
            'Expected Map<String, dynamic> for screen, got ${item.runtimeType}',
          );
        }
        return OnboardingModel.fromJson(item);
      }).toList();
      
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

  /// Get onboarding config from Remote Config (key: [onboarding_config]).
  /// Contains e.g. background gradient for onboarding flow.
  /// Returns null if not configured.
  OnboardingConfig? getOnboardingConfig() {
    try {
      final jsonString = getString('onboarding_config');
      if (jsonString.isEmpty) {
        return null;
      }

      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        _logger.w('Invalid onboarding_config format');
        return null;
      }

      return OnboardingConfig.fromJson(json);
    } catch (e, stackTrace) {
      _logger.e('Error parsing onboarding config', e, stackTrace);
      return null;
    }
  }

  /// Main-screen gradient from [main_page_config].background.
  /// Used by root PastelGradientBackground.
  GradientBackgroundConfig? getGradientBackgroundConfig() =>
      getMainPageConfig()?.background;

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

  /// Get Privacy Policy URL from Remote Config
  /// Returns empty string if not configured
  String getPrivacyPolicyUrl() {
    try {
      final url = getString('privacy_policy_url');
      if (url.isEmpty) {
        _logger.w('Privacy policy URL is not configured');
      }
      return url;
    } catch (e, stackTrace) {
      _logger.e('Error getting privacy policy URL', e, stackTrace);
      return '';
    }
  }

  /// Get Terms of Use URL from Remote Config
  /// Returns empty string if not configured
  String getTermsOfUseUrl() {
    try {
      final url = getString('terms_of_use_url');
      if (url.isEmpty) {
        _logger.w('Terms of use URL is not configured');
      }
      return url;
    } catch (e, stackTrace) {
      _logger.e('Error getting terms of use URL', e, stackTrace);
      return '';
    }
  }

  /// Get subscription configuration from Remote Config
  /// Returns null if not configured
  SubscriptionConfig? getSubscriptionConfig() {
    try {
      final jsonString = getString('subscription_config');
      if (jsonString.isEmpty) {
        _logger.w('Subscription config is empty');
        return null;
      }

      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        _logger.w('Invalid subscription_config format');
        return null;
      }

      return SubscriptionConfig.fromJson(json);
    } catch (e, stackTrace) {
      _logger.e('Error parsing subscription config', e, stackTrace);
      return null;
    }
  }

  /// Get paywall configuration from Remote Config
  /// Returns null if not configured or parsing fails
  /// Uses defaults from remote_config_defaults.json if available
  PaywallConfig? getPaywallConfig({String? configKey}) {
    try {
      final key = configKey ?? 'paywall_config';
      final jsonString = getString(key);
      
      if (jsonString.isEmpty) {
        _logger.w('Paywall config is empty for key: $key');
        return null;
      }

      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        _logger.w('Invalid paywall config format for key: $key');
        return null;
      }

      return PaywallConfig.fromJson(json);
    } catch (e, stackTrace) {
      _logger.e('Error parsing paywall config', e, stackTrace);
      return null;
    }
  }

  /// Get main page configuration from Remote Config (key: [main_page_config]).
  /// Button texts and center visual (path + metadata) for the home screen.
  MainPageConfig? getMainPageConfig() {
    try {
      final jsonString = getString('main_page_config');
      if (jsonString.isEmpty) {
        return null;
      }
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        _logger.w('Invalid main_page_config format');
        return null;
      }
      return MainPageConfig.fromJson(json);
    } catch (e, stackTrace) {
      _logger.e('Error parsing main page config', e, stackTrace);
      return null;
    }
  }

  /// Get payment provider type, primarily from paywall config.
  /// Falls back to AppConfig.default (env) and then IAP.
  PaymentProviderType getPaymentProviderType() {
    try {
      final paywall = getPaywallConfig();
      final value = paywall?.paymentProvider?.toLowerCase().trim();
      switch (value) {
        case 'stripe':
          return PaymentProviderType.stripe;
        case 'iap':
          return PaymentProviderType.iap;
        default:
          // Fallback to compile-time config if RC doesn't specify.
          return AppConfig.paymentProviderType;
      }
    } catch (_) {
      return AppConfig.paymentProviderType;
    }
  }
}

