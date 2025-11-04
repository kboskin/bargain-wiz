import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'firebase_options.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// Firebase service for initializing and managing Firebase services
class FirebaseService {
  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;
  static FirebaseMessaging? _messaging;
  static FirebaseRemoteConfig? _remoteConfig;

  /// Get Firebase Analytics instance
  static FirebaseAnalytics? get analytics => _analytics;

  /// Get Firebase Crashlytics instance
  static FirebaseCrashlytics? get crashlytics => _crashlytics;

  /// Get Firebase Messaging instance
  static FirebaseMessaging? get messaging => _messaging;

  /// Get Firebase Remote Config instance
  static FirebaseRemoteConfig? get remoteConfig => _remoteConfig;

  /// Initialize Firebase services
  static Future<void> initialize() async {
    try {
      AppLogger.i('Initializing Firebase...');

      // Initialize Firebase Core
      await Firebase.initializeApp(
        options: _getFirebaseOptions(),
      );
      AppLogger.i('Firebase Core initialized');

      // Initialize Analytics
      _analytics = FirebaseAnalytics.instance;
      AppLogger.i('Firebase Analytics initialized');

      // Initialize Crashlytics
      _crashlytics = FirebaseCrashlytics.instance;
      
      // Set up error handling
      FlutterError.onError = (errorDetails) {
        _crashlytics?.recordFlutterFatalError(errorDetails);
      };
      
      // Pass uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };
      AppLogger.i('Firebase Crashlytics initialized');

      // Initialize Messaging
      _messaging = FirebaseMessaging.instance;
      
      // Request notification permissions
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.i('Firebase Messaging permission: ${settings.authorizationStatus}');

      // Initialize Remote Config
      _remoteConfig = FirebaseRemoteConfig.instance;
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: AppConfig.isDev
              ? const Duration(minutes: 1) // Dev: fetch every minute
              : const Duration(hours: 1), // Prod: fetch every hour
        ),
      );
      
      // Set default values
      await _remoteConfig!.setDefaults({
        'api_url': AppConfig.baseUrl,
        'feature_enabled': false,
      });
      
      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();
      AppLogger.i('Firebase Remote Config initialized');

      AppLogger.i('Firebase initialization complete');
    } catch (e, stackTrace) {
      AppLogger.e('Error initializing Firebase', e, stackTrace);
      _crashlytics?.recordError(e, stackTrace, fatal: false);
      rethrow;
    }
  }

  /// Get Firebase options based on flavor
  static FirebaseOptions _getFirebaseOptions() {
    // Currently using dev configuration
    // TODO: When prod Firebase project is available, add flavor-specific options
    // For now, both dev and prod use the dev Firebase project
    // In production, you can check AppConfig.isDev and return different options
    return DefaultFirebaseOptions.currentPlatform;
  }
}

