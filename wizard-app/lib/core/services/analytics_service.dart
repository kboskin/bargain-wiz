import 'package:appwizard/core/utils/app_logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics service for logging events
/// Provides a centralized, injectable service for analytics tracking
///
/// Collection itself is not switched here: `FirebaseService` turns it off in the SDK for the
/// `local` flavor, and every call below simply logs what it is given.
class AnalyticsService {
  final FirebaseAnalytics _analytics;
  final AppLogger _logger;

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
    try {
      _logger.i('Analytics: $name with params: $parameters');
      await _analytics.logEvent(
        name: name,
        parameters: _wireParameters(parameters),
      );
    } catch (e, stackTrace) {
      _logger.e('Error logging analytics event: $name', e, stackTrace);
    }
  }

  /// Log screen view. [parameters] ride along on the `screen_view` itself — a screen that is
  /// one of several the same class draws (the onboarding steps, drawn by one route) says
  /// which one it is here rather than in a second event beside it.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      _logger.i('Analytics: Screen view - $screenName with params: $parameters');
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
        parameters: _wireParameters(parameters),
      );
    } catch (e, stackTrace) {
      _logger.e('Error logging screen view: $screenName', e, stackTrace);
    }
  }

  /// Parameters as the SDK takes them: String or num, everything else stringified.
  static Map<String, Object>? _wireParameters(Map<String, dynamic>? parameters) {
    if (parameters == null) return null;
    return {
      for (final entry in parameters.entries)
        entry.key: entry.value is String || entry.value is num ? entry.value as Object : entry.value.toString(),
    };
  }

  /// Set user ID for analytics. `AppBootstrap.warmUp` calls this once with the uid the
  /// launch signed in under — the only thing reported about the person, and what joins the
  /// Analytics export to `users/{uid}` and to an A/B arm (PROFILE_SYNC.md). No user
  /// properties are set anywhere.
  Future<void> setUserId(String? userId) async {
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

  // ─── onboarding funnel ─────────────────────────────────────────────────────

  /// The person moved on from a screen: [answerKeys] are the answers it writes, [answers]
  /// what they picked — one parameter per answer key (`vibe: tactical`, a multi-select
  /// comma-joined), so the funnel can be broken down by answer, including the funnels that
  /// never complete (PROFILE_SYNC.md). The caller sends option ids only, never typed text.
  /// A key named like one of the step's own parameters loses to it.
  Future<void> logOnboardingStepAnswered({
    required int index,
    required String stepId,
    required String stepType,
    List<String> answerKeys = const [],
    Map<String, dynamic> answers = const {},
  }) =>
      logEvent(
        name: 'onboarding_step_answered',
        parameters: {
          for (final entry in answers.entries)
            entry.key: entry.value is List ? (entry.value as List).join(',') : entry.value,
          'step_index': index,
          'step_id': stepId,
          'step_type': stepType,
          if (answerKeys.isNotEmpty) 'answer_keys': answerKeys.join(','),
        },
      );

  /// The funnel finished — the moment the profile is pushed and the app opens.
  Future<void> logOnboardingCompleted({required int total, required int answered}) => logEvent(
        name: 'onboarding_completed',
        parameters: {'step_count': total, 'answered_count': answered},
      );

  /// Get the underlying Firebase Analytics instance
  FirebaseAnalytics get analytics => _analytics;
}
