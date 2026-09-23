import 'dart:async';

import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/subscription/subscription_checker_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Where the person is in the funnel, as the FCM topic push campaigns target. An install is
/// subscribed to exactly one.
enum PushPhase {
  /// From the first launch until onboarding is finished.
  onboarding('onboarding_phase'),

  /// Onboarding finished, nothing bought.
  subscription('subscription_phase'),

  /// Holds a paid entitlement — bought here, or restored from the store.
  premium('premium_phase');

  const PushPhase(this.topic);

  final String topic;
}

/// Keeps this install subscribed to the topic of its current [PushPhase] and to no other.
///
/// The phase is derived, never stored: a paid tier wins, then finished onboarding, else
/// onboarding. [sync] applies it — subscribe to the current topic first, then unsubscribe
/// from the rest — so it is idempotent, and a switch that failed (offline, or iOS before
/// APNs has registered) is simply redone by the next one. It runs:
/// - on every FCM token ([start]): once per launch, and again on rotation, because topic
///   subscriptions belong to the token;
/// - when onboarding finishes (`OnboardingBloc`);
/// - when the stored entitlement changes (`SubscriptionRepositoryImpl`).
///
/// Syncs are queued, so two in flight cannot interleave their calls and leave the install
/// in no topic. Failures are logged, never thrown.
class PushTopicService {
  PushTopicService({
    required final OnboardingRepository onboarding,
    required final SubscriptionCheckerService subscription,
    required final AppLogger logger,
    final Stream<String> Function()? fcmTokens,
    final Future<void> Function(String topic)? subscribe,
    final Future<void> Function(String topic)? unsubscribe,
  })  : _onboarding = onboarding,
        _subscription = subscription,
        _logger = logger,
        _fcmTokens = fcmTokens ?? FirebaseService.fcmTokens,
        _subscribe = subscribe ?? ((final topic) async => FirebaseService.messaging?.subscribeToTopic(topic)),
        _unsubscribe = unsubscribe ?? ((final topic) async => FirebaseService.messaging?.unsubscribeFromTopic(topic));

  final OnboardingRepository _onboarding;
  final SubscriptionCheckerService _subscription;
  final AppLogger _logger;
  final Stream<String> Function() _fcmTokens;
  final Future<void> Function(String topic) _subscribe;
  final Future<void> Function(String topic) _unsubscribe;

  StreamSubscription<String>? _tokens;
  Future<void> _queue = Future<void>.value();

  /// The phase the current token is known to be subscribed to; null until a sync succeeds.
  PushPhase? _applied;

  /// Called once per launch, after sign-in. The first sync waits for a token: before one
  /// exists, iOS rejects topic calls outright.
  void start() {
    _tokens ??= _fcmTokens().listen(
      (_) => unawaited(sync(force: true)),
      onError: (final Object e) => _logger.w('FCM token unavailable: $e'),
    );
  }

  void dispose() {
    _tokens?.cancel();
  }

  /// Moves this install to the topic of its current phase. Skipped when the token is
  /// already there, unless [force]d (a new token starts with no topics).
  Future<void> sync({final bool force = false}) => _queue = _queue.then((_) => _apply(force: force));

  Future<void> _apply({required final bool force}) async {
    PushPhase? phase;
    try {
      phase = await currentPhase();
      if (!force && phase == _applied) return;
      _applied = null;
      await _subscribe(phase.topic);
      for (final other in PushPhase.values) {
        if (other != phase) await _unsubscribe(other.topic);
      }
      _applied = phase;
      _logger.i('Push topic: ${phase.topic}');
    } on Object catch (e) {
      _logger.w('Push topic ${phase?.topic} not applied: $e');
    }
  }

  Future<PushPhase> currentPhase() async {
    if (await _subscription.getCurrentTier() != SubscriptionTier.free) return PushPhase.premium;
    final completed = await _onboarding.isOnboardingCompleted();
    return completed.fold((_) => false, (final done) => done) ? PushPhase.subscription : PushPhase.onboarding;
  }
}
