import 'dart:async';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/profile_sync_service.dart';
import 'package:appwizard/core/services/profile_cache.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_override.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RecordingLogger implements AppLogger {
  final errors = <String>[];
  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) => errors.add(message);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUser implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
  @override
  bool get isAnonymous => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuth implements AuthService {
  final controller = StreamController<User?>.broadcast();
  @override
  Stream<User?> get authStateChanges => controller.stream;
  @override
  Stream<User?> get userChanges => controller.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeProfile implements UserProfileService {
  OnboardingDataEntity? entity;
  final listeners = <VoidCallback>[];
  int refreshes = 0;

  /// The answers the configured screens collect, keyed as they are sent.
  @override
  List<ProfileField> get fields => const [
        ProfileField(key: 'vibe', label: 'Vibe', kind: ProfileFieldKind.single),
        ProfileField(key: 'push', label: 'Push', kind: ProfileFieldKind.single),
        ProfileField(key: 'marketplace', label: 'Marketplace', kind: ProfileFieldKind.single),
        ProfileField(key: 'deals_per_month', label: 'Deals', kind: ProfileFieldKind.single),
        ProfileField(key: 'deal_size', label: 'Deal size', kind: ProfileFieldKind.single),
        ProfileField(key: 'hurdles', label: 'Leaks', kind: ProfileFieldKind.multi),
        ProfileField(key: ProfileFields.referralKey, label: 'Code', kind: ProfileFieldKind.text),
      ];

  @override
  OnboardingDataEntity? get data => entity;
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> refresh() async => refreshes++;
  @override
  Map<String, dynamic> get answers =>
      {for (final a in entity?.answers ?? const <OnboardingAnswer>[]) if (a.answerKey != null) a.answerKey!: a.answer};
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRemote implements ProfileRemoteDataSource {
  final patches = <ProfilePatchRequest>[];
  ProfileDocument? stored;
  bool fail = false;
  int attempts = 0;
  int fetches = 0;

  /// Holds every GET until completed, to overlap requests.
  Completer<void>? fetchGate;

  @override
  Future<ProfileDocument> patch(ProfilePatchRequest request) async {
    attempts++;
    if (fail) throw StateError('offline');
    patches.add(request);
    return stored ?? const ProfileDocument();
  }

  @override
  Future<ProfileDocument?> fetch() async {
    fetches++;
    await fetchGate?.future;
    if (fail) throw StateError('offline');
    return stored;
  }

  /// Everything sent besides the launch report [ProfileSyncService.start] makes.
  List<ProfilePatchRequest> get sent => [for (final p in patches) if (p.app?.lastOpenedAt == null) p];
}

class _FakeOnboardingRepo implements OnboardingRepository {
  OnboardingDataEntity? saved;
  @override
  Future<Either<Failure, void>> saveOnboardingData(OnboardingDataEntity data) async {
    saved = data;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

OnboardingAnswer _a(String key, dynamic value, {OnboardingScreenType type = OnboardingScreenType.select, List<String>? options}) =>
    OnboardingAnswer(screenIndex: 0, screenTitle: 'T:$key', screenType: type, answerKey: key, answer: value, options: options);

const _weekly = SubscriptionStatus(
  tier: SubscriptionTier.premium,
  isActive: true,
  productId: 'com.bargain.wiz.premium.weekly',
  plan: 'weekly',
);

/// A store product the config gives no plan id (a status stored before plans were tracked).
const _keyless = SubscriptionStatus(
  tier: SubscriptionTier.premium,
  isActive: true,
  productId: 'com.bargain.wiz.premium.weekly',
);

void main() {
  late _FakeProfile profile;
  late _FakeRemote remote;
  late _FakeAuth auth;
  late _FakeOnboardingRepo onboarding;
  late ProfileCache cache;
  late int overrideChanges;
  late ProfileSyncService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = ProfileCache(await SharedPreferences.getInstance());
    overrideChanges = 0;
    profile = _FakeProfile();
    remote = _FakeRemote();
    auth = _FakeAuth();
    onboarding = _FakeOnboardingRepo();
    service = ProfileSyncService(
      profile: profile,
      remote: remote,
      auth: auth,
      onboarding: onboarding,
      cache: cache,
      onOverrideChanged: () async => overrideChanges++,
      logger: _SilentLogger(),
      debounce: Duration.zero,
      retryDelay: const Duration(days: 1),
      localeCode: () => 'es',
    );
  });

  tearDown(() {
    service.dispose();
    auth.controller.close();
  });

  final entity = OnboardingDataEntity(
    answers: [
      _a('hurdles', ['starting', 'fair_price'], type: OnboardingScreenType.multiSelect, options: ['starting', 'counter_offers', 'fair_price']),
      _a('vibe', 'tactical'),
      _a('push', 80),
      _a('marketplace', 'ebay', type: OnboardingScreenType.selectGroup),
      _a('deals_per_month', '3_5', type: OnboardingScreenType.selectGroup),
      _a('deal_size', 550),
      _a('referral_code', 'FRIEND-42'),
    ],
    isCompleted: true,
  );

  test('buildPatch puts every answer in preferences, the referral code in its own section', () {
    final patch = service.buildPatch(entity, completed: true).toJson();

    // The whole record: no second copy of the answers anywhere in the body.
    expect(patch['preferences'], {
      'hurdles': ['starting', 'fair_price'],
      'vibe': 'tactical', 'push': 80, 'marketplace': 'ebay', 'deals_per_month': '3_5', 'deal_size': 550,
      'locale': 'es',
    });
    expect((patch['preferences'] as Map).containsKey('referral_code'), isFalse);
    expect(patch['onboarding_status'], {'completed': true});
    expect(patch['referral'], {'code': 'FRIEND-42'});
    expect((patch['app'] as Map)['platform'], isNotNull);
    expect((patch['app'] as Map)['locale'], 'es');
  });

  test('an answer whose screen is no longer configured is still recorded', () {
    final patch = service
        .buildPatch(OnboardingDataEntity(answers: [_a('experience_level', 'pro')], isCompleted: false), completed: false)
        .toJson();
    expect(patch['preferences'], {'experience_level': 'pro', 'locale': 'es'});
  });

  test('buildPatch sends only answered fields; an unfinished funnel reports no status', () {
    final patch = service.buildPatch(const OnboardingDataEntity(answers: [], isCompleted: false), completed: false).toJson();
    expect(patch['preferences'], {'locale': 'es'}); // nothing answered yet
    expect(patch.containsKey('onboarding_status'), isFalse);
    expect(patch.containsKey('referral'), isFalse);
  });

  test('an in-flow push records the answers so far, but not the status or the referral code', () async {
    await service.pushOnboarding(entity.copyWith(isCompleted: false));

    final patch = remote.patches.single.toJson();
    expect((patch['preferences'] as Map)['vibe'], 'tactical');
    expect(patch.containsKey('onboarding_status'), isFalse);
    // Write-once on the server: held back while the person can still go back and fix it.
    expect(patch.containsKey('referral'), isFalse);
  });

  test('pushOnboarding sends the completed answers; a failure schedules a retry silently', () async {
    await service.pushOnboarding(entity);
    expect(remote.patches.single.onboardingStatus!.completed, isTrue);
    expect(remote.patches.single.referral!.code, 'FRIEND-42');

    remote.fail = true;
    await service.pushOnboarding(entity); // must not throw
    expect(remote.patches.length, 1);
  });

  group('a failed push', () {
    late _RecordingLogger logger;

    setUp(() {
      logger = _RecordingLogger();
      service.dispose();
      service = ProfileSyncService(
        profile: profile,
        remote: remote,
        auth: auth,
        onboarding: onboarding,
        cache: cache,
        onOverrideChanged: () async => overrideChanges++,
        logger: logger,
        debounce: Duration.zero,
        retryDelay: const Duration(milliseconds: 10),
        localeCode: () => 'es',
      );
    });

    test('is retried once with the same patch, and nothing is reported when the retry lands', () async {
      remote.fail = true;
      await service.pushOnboarding(entity);
      remote.fail = false;
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(remote.patches.single.onboardingStatus!.completed, isTrue);
      expect(logger.errors, isEmpty);
    });

    test('is reported once when the retry fails too, and not retried again', () async {
      remote.fail = true;
      await service.pushOnboarding(entity);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(remote.attempts, 2);
      expect(logger.errors, hasLength(1));
    });

    test('a plan that could not be sent is retried like any other push', () async {
      remote.fail = true;
      await service.reportSubscription(_weekly);
      remote.fail = false;
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(remote.patches.single.subscription!.plan, 'weekly');
      expect(logger.errors, isEmpty);
    });
  });

  group('the pulled profile', () {
    const granted = SubscriptionOverride(tier: SubscriptionTier.premium);

    ProfileDocument carrying(final String tier, {String? until, String uid = 'u1'}) => ProfileDocument(
          identity: ProfileIdentity(uid: uid),
          subscription: ProfileSubscription(
            plan: 'weekly',
            operatorOverride: ProfileSubscriptionOverride(tier: tier, until: until),
          ),
        );

    /// The profile of `u1` with no override in it.
    const plain = ProfileDocument(
      identity: ProfileIdentity(uid: 'u1'),
      subscription: ProfileSubscription(plan: 'weekly'),
    );

    test('is pulled with a GET at launch, beside the launch report, and cached', () async {
      remote.stored = carrying('premium', until: '2026-12-31T00:00:00Z');

      service.start();
      await Future<void>.delayed(Duration.zero);

      expect(remote.fetches, 1);
      expect(remote.patches, hasLength(1)); // the launch report, which does not carry it back
      expect(cache.document!.identity!.uid, 'u1');
      expect(cache.subscriptionOverride, SubscriptionOverride(tier: SubscriptionTier.premium, until: DateTime.utc(2026, 12, 31)));
      expect(overrideChanges, 1);
    });

    test('the cache outlives the session: the next launch has the grant before any pull lands', () async {
      remote.stored = carrying('premium');
      service.start();
      await Future<void>.delayed(Duration.zero);

      final nextLaunch = ProfileCache(await SharedPreferences.getInstance());
      expect(nextLaunch.subscriptionOverride, granted);
    });

    test('a launch that finds no document yet (the very first) caches nothing', () async {
      remote.stored = null;

      service.start();
      await Future<void>.delayed(Duration.zero);

      expect(cache.document, isNull);
      expect(overrideChanges, 0);
    });

    test('a launch and a sign-in that overlap ask the server once', () async {
      remote.stored = carrying('premium');
      remote.fetchGate = Completer<void>();

      service.start();
      final signedIn = service.onSignedIn();
      await Future<void>.delayed(Duration.zero);
      remote.fetchGate!.complete();
      await signedIn;
      await Future<void>.delayed(Duration.zero);

      expect(remote.fetches, 1);
      expect(cache.subscriptionOverride, granted);
      expect(overrideChanges, 1);

      await service.onSignedIn(); // a later sign-in asks again
      expect(remote.fetches, 2);
    });

    test('tells the gate once, not on every launch that finds the same grant', () async {
      remote.stored = carrying('premium');
      service.start();
      await Future<void>.delayed(Duration.zero);
      expect(overrideChanges, 1);

      final next = ProfileSyncService(
        profile: profile,
        remote: remote,
        auth: auth,
        onboarding: onboarding,
        cache: ProfileCache(await SharedPreferences.getInstance()), // a fresh process, same storage
        onOverrideChanged: () async => overrideChanges++,
        logger: _SilentLogger(),
        localeCode: () => 'es',
      )..start();
      await Future<void>.delayed(Duration.zero);
      next.dispose();

      expect(overrideChanges, 1);
    });

    test('a profile without an override takes a cached grant back', () async {
      await cache.save(carrying('premium'));
      remote.stored = plain;

      service.start();
      await Future<void>.delayed(Duration.zero);

      expect(cache.subscriptionOverride, isNull);
      expect(overrideChanges, 1);
    });

    test('a pull that fails leaves the cached profile as it was', () async {
      await cache.save(carrying('premium'));
      remote.fail = true;

      service.start();
      await Future<void>.delayed(Duration.zero);

      expect(remote.fetches, 1);
      expect(cache.subscriptionOverride, granted);
      expect(overrideChanges, 0);
    });

    test('a grant that names no paid tier or cannot be bounded grants nothing', () async {
      remote.stored = carrying('free');
      await service.onSignedIn();
      expect(cache.subscriptionOverride, isNull);

      remote.stored = carrying('premium', until: 'soon');
      await service.onSignedIn();
      expect(cache.subscriptionOverride, isNull);
      expect(overrideChanges, 0);
    });

    test('is pulled again once onboarding has finished, without holding the step up', () async {
      remote.stored = carrying('premium');
      remote.fetchGate = Completer<void>(); // a slow GET must not delay the push's caller

      await service.pushOnboarding(entity);

      expect(remote.patches.single.onboardingStatus!.completed, isTrue);
      expect(remote.fetches, 1);
      expect(cache.subscriptionOverride, isNull); // still in flight

      remote.fetchGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(cache.subscriptionOverride, granted);
      expect(overrideChanges, 1);
    });

    test('a pull after onboarding that fails is fine: onboarding finishes, the cache stays', () async {
      await cache.save(carrying('premium'));
      remote.fetchGate = Completer<void>();

      await service.pushOnboarding(entity); // the push lands and returns without waiting on the GET
      remote.fail = true; // the GET behind it does not make it
      remote.fetchGate!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(cache.subscriptionOverride, granted);
      expect(overrideChanges, 0);
    });

    test('an answered step is not a reason to pull', () async {
      await service.pushOnboarding(entity.copyWith(isCompleted: false));
      expect(remote.fetches, 0);
    });

    test('is read at sign-in too, whether or not the device has answers', () async {
      profile.entity = entity;
      remote.stored = carrying('premium');

      await service.onSignedIn();

      expect(cache.subscriptionOverride, granted);
      expect(overrideChanges, 1);
      expect(onboarding.saved, isNull); // local answers still win
    });

    test('belongs to one account: another uid, or none, drops it at once', () async {
      remote.stored = carrying('premium');
      service.start();
      await Future<void>.delayed(Duration.zero);
      expect(cache.subscriptionOverride, granted);

      auth.controller.add(_FakeUser('u1')); // the same account again: nothing to drop
      await Future<void>.delayed(Duration.zero);
      expect(cache.subscriptionOverride, granted);
      expect(overrideChanges, 1);

      remote.fail = true; // no network to refill it
      auth.controller.add(_FakeUser('u2')); // signed out and back in as someone else
      await Future<void>.delayed(Duration.zero);
      expect(cache.document, isNull);
      expect(cache.subscriptionOverride, isNull);
      expect(overrideChanges, 2);
    });

    test('never rides along on what the device reports', () async {
      remote.stored = carrying('premium');
      await service.reportSubscription(_weekly);

      expect(remote.patches.single.toJson(), {
        'subscription': {'plan': 'weekly', 'product_id': 'com.bargain.wiz.premium.weekly'},
      });
    });
  });

  group('the subscription plan', () {
    test('is reported on its own, with the store product behind it', () async {
      await service.reportSubscription(_weekly);

      expect(remote.patches.single.toJson(), {
        'subscription': {'plan': 'weekly', 'product_id': 'com.bargain.wiz.premium.weekly'},
      });
    });

    test('is left out when the status names no plan, the product still goes', () async {
      await service.reportSubscription(_keyless);

      expect(remote.patches.single.toJson(), {
        'subscription': {'product_id': 'com.bargain.wiz.premium.weekly'},
      });
    });

    test('says nothing when nothing is held: no entitlement, a free one, a lapsed one', () async {
      await service.reportSubscription(null);
      await service.reportSubscription(const SubscriptionStatus(tier: SubscriptionTier.free, isActive: false));
      await service.reportSubscription(_weekly.copyWith(isActive: false));
      await service.reportSubscription(_weekly.copyWith(expiryDate: DateTime(2020)));

      // A device without a plan is not proof the account has none, so nothing is deleted either.
      expect(remote.patches, isEmpty);
    });

    test('is not part of the full pushes: those carry the answers', () async {
      await service.reportSubscription(_weekly);
      await service.pushOnboarding(entity);

      expect(remote.patches.last.toJson().containsKey('subscription'), isFalse);
    });
  });

  test('a scheduled push sends the stored answers (debounced)', () async {
    service.start();
    profile.entity = entity;
    service.schedulePush();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(remote.sent.single.preferences!['vibe'], 'tactical');
  });

  test('start reports the launch once, before onboarding has begun too', () async {
    service
      ..start()
      ..start();
    await Future<void>.delayed(Duration.zero);

    final json = remote.patches.single.toJson();
    expect(json.keys, ['app']); // no answers, no status: only this install and the time
    expect(DateTime.parse((json['app'] as Map)['last_opened_at'] as String).isUtc, isTrue);
  });

  test('pushNow does nothing without local answers', () async {
    await service.pushNow();
    expect(remote.patches, isEmpty);
  });

  test('onSignedIn hydrates an empty device from the account and refreshes the profile', () async {
    remote.stored = const ProfileDocument(
      preferences: {'vibe': 'quiet_closer', 'push': 20, 'locale': 'en'},
      onboardingStatus: ProfileOnboardingStatus(completedAt: '2026-09-17T12:00:00Z'),
    );

    await service.onSignedIn();

    expect(onboarding.saved, isNotNull);
    expect(onboarding.saved!.isCompleted, isTrue);
    // `locale` is a device fact stored beside the answers, not one of them.
    expect(onboarding.saved!.answers.map((a) => a.answerKey), ['vibe', 'push']);
    expect(profile.refreshes, 1);
  });

  test('onSignedIn keeps local answers (they were pushed and win server-side)', () async {
    profile.entity = entity;
    remote.stored = const ProfileDocument(preferences: {'vibe': 'friendly'});

    await service.onSignedIn();

    expect(remote.patches.length, 1); // the merge push
    expect(onboarding.saved, isNull);
  });

  group('the FCM token', () {
    late StreamController<String> tokens;

    setUp(() {
      tokens = StreamController<String>();
      service.dispose();
      service = ProfileSyncService(
        profile: profile,
        remote: remote,
        auth: auth,
        onboarding: onboarding,
        cache: cache,
        onOverrideChanged: () async => overrideChanges++,
        logger: _SilentLogger(),
        debounce: Duration.zero,
        retryDelay: const Duration(days: 1),
        localeCode: () => 'es',
        fcmTokens: () => tokens.stream,
      );
    });

    tearDown(() => tokens.close());

    test('rides on every push once FCM has handed one over', () async {
      service.start();
      expect((service.buildPatch(entity, completed: true).toJson()['app'] as Map).containsKey('fcm_token'), isFalse);

      tokens.add('token-1');
      await Future<void>.delayed(Duration.zero);

      expect((service.buildPatch(entity, completed: true).toJson()['app'] as Map)['fcm_token'], 'token-1');
    });

    test('is reported on its own, and again only when it changes', () async {
      service.start();

      tokens
        ..add('token-1')
        ..add('token-1') // FCM may repeat itself; nothing new to say
        ..add('token-2');
      await Future<void>.delayed(Duration.zero);

      expect(remote.sent.map((final p) => p.toJson()), [
        {'app': {'fcm_token': 'token-1'}},
        {'app': {'fcm_token': 'token-2'}},
      ]);
    });

    test('does not wait for an answer: a fresh install reports it before the first step', () async {
      service.start();
      tokens.add('token-1');
      await Future<void>.delayed(Duration.zero);

      expect(profile.answers, isEmpty);
      expect(remote.sent.single.toJson(), {'app': {'fcm_token': 'token-1'}});
    });
  });
}
