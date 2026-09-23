import 'dart:async';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/push_topic_service.dart';
import 'package:appwizard/core/services/subscription/subscription_checker_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(final Invocation invocation) => null;
}

class _FakeOnboarding implements OnboardingRepository {
  bool completed = false;
  @override
  Future<Either<Failure, bool>> isOnboardingCompleted() async => Right(completed);
  @override
  dynamic noSuchMethod(final Invocation invocation) => null;
}

class _FakeChecker implements SubscriptionCheckerService {
  SubscriptionTier tier = SubscriptionTier.free;
  @override
  Future<SubscriptionTier> getCurrentTier() async => tier;
  @override
  dynamic noSuchMethod(final Invocation invocation) => null;
}

void main() {
  late _FakeOnboarding onboarding;
  late _FakeChecker checker;
  late StreamController<String> tokens;
  late List<String> calls;
  late Set<String> topics;
  String? failOn;
  Completer<void>? gate; // holds the next subscribe call until completed

  PushTopicService service() => PushTopicService(
        onboarding: onboarding,
        subscription: checker,
        logger: _SilentLogger(),
        fcmTokens: () => tokens.stream,
        subscribe: (final topic) async {
          final held = gate;
          gate = null;
          if (held != null) await held.future;
          if (failOn == topic) throw StateError('offline');
          calls.add('+$topic');
          topics.add(topic);
        },
        unsubscribe: (final topic) async {
          calls.add('-$topic');
          topics.remove(topic);
        },
      );

  setUp(() {
    onboarding = _FakeOnboarding();
    checker = _FakeChecker();
    tokens = StreamController<String>.broadcast(); // closes even when never listened to
    calls = [];
    topics = {};
    failOn = null;
    gate = null;
  });

  tearDown(() => tokens.close());

  test('a fresh install joins onboarding_phase as soon as FCM has a token', () async {
    service().start();
    await pumpEventQueue();
    expect(calls, isEmpty, reason: 'nothing before a token: iOS rejects topic calls without one');

    tokens.add('t1');
    await pumpEventQueue();
    expect(calls, ['+onboarding_phase', '-subscription_phase', '-premium_phase']);
  });

  test('finishing onboarding moves to subscription_phase', () async {
    final s = service();
    await s.sync();
    onboarding.completed = true;
    await s.sync();
    expect(topics, {'subscription_phase'});
  });

  test('a purchase moves to premium_phase, even mid-onboarding', () async {
    final s = service();
    await s.sync();
    checker.tier = SubscriptionTier.premium;
    await s.sync();
    expect(topics, {'premium_phase'});
    onboarding.completed = true; // finishing onboarding after the paywall does not demote
    await s.sync();
    expect(topics, {'premium_phase'});
  });

  test('an unchanged phase makes no calls; a new token re-applies it', () async {
    final s = service()..start();
    await s.sync();
    await s.sync();
    expect(calls, hasLength(3));

    tokens.add('rotated');
    await pumpEventQueue();
    expect(calls, hasLength(6));
  });

  test('a failed switch is redone by the next sync', () async {
    final s = service();
    failOn = 'onboarding_phase';
    await s.sync();
    expect(topics, isEmpty);

    failOn = null;
    await s.sync();
    expect(topics, {'onboarding_phase'});
  });

  test('overlapping syncs do not interleave', () async {
    final s = service();
    final release = Completer<void>();
    gate = release;
    final first = s.sync();
    await pumpEventQueue(); // first has read its phase and is waiting on FCM
    onboarding.completed = true;
    final second = s.sync();
    await pumpEventQueue();
    release.complete();
    await Future.wait([first, second]);
    expect(topics, {'subscription_phase'});
  });
}
