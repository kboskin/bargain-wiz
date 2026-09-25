import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/gradient_background_config.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_config.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/welcome_screen_config.dart';
import 'package:appwizard/features/subscription/data/models/subscription_config.dart';
import 'package:appwizard/features/home/data/models/main_page_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/home/data/models/rate_us_modal_config.dart';
import 'package:appwizard/features/home/data/models/refer_config.dart';
import 'package:appwizard/features/home/data/models/share_config.dart';
import 'package:appwizard/core/config/app_config.dart';

/// Firebase Remote Config values, with the bundled asset defaults as a floor.
///
/// Notifies its listeners when a fetch activates new values, so the widget tree can pick
/// them up after the first frame (see [loadDefaults] / [refresh]).
class RemoteConfigService extends ChangeNotifier {
  final AppLogger _logger;

  RemoteConfigService(this._logger);

  /// Parsed configs, memoised by key. The getters below are called from `build` methods (the
  /// root gradient on every root rebuild), and decoding the same JSON on every frame is pure
  /// waste. Cleared whenever new values are activated.
  final Map<String, Object?> _parsed = {};

  T? _memo<T>(String key, T? Function() parse) {
    if (_parsed.containsKey(key)) return _parsed[key] as T?;
    final value = parse();
    _parsed[key] = value;
    return value;
  }

  /// Bundled defaults from the asset file: everything the UI can render without a network
  /// call. Awaited once at startup.
  Future<void> loadDefaults() async {
    final remoteConfig = FirebaseService.remoteConfig;
    if (remoteConfig == null) {
      _logger.w('Firebase Remote Config not available');
      return;
    }
    try {
      final defaultsJson = await rootBundle.loadString('assets/config/remote_config_defaults.json');
      final defaultsMap = jsonDecode(defaultsJson) as Map<String, dynamic>;
      // setDefaults takes strings; the asset values are already JSON-encoded strings.
      final defaults = <String, dynamic>{
        for (final entry in defaultsMap.entries) entry.key: entry.value.toString(),
      };
      await remoteConfig.setDefaults(defaults);
      _parsed.clear();
      _logger.i('Remote Config defaults loaded from asset file (${defaults.length} keys)');
    } on Object catch (e, stackTrace) {
      _logger.e('Error loading Remote Config defaults', e, stackTrace);
    }
  }

