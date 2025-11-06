import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Logger utility that logs errors to Crashlytics
/// Provided through dependency injection
class AppLogger {
  final FirebaseCrashlytics? _crashlytics;

  AppLogger(this._crashlytics);

  void d(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }

    // Log to Crashlytics as non-fatal error
    final crashlytics = _crashlytics;
    if (crashlytics != null && error != null) {
      try {
        final errorMessage = '$message: ${error.toString()}';
        crashlytics.recordError(
          error,
          stackTrace ?? StackTrace.current,
          reason: errorMessage,
          fatal: false,
        );
      } catch (e) {
        // Silently fail if Crashlytics logging fails
        debugPrint('Failed to log to Crashlytics: $e');
      }
    }
  }

  void i(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  void w(String message) {
    if (kDebugMode) {
      debugPrint('[WARNING] $message');
    }
  }
}

