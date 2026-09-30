import 'dart:convert';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/onboarding_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves where an unfinished onboarding stopped ([OnboardingProgress]) so the flow can reopen
/// there. Best effort both ways: a write that fails costs the resume, never the flow, and a
/// value that cannot be read is treated as no progress.
class OnboardingProgressStore {
  OnboardingProgressStore(this._prefs, this._logger);

  final SharedPreferences _prefs;
  final AppLogger _logger;

  OnboardingProgress? read() {
    final raw = _prefs.getString(PrefsKeys.onboardingProgress);
    if (raw == null) return null;
    try {
      return OnboardingProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (e) {
      _logger.w('OnboardingProgressStore: ignoring unreadable progress: $e');
      return null;
    }
  }

  Future<void> write(final OnboardingProgress progress) async {
    try {
      await _prefs.setString(PrefsKeys.onboardingProgress, jsonEncode(progress.toJson()));
    } on Object catch (e) {
      _logger.w('OnboardingProgressStore: could not save progress: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(PrefsKeys.onboardingProgress);
    } on Object catch (e) {
      _logger.w('OnboardingProgressStore: could not clear progress: $e');
    }
  }
}
