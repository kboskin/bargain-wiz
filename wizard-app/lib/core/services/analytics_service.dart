import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:appwizard/core/utils/app_logger.dart';

/// Analytics service for logging events
/// Provides a centralized, injectable service for analytics tracking
class AnalyticsService {
  final FirebaseAnalytics _analytics;
  final AppLogger _logger;
  bool _isEnabled = true;

  AnalyticsService({
    required AppLogger logger,
    FirebaseAnalytics? analytics,
  })  : _logger = logger,
        _analytics = analytics ?? FirebaseAnalytics.instance;

  /// Log a custom analytics event
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isEnabled) {
      _logger.d('Analytics disabled, skipping event: $name');
      return;
    }

    try {
      _logger.i('Analytics: $name with params: $parameters');
      
      // Convert parameters to the correct type (String or num values only)
      Map<String, Object>? convertedParams;
      if (parameters != null) {
        convertedParams = {};
        for (final entry in parameters.entries) {
          convertedParams[entry.key] = 
              entry.value is String || entry.value is num 
                  ? entry.value 
                  : entry.value.toString();
        }
      }

      await _analytics.logEvent(
        name: name,
        parameters: convertedParams,
      );
    } catch (e, stackTrace) {
      _logger.e('Error logging analytics event: $name', e, stackTrace);
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isEnabled) {
      _logger.d('Analytics disabled, skipping screen view: $screenName');
      return;
    }

    try {
      _logger.i('Analytics: Screen view - $screenName');
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e, stackTrace) {
      _logger.e('Error logging screen view: $screenName', e, stackTrace);
    }
  }

  /// Enable or disable analytics
  Future<void> setEnabled(bool enabled) async {
    try {
      _isEnabled = enabled;
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      _logger.i('Analytics ${enabled ? 'enabled' : 'disabled'}');
    } catch (e, stackTrace) {
      _logger.e('Error setting analytics enabled state', e, stackTrace);
    }
  }

  /// Set user ID for analytics
  Future<void> setUserId(String? userId) async {
    if (!_isEnabled) return;

    try {
      await _analytics.setUserId(id: userId);
      _logger.i('Analytics user ID set: $userId');
    } catch (e, stackTrace) {
      _logger.e('Error setting user ID', e, stackTrace);
    }
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_isEnabled) return;

    try {
      await _analytics.setUserProperty(
        name: name,
        value: value,
      );
      _logger.i('Analytics user property set: $name = $value');
    } catch (e, stackTrace) {
      _logger.e('Error setting user property: $name', e, stackTrace);
    }
  }

  /// Log purchase event
  Future<void> logPurchase({
    required String transactionId,
    required String currency,
    required double value,
    String? itemId,
    Map<String, dynamic>? additionalParams,
  }) async {
    if (!_isEnabled) return;

    try {
      final params = {
        'transaction_id': transactionId,
        'currency': currency,
        'value': value,
        if (itemId != null) 'item_id': itemId,
        ...?additionalParams,
      };

      await logEvent(name: 'purchase', parameters: params);
    } catch (e, stackTrace) {
      _logger.e('Error logging purchase', e, stackTrace);
    }
  }

  /// Log paywall impression
  Future<void> logPaywallImpression({
    required String paywallType,
    Map<String, dynamic>? additionalParams,
  }) async {
    await logEvent(
      name: 'paywall_impression',
      parameters: {
        'paywall_type': paywallType,
        ...?additionalParams,
      },
    );
  }

  /// Log paywall CTA tap
  Future<void> logPaywallCtaTap({
    required String paywallType,
    required String tier,
    Map<String, dynamic>? additionalParams,
  }) async {
    await logEvent(
      name: 'paywall_cta_tap',
      parameters: {
        'paywall_type': paywallType,
        'tier': tier,
        ...?additionalParams,
      },
    );
  }

  /// Log paywall option selected
  Future<void> logPaywallOptionSelected({
    required String paywallType,
    required String optionId,
    required String tier,
    Map<String, dynamic>? additionalParams,
  }) async {
    await logEvent(
      name: 'paywall_option_selected',
      parameters: {
        'paywall_type': paywallType,
        'option_id': optionId,
        'tier': tier,
        ...?additionalParams,
      },
    );
  }

  /// Get the underlying Firebase Analytics instance
  FirebaseAnalytics get analytics => _analytics;

  /// Check if analytics is enabled
  bool get isEnabled => _isEnabled;
}
