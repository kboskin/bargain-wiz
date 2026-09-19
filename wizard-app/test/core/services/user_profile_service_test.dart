import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Two screens, as remote config sends them: the answer key is the field name, and the tone
/// screen's first option is its default.
class _FakeRemoteConfig implements RemoteConfigService {
  final List<OnboardingModel> screens = [
    OnboardingModel.fromJson({
      'type': 'select',
      'title': {'en': 'Who negotiates for you?'},
      'answer_structure': {'answer_key_name': ProfileFields.vibeKey},
      'options': [
        {'label': {'en': 'Friendly'}, 'value': 'friendly'},
        {'label': {'en': 'Tactical'}, 'value': 'tactical'},
      ],
    }),
    OnboardingModel.fromJson({
      'type': 'select',
      'title': {'en': 'Shoe size?'},
      'answer_structure': {'answer_key_name': 'shoe_size'},
      'options': [
        {'label': {'en': '44'}, 'value': '44'},
      ],
    }),
  ];

  @override
  List<OnboardingModel> getOnboardingScreens() => screens;

  @override
  List<ProfileField> getProfileFields() => ProfileFields.fromScreens(screens);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRepository implements OnboardingRepository {
  OnboardingDataEntity? stored;
  int saves = 0;
  bool fail = false;

  @override
  Future<Either<Failure, OnboardingDataEntity?>> getOnboardingData() async => Right(stored);

  @override
  Future<Either<Failure, void>> saveOnboardingData(OnboardingDataEntity data) async {
    saves++;
    if (fail) return const Left(CacheFailure('disk full'));
    stored = data;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

OnboardingAnswer _answer(String key, dynamic value) => OnboardingAnswer(
      screenIndex: 0,
      screenTitle: 'T:$key',
      screenType: OnboardingScreenType.select,
      answerKey: key,
      answer: value,
    );

void main() {
  late _FakeRepository repository;
  late _FakeRemoteConfig remoteConfig;
  late UserProfileService service;
  late int pushes;

  setUp(() {
    repository = _FakeRepository();
    remoteConfig = _FakeRemoteConfig();
    pushes = 0;
    service = UserProfileService(
      repository,
      remoteConfig,
      _SilentLogger(),
      pushToBackend: () => pushes++,
    );
  });

  test('reads the stored answers by key', () async {
    repository.stored = OnboardingDataEntity(
      answers: [_answer(ProfileFields.vibeKey, 'tactical'), _answer('shoe_size', 44)],
      isCompleted: true,
    );

    await service.ensureLoaded();

    expect(service.answers, {ProfileFields.vibeKey: 'tactical', 'shoe_size': 44});
    expect(service.answer('shoe_size'), 44);
    expect(service.answer('nope'), isNull);
    expect(service.answerKeys, [ProfileFields.vibeKey, 'shoe_size']);
    expect(service.isOnboardingCompleted, isTrue);
  });

  test('an unanswered screen falls back to its configured default', () async {
    await service.ensureLoaded();

    expect(service.answer(ProfileFields.vibeKey), isNull);
    expect(service.valueOf(ProfileFields.vibeKey), 'friendly'); // the screen's first option
    expect(service.valueOf('nope'), isNull);
    expect(service.optionFor(ProfileFields.vibeKey)?.value, 'friendly');
  });

  test('payload carries every configured answer, with overrides and exceptions', () async {
    repository.stored = OnboardingDataEntity(
      answers: [_answer(ProfileFields.vibeKey, 'tactical'), _answer('shoe_size', 44)],
      isCompleted: true,
    );

    await service.ensureLoaded();

    expect(service.payload(), {ProfileFields.vibeKey: 'tactical', 'shoe_size': 44});
    expect(
      service.payload(overrides: const {ProfileFields.vibeKey: 'friendly'}),
      {ProfileFields.vibeKey: 'friendly', 'shoe_size': 44},
    );
    expect(service.payload(except: const {'shoe_size'}), {ProfileFields.vibeKey: 'tactical'});
  });

  test('a write stores locally first, then asks for a push, and keeps the screen trace', () async {
    var notified = 0;
    service.addListener(() => notified++);

    await service.setAnswer(ProfileFields.vibeKey, 'tactical');

    final saved = repository.stored!.answers.single;
    expect(saved.answerKey, ProfileFields.vibeKey);
    expect(saved.answer, 'tactical');
    expect(saved.screenIndex, 0);
    expect(saved.screenTitle, 'Who negotiates for you?');
    expect(saved.options, ['friendly', 'tactical']); // what the screen offered
    expect(pushes, 1);
    expect(notified, greaterThan(0));
  });

  test('a failed save changes nothing and sends nothing', () async {
    repository.fail = true;

    await service.setAnswer(ProfileFields.vibeKey, 'tactical');

    expect(service.answers, isEmpty);
    expect(pushes, 0);
  });

  test('replacing an answer keeps one entry per key, and a batch travels once', () async {
    await service.setAnswer(ProfileFields.vibeKey, 'friendly');
    await service.setAnswers({ProfileFields.vibeKey: 'tactical', 'shoe_size': 44});

    expect(service.answers, {ProfileFields.vibeKey: 'tactical', 'shoe_size': 44});
    expect(repository.stored!.answers.length, 2);
    expect(repository.saves, 2);
    expect(pushes, 2);
  });
}
