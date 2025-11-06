import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/onboarding_data.dart';
import '../../core/utils/app_logger.dart';

/// Local data source for onboarding data
abstract class OnboardingLocalDataSource {
  Future<void> saveOnboardingData(OnboardingData data);
  Future<OnboardingData?> getOnboardingData();
  Future<void> clearOnboardingData();
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const String _onboardingDataKey = 'onboarding_data';
  final SharedPreferences _prefs;
  final AppLogger _logger;

  OnboardingLocalDataSourceImpl(this._prefs, this._logger);

  @override
  Future<void> saveOnboardingData(OnboardingData data) async {
    try {
      final json = jsonEncode(data.toJson());
      await _prefs.setString(_onboardingDataKey, json);
      _logger.i('Onboarding data saved to local storage');
    } catch (e, stackTrace) {
      _logger.e('Error saving onboarding data', e, stackTrace);
      throw Exception('Failed to save onboarding data: $e');
    }
  }

  @override
  Future<OnboardingData?> getOnboardingData() async {
    try {
      final jsonString = _prefs.getString(_onboardingDataKey);
      if (jsonString == null) return null;
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return OnboardingData.fromJson(json);
    } catch (e, stackTrace) {
      _logger.e('Error loading onboarding data', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> clearOnboardingData() async {
    try {
      await _prefs.remove(_onboardingDataKey);
      _logger.i('Onboarding data cleared');
    } catch (e, stackTrace) {
      _logger.e('Error clearing onboarding data', e, stackTrace);
      throw Exception('Failed to clear onboarding data: $e');
    }
  }
}

