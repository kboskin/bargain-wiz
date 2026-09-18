import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../config/app_config.dart';
import 'package:appwizard/core/services/firebase_options.dart';

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
  /// Note: AppLogger is not available here as it depends on Crashlytics
  /// Use debugPrint directly for initialization logging
  static Future<void> initialize() async {
    try {
      debugPrint('[INFO] Initializing Firebase...');

      // Initialize Firebase Core
      await Firebase.initializeApp(
        options: _getFirebaseOptions(),
      );
      debugPrint('[INFO] Firebase Core initialized');

      if (AppConfig.isLocal) await _useEmulators();

      // Initialize Analytics
      _analytics = FirebaseAnalytics.instance;
      debugPrint('[INFO] Firebase Analytics initialized');

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
      debugPrint('[INFO] Firebase Crashlytics initialized');

      // Initialize Messaging
      _messaging = FirebaseMessaging.instance;
      debugPrint('[INFO] Firebase Messaging initialized');

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
      
      // Default values will be set by RemoteConfigService from asset file
      // fetchAndActivate() will be called by RemoteConfigService.initialize()
      debugPrint('[INFO] Firebase Remote Config instance created');

      debugPrint('[INFO] Firebase initialization complete');
    } catch (e, stackTrace) {
      // Note: AppLogger might not be available yet, so log directly to Crashlytics if available
      _crashlytics?.recordError(e, stackTrace, fatal: false);
      debugPrint('[ERROR] Error initializing Firebase: $e');
      rethrow;
    }
  }

  /// Request notification permission
  /// This triggers the native Android/iOS permission dialog
  /// Returns the NotificationSettings with authorization status
  static Future<NotificationSettings?> requestNotificationPermission() async {
    try {
      if (_messaging == null) {
        debugPrint('[WARN] Firebase Messaging not initialized');
        return null;
      }

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[INFO] Notification permission result: ${settings.authorizationStatus}');
      return settings;
    } catch (e, stackTrace) {
      _crashlytics?.recordError(e, stackTrace, fatal: false);
      debugPrint('[ERROR] Error requesting notification permission: $e');
      return null;
    }
  }

  /// Local flavor: Auth, Firestore and Storage talk to `firebase emulators:start`
  /// (wizard-backend/firebase.json ports). Must run before any of them is used. Remote Config
  /// has no emulator and keeps reading the dev project; the Functions emulator URL replaces
  /// `api_url` in [RemoteConfigService.getApiUrl]. Crash and analytics reporting is off.
  static Future<void> _useEmulators() async {
    final host = AppConfig.emulatorHost;
    if (defaultTargetPlatform == TargetPlatform.android && appFlavor != 'local' && !kDebugMode) {
      // Debug builds allow plain HTTP through src/debug/res/xml/network_security_config.xml;
      // release and profile builds only do so in the `local` Gradle flavor.
      debugPrint('[ERROR] FLAVOR=local in a non-debug build needs the Android `local` flavor '
          '(built with "${appFlavor ?? 'none'}"): cleartext HTTP to $host will be rejected.');
    }
    await FirebaseAuth.instance.useAuthEmulator(host, AppConfig.emulatorAuthPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, AppConfig.emulatorFirestorePort);
    await FirebaseStorage.instance.useStorageEmulator(host, AppConfig.emulatorStoragePort);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    debugPrint('[INFO] Local flavor: Firebase emulators at $host '
        '(auth ${AppConfig.emulatorAuthPort}, firestore ${AppConfig.emulatorFirestorePort}, '
        'storage ${AppConfig.emulatorStoragePort}, functions ${AppConfig.emulatorFunctionsPort})');
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

