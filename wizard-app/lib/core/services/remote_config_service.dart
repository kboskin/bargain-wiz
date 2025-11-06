import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../utils/app_logger.dart';
import 'firebase_service.dart';

/// Service for managing Firebase Remote Config values
/// Loads and caches remote config values on app startup
class RemoteConfigService {
  static const String _configCachePrefix = 'remote_config_';
  static const String _defaultsAssetPath = 'assets/config/remote_config_defaults.json';
  final SharedPreferences _prefs;
  final AppLogger _logger;
  final Map<String, String> _cache = {};
  Map<String, dynamic> _defaults = {};

  RemoteConfigService(this._prefs, this._logger);

  /// Load default config values from asset file
  Future<void> _loadDefaultsFromAsset() async {
    try {
      final String jsonString = await rootBundle.loadString(_defaultsAssetPath);
      final Map<String, dynamic> json = jsonDecode(jsonString) as Map<String, dynamic>;
      _defaults = json;
      _logger.i('Loaded default config from asset file');
    } catch (e) {
      _logger.w('Error loading default config from asset, using empty defaults: $e');
      _defaults = {};
    }
  }

  /// Initialize and load remote config values on app startup
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Remote Config Service...');
      
      // Load defaults from asset file first
      await _loadDefaultsFromAsset();
      
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        _logger.w('Firebase Remote Config not available, using cached values');
        await _loadCachedValues();
        // Apply defaults for missing values
        _applyDefaults();
        return;
      }

      // Set defaults in Firebase Remote Config
      await _setDefaultsInRemoteConfig(remoteConfig);

      // Fetch fresh values from Remote Config
      try {
        await remoteConfig.fetchAndActivate();
        _logger.i('Remote Config fetched and activated');
      } catch (e) {
        _logger.w('Error fetching Remote Config, using cached values: $e');
      }

      // Load all config values into cache
      await _loadConfigValues(remoteConfig);
      
      // Apply defaults for any missing values
      _applyDefaults();
      
      _logger.i('Remote Config Service initialized');
    } catch (e, stackTrace) {
      _logger.e('Error initializing Remote Config Service', e, stackTrace);
      // Fallback to cached values
      await _loadCachedValues();
      _applyDefaults();
    }
  }

  /// Set defaults in Firebase Remote Config
  Future<void> _setDefaultsInRemoteConfig(FirebaseRemoteConfig remoteConfig) async {
    try {
      // Convert string values to appropriate types for Firebase Remote Config
      final Map<String, dynamic> defaultsForFirebase = {};
      for (final entry in _defaults.entries) {
        final value = entry.value;
        if (value is String) {
          defaultsForFirebase[entry.key] = value;
        } else {
          defaultsForFirebase[entry.key] = value.toString();
        }
      }
      
      await remoteConfig.setDefaults(defaultsForFirebase);
      _logger.i('Set defaults in Firebase Remote Config');
    } catch (e) {
      _logger.w('Error setting defaults in Firebase Remote Config: $e');
    }
  }

  /// Apply default values to cache for any missing keys
  void _applyDefaults() {
    for (final entry in _defaults.entries) {
      if (!_cache.containsKey(entry.key) || _cache[entry.key]!.isEmpty) {
        _cache[entry.key] = entry.value.toString();
        _logger.d('Applied default value for key: ${entry.key}');
      }
    }
  }

  /// Load config values from Remote Config into cache
  /// Excludes onboarding_screens as it should always be fetched fresh
  Future<void> _loadConfigValues(FirebaseRemoteConfig remoteConfig) async {
    // Get all known keys (you can extend this list)
    final knownKeys = [
      'api_url',
      'feature_enabled',
      // Add more keys as needed
      // Note: onboarding_screens is excluded from cache - always fetched fresh
    ];

    for (final key in knownKeys) {
      try {
        final value = remoteConfig.getString(key);
        if (value.isNotEmpty) {
          _cache[key] = value;
          // Cache to SharedPreferences for offline access
          await _prefs.setString('$_configCachePrefix$key', value);
          _logger.d('Cached Remote Config key: $key');
        }
      } catch (e) {
        _logger.w('Error loading config key $key: $e');
      }
    }
  }

  /// Load cached values from SharedPreferences
  Future<void> _loadCachedValues() async {
    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_configCachePrefix)) {
          final configKey = key.substring(_configCachePrefix.length);
          final value = _prefs.getString(key);
          if (value != null && value.isNotEmpty) {
            _cache[configKey] = value;
            _logger.d('Loaded cached config key: $configKey');
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading cached config values', e, stackTrace);
    }
  }

  /// Get a string value from Remote Config
  /// Returns empty string if not found
  String getString(String key, {String defaultValue = ''}) {
    return _cache[key] ?? defaultValue;
  }

  /// Get onboarding screens directly from Remote Config (not cached)
  /// This ensures we always get the latest onboarding configuration
  Future<String> getOnboardingScreensFresh() async {
    try {
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        _logger.w('Firebase Remote Config not available');
        return '';
      }

      // Fetch and activate to get latest values
      await remoteConfig.fetchAndActivate();
      
      final value = remoteConfig.getString('onboarding_screens');
      _logger.i('Fetched onboarding screens directly from Remote Config');
      return value;
    } catch (e, stackTrace) {
      _logger.e('Error fetching onboarding screens from Remote Config', e, stackTrace);
      return '';
    }
  }

  /// Get a boolean value from Remote Config
  bool getBool(String key, {bool defaultValue = false}) {
    final value = _cache[key];
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true' || value == '1';
  }

  /// Get an integer value from Remote Config
  int getInt(String key, {int defaultValue = 0}) {
    final value = _cache[key];
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Get a double value from Remote Config
  double getDouble(String key, {double defaultValue = 0.0}) {
    final value = _cache[key];
    if (value == null) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }

  /// Check if a key exists in the cache
  bool hasKey(String key) {
    return _cache.containsKey(key) && _cache[key]!.isNotEmpty;
  }

  /// Get all cached keys
  Set<String> getKeys() {
    return _cache.keys.toSet();
  }

  /// Refresh config values from Remote Config
  /// This can be called periodically or when needed
  Future<void> refresh() async {
    try {
      final remoteConfig = FirebaseService.remoteConfig;
      if (remoteConfig == null) {
        _logger.w('Firebase Remote Config not available for refresh');
        return;
      }

      await remoteConfig.fetchAndActivate();
      await _loadConfigValues(remoteConfig);
      _logger.i('Remote Config refreshed');
    } catch (e, stackTrace) {
      _logger.e('Error refreshing Remote Config', e, stackTrace);
    }
  }

  /// Clear all cached config values
  Future<void> clearCache() async {
    try {
      _cache.clear();
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_configCachePrefix)) {
          await _prefs.remove(key);
        }
      }
      _logger.i('Remote Config cache cleared');
    } catch (e, stackTrace) {
      _logger.e('Error clearing Remote Config cache', e, stackTrace);
    }
  }
}