  /// Fetches and activates remote values, then notifies listeners so config-driven widgets
  /// rebuild. Runs in the background: the fetch can take seconds (10 s timeout), so no frame
  /// ever waits for it.
  Future<void> refresh() async {
    final remoteConfig = FirebaseService.remoteConfig;
    if (remoteConfig == null) return;
    try {
      final activated = await remoteConfig.fetchAndActivate();
      _logger.i('Remote Config fetched${activated ? ' and activated' : ' (unchanged)'}');
      if (activated) {
        _parsed.clear();
        notifyListeners();
      }
    } on Object catch (e) {
      _logger.w('Error fetching Remote Config: $e');
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

  /// Base URL of our backend, the project's Cloud Functions host (key: [api_url]), without
  /// a trailing slash, e.g. `https://us-central1-wizard-app-dev.cloudfunctions.net`.
  /// Set per Firebase project (dev / prod). Empty when not configured.
  String getApiUrl() {
    // Local flavor: the Functions emulator, whatever Remote Config says.
    if (AppConfig.isLocal) return AppConfig.localApiUrl(Firebase.app().options.projectId);
    final url = getString('api_url').trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      _logger.w('api_url is not configured');
    }
    return url;
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

  /// Onboarding screens parsed from the value in hand — remote when a fetch has activated,
  /// the bundled defaults otherwise — and memoised until new values activate. The sync
  /// counterpart of [getOnboardingScreensFresh], for screens that are read during a build
  /// (the Profile answer rows). A screen that fails to parse is skipped, so one bad entry
  /// cannot empty the list.
  List<OnboardingModel> getOnboardingScreens() =>
      _memo<List<OnboardingModel>>('onboarding_screens:parsed', () {
        final raw = getString('onboarding_screens');
        if (raw.isEmpty) return const [];
        try {
          final json = jsonDecode(raw);
          if (json is! List) return const [];
          final screens = <OnboardingModel>[];
          for (final item in json.whereType<Map>()) {
            try {
              screens.add(OnboardingModel.fromJson(Map<String, dynamic>.from(item)));
            } on Object catch (e) {
              _logger.w('Skipping malformed onboarding screen: $e');
            }
          }
          return screens;
        } on Object catch (e, stackTrace) {
          _logger.e('Error parsing onboarding_screens', e, stackTrace);
          return const [];
        }
      }) ??
      const [];

  /// The configured answers as fields — key, kind, options and every attribute the UI draws
  /// (label, colour, icon, subtext, emoji, savings). Built straight from the typed screen
  /// models, so nothing about a tone or a push level is described in Dart. Memoised until
  /// new values activate.
  List<ProfileField> getProfileFields() =>
      _memo<List<ProfileField>>('profile_fields', () => ProfileFields.fromScreens(getOnboardingScreens())) ??
      const [];

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
  OnboardingConfig? getOnboardingConfig() => _memo('onboarding_config', () {
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
  
      });

  /// Main-screen gradient from [main_page_config].background.
  /// Used by root PastelGradientBackground.
  GradientBackgroundConfig? getGradientBackgroundConfig() =>
      getMainPageConfig()?.background;

  /// Get welcome screen configuration from Remote Config
  /// Returns null if not configured
  WelcomeScreenConfig? getWelcomeScreenConfig() => _memo('welcome_screen_config', () {
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
  
      });

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
  SubscriptionConfig? getSubscriptionConfig() => _memo('subscription_config', () {
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
  
      });

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
  MainPageConfig? getMainPageConfig() => _memo('main_page_config', () {
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
  
      });

  /// Get share configuration from Remote Config (key: [share_config]).
  /// Used when the user taps Share to generate a Firebase link with title, description, imageUrl.
  /// Returns null if not configured.
  ShareConfig? getShareConfig() => _memo('share_config', () {
      try {
        final jsonString = getString('share_config');
        if (jsonString.isEmpty) {
          return null;
        }
        final json = jsonDecode(jsonString);
        if (json is! Map<String, dynamic>) {
          _logger.w('Invalid share_config format');
          return null;
        }
        return ShareConfig.fromJson(json);
      } catch (e, stackTrace) {
        _logger.e('Error parsing share config', e, stackTrace);
        return null;
      }
  
      });

  /// Rate Us / satisfaction modal config (key: [rate_us_modal_config]).
  /// Same structure as permission screen: title, visual, buttons (ButtonConfig).
  /// Returns null if not configured or parsing fails.
  RateUsModalConfig? getRateUsModalConfig() => _memo('rate_us_modal_config', () {
      try {
        final jsonString = getString('rate_us_modal_config');
        if (jsonString.isEmpty) {
          return null;
        }
        final json = jsonDecode(jsonString);
        if (json is! Map<String, dynamic>) {
          _logger.w('Invalid rate_us_modal_config format');
          return null;
        }
        return RateUsModalConfig.fromJson(json);
      } catch (e, stackTrace) {
        _logger.e('Error parsing rate_us_modal_config', e, stackTrace);
        return null;
      }
  
      });

  /// Refer / invite-friends config (key: [refer_config]).
  /// Title, benefits list, CTA button text; optional share_title, share_description, share_link_url.
  /// Returns null if not configured or parsing fails.
  ReferConfig? getReferConfig() => _memo('refer_config', () {
      try {
        final jsonString = getString('refer_config');
        if (jsonString.isEmpty) {
          return null;
        }
        final json = jsonDecode(jsonString);
        if (json is! Map<String, dynamic>) {
          _logger.w('Invalid refer_config format');
          return null;
        }
        return ReferConfig.fromJson(json);
      } catch (e, stackTrace) {
        _logger.e('Error parsing refer_config', e, stackTrace);
        return null;
      }
  
      });

  /// The payment provider `paywall_config.payment_provider` names (`iap` | `stripe`). Remote
  /// Config is the only switch: anything else, or no paywall config, is IAP.
  PaymentProviderType getPaymentProviderType() =>
      getPaywallConfig()?.paymentProvider?.toLowerCase().trim() == 'stripe'
          ? PaymentProviderType.stripe
          : PaymentProviderType.iap;
}

