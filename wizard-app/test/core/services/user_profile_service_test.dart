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
  final List<OnboardingModel> screens = <OnboardingModel>[
    OnboardingModel.fromJson({
      'type': 'select',
      'title': {'en': 'Who negotiates for you?'},
      'answer_structure': {'answer_key_name': 'vibe'},
      'options': [
        {
          'label': {'en': 'Friendly'},
          'value': 'friendly',
          'metadata': {'prompt': 'warm and polite, still anchors low.'},
        },
        {
          'label': {'en': 'Tactical'},
          'value': 'tactical',
          'metadata': {'prompt': 'uses comparables as leverage.'},
        },
      ],
    }),
    OnboardingModel.fromJson({
      'type': 'select',
      'title': {'en': 'Shoe size?'},
      'answer_structure': {'answer_key_name': 'shoe_size'},
      'options': [
        // No `prompt`: an option that describes nothing contributes no sentence.
        {'label': {'en': '44'}, 'value': '44'},
      ],
    }),
  ];

  /// A multi-select and a slider stop, so the note resolution is exercised on every carrier
  /// of `prompt`. Opt-in: the tests above assert exact payloads.
  void describeMoreScreens() => screens.addAll([
        OnboardingModel.fromJson({
          'type': 'multi_select',
          'title': {'en': 'Where has your money slipped away?'},
          'answer_structure': {'answer_key_name': 'hurdles', 'multi': true},
          'options': [
            {'label': {'en': 'Opening'}, 'value': 'starting', 'metadata': {'prompt': 'hesitates to open.'}},
            {'label': {'en': 'Fair price'}, 'value': 'fair_price', 'metadata': {'prompt': 'cannot judge a price.'}},
          ],
        }),
        OnboardingModel.fromJson({
          'type': 'slider_lottie',
          'title': {'en': 'How hard do you push?'},
          'answer_structure': {'answer_key_name': 'push'},
          'metadata': {
            'default_value': 60,
            'options': [
              {'value': 60, 'label': {'en': 'Balanced'}, 'prompt': 'a fair anchor, ready to walk away.'},
              {'value': 100, 'label': {'en': 'Hard'}, 'prompt': 'the lowest credible price or no deal.'},
            ],
          },
        }),
      ]);

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
      answers: [_answer('vibe', 'tactical'), _answer('shoe_size', 44)],
      isCompleted: true,
    );

    await service.ensureLoaded();

    expect(service.answers, {'vibe': 'tactical', 'shoe_size': 44});
    expect(service.answer('shoe_size'), 44);
    expect(service.answer('nope'), isNull);
    expect(service.answerKeys, ['vibe', 'shoe_size']);
    expect(service.isOnboardingCompleted, isTrue);
  });

  test('an unanswered screen falls back to its configured default', () async {
    await service.ensureLoaded();

    expect(service.answer('vibe'), isNull);
    expect(service.valueOf('vibe'), 'friendly'); // the screen's first option
    expect(service.valueOf('nope'), isNull);
    expect(service.optionFor('vibe')?.value, 'friendly');
  });

  test('payload carries every configured answer, with overrides and exceptions', () async {
    repository.stored = OnboardingDataEntity(
      answers: [_answer('vibe', 'tactical'), _answer('shoe_size', 44)],
      isCompleted: true,
    );

    await service.ensureLoaded();

    expect(service.payload(), {'vibe': 'tactical', 'shoe_size': 44});
    expect(
      service.payload(overrides: const {'vibe': 'friendly'}),
      {'vibe': 'friendly', 'shoe_size': 44},
    );
    expect(service.payload(except: const {'shoe_size'}), {'vibe': 'tactical'});
  });

  group('snapshot: the answers and what they mean to the model', () {
    setUp(() => remoteConfig.describeMoreScreens());

    test('carries one sentence per described answer, keyed the way the answers are', () async {
      repository.stored = OnboardingDataEntity(
        answers: [
          _answer('vibe', 'tactical'),
          _answer('shoe_size', 44),
          _answer('hurdles', ['fair_price', 'starting']),
        ],
        isCompleted: true,
      );

      await service.ensureLoaded();
      final snapshot = service.snapshot();

      expect(snapshot.fields, {
        'vibe': 'tactical',
        'shoe_size': 44,
        'hurdles': ['fair_price', 'starting'],
        'push': 60, // the slider's configured default
      });
      // One entry per pick, in screen order, each carrying its own sentence. `shoe_size` is
      // answered but describes nothing: the answer travels, with no sentence on it.
      expect(
        [for (final a in snapshot.answers) (a.key, a.value, a.prompt)],
        [
          ('vibe', 'tactical', 'uses comparables as leverage.'),
          ('shoe_size', 44, null),
          ('hurdles', 'fair_price', 'cannot judge a price.'),
          ('hurdles', 'starting', 'hesitates to open.'),
          ('push', 60, 'a fair anchor, ready to walk away.'),
        ],
      );
    });

    test('an override describes the option actually being sent', () async {
      repository.stored = OnboardingDataEntity(
        answers: [_answer('vibe', 'tactical')],
        isCompleted: true,
      );

      await service.ensureLoaded();
      final snapshot = service.snapshot(overrides: const {'vibe': 'friendly'});

      expect(snapshot.fields['vibe'], 'friendly');
      final vibe = snapshot.answers.firstWhere((a) => a.key == 'vibe');
      expect((vibe.value, vibe.prompt), ('friendly', 'warm and polite, still anchors low.'));
    });

    test('an answer the config no longer offers contributes no sentence', () async {
      repository.stored = OnboardingDataEntity(
        answers: [_answer('vibe', 'retired_tone')],
        isCompleted: true,
      );

      await service.ensureLoaded();
      final snapshot = service.snapshot();

      expect(snapshot.fields['vibe'], 'retired_tone');
      expect(snapshot.answers.firstWhere((a) => a.key == 'vibe').prompt, isNull);
    });

    test('except drops the field and its sentence together', () async {
      repository.stored = OnboardingDataEntity(
        answers: [_answer('vibe', 'tactical')],
        isCompleted: true,
      );

      await service.ensureLoaded();
      final snapshot = service.snapshot(except: const {'vibe'});

      expect(snapshot.fields.containsKey('vibe'), isFalse);
      expect(snapshot.answers.any((a) => a.key == 'vibe'), isFalse);
    });

    test('payload is the fields half of the same resolution', () async {
      await service.ensureLoaded();
      expect(service.payload(), service.snapshot().fields);
    });
  });

  test('a write stores locally first, then asks for a push, and keeps the screen trace', () async {
    var notified = 0;
    service.addListener(() => notified++);

    await service.setAnswer('vibe', 'tactical');

    final saved = repository.stored!.answers.single;
    expect(saved.answerKey, 'vibe');
    expect(saved.answer, 'tactical');
    expect(saved.screenIndex, 0);
    expect(saved.screenTitle, 'Who negotiates for you?');
    expect(saved.options, ['friendly', 'tactical']); // what the screen offered
    expect(pushes, 1);
    expect(notified, greaterThan(0));
  });

  test('a failed save changes nothing and sends nothing', () async {
    repository.fail = true;

    await service.setAnswer('vibe', 'tactical');

    expect(service.answers, isEmpty);
    expect(pushes, 0);
  });

  test('replacing an answer keeps one entry per key, and a batch travels once', () async {
    await service.setAnswer('vibe', 'friendly');
    await service.setAnswers({'vibe': 'tactical', 'shoe_size': 44});

    expect(service.answers, {'vibe': 'tactical', 'shoe_size': 44});
    expect(repository.stored!.answers.length, 2);
    expect(repository.saves, 2);
    expect(pushes, 2);
  });
}
