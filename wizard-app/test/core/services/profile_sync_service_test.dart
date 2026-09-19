import 'dart:async';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/profile_sync_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentLogger implements AppLogger {
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
        ProfileField(key: ProfileFields.vibeKey, label: 'Vibe', kind: ProfileFieldKind.single),
        ProfileField(key: ProfileFields.pushKey, label: 'Push', kind: ProfileFieldKind.single),
        ProfileField(key: ProfileFields.marketplaceKey, label: 'Marketplace', kind: ProfileFieldKind.single),
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

  @override
  Future<ProfileDocument> patch(ProfilePatchRequest request) async {
    if (fail) throw StateError('offline');
    patches.add(request);
    return stored ?? const ProfileDocument();
  }

  @override
  Future<ProfileDocument?> fetch() async => stored;
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

void main() {
  late _FakeProfile profile;
  late _FakeRemote remote;
  late _FakeAuth auth;
  late _FakeOnboardingRepo onboarding;
  late ProfileSyncService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    profile = _FakeProfile();
    remote = _FakeRemote();
    auth = _FakeAuth();
    onboarding = _FakeOnboardingRepo();
    service = ProfileSyncService(
      profile: profile,
      remote: remote,
      auth: auth,
      onboarding: onboarding,
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
    expect((patch['app'] as Map)['flavor'], isNotNull);
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

  test('pushOnboarding sends the completed answers; a failure schedules a retry silently', () async {
    await service.pushOnboarding(entity);
    expect(remote.patches.single.onboardingStatus!.completed, isTrue);

    remote.fail = true;
    await service.pushOnboarding(entity); // must not throw
    expect(remote.patches.length, 1);
  });

  test('a scheduled push sends the stored answers (debounced)', () async {
    service.start();
    profile.entity = entity;
    service.schedulePush();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(remote.patches.length, 1);
    expect(remote.patches.single.preferences!['vibe'], 'tactical');
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

}
