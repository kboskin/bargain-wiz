import 'package:flutter/foundation.dart';

/// Simple logger utility
class AppLogger {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  static void i(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      debugPrint('[WARNING] $message');
    }
  }
}

