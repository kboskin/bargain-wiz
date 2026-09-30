import 'dart:convert';
import 'dart:io';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/datasources/onboarding_progress_store.dart';
import 'package:appwizard/features/onboarding/data/models/onboarding_progress.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<OnboardingModel> _defaultScreens() {
  final root = jsonDecode(File('assets/config/remote_config_defaults.json').readAsStringSync()) as Map<String, dynamic>;
  final list = jsonDecode(root['onboarding_screens'] as String) as List;
  return list.map((e) => OnboardingModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}

class _FakeOnboardingService implements OnboardingService {
  _FakeOnboardingService(this.screens);

  List<OnboardingModel> screens;

  @override
  Future<List<OnboardingModel>> getOnboardingConfig() async => screens;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepository implements OnboardingRepository {
  OnboardingDataEntity? saved;

  @override
  Future<Either<Failure, void>> saveOnboardingData(OnboardingDataEntity data) async {
    saved = data;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final screens = _defaultScreens(); // hurdles, vibe, push, select_group, deal_size, warmup, …
  late SharedPreferences prefs;
  late OnboardingProgressStore store;
  late _FakeOnboardingService service;
  late _FakeRepository repository;

  Future<void> start({Map<String, Object> saved = const {}}) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
    store = OnboardingProgressStore(prefs, AppLogger(null));
  }

  OnboardingBloc newBloc() => OnboardingBloc(
        repository: repository,
        onboardingService: service,
        logger: AppLogger(null),
        preferences: prefs,
        progressStore: store,
      );

  Future<OnboardingConfigLoaded> load(OnboardingBloc bloc) async {
    bloc.add(const LoadOnboardingConfigRequested());
    return await bloc.stream.firstWhere((s) => s is OnboardingConfigLoaded) as OnboardingConfigLoaded;
  }

  Map<String, Object> savedProgress(OnboardingProgress p) => {PrefsKeys.onboardingProgress: jsonEncode(p.toJson())};

  setUp(() {
    service = _FakeOnboardingService(screens);
    repository = _FakeRepository();
  });

  group('OnboardingProgress.indexIn', () {
    test('finds the step at its saved position, or by id when the template moved it', () {
      expect(const OnboardingProgress(stepId: 'push', stepIndex: 2).indexIn(screens), 2);
      expect(const OnboardingProgress(stepId: 'push', stepIndex: 7).indexIn(screens), 2);
      expect(const OnboardingProgress(stepId: 'push', stepIndex: 99).indexIn(screens), 2);
      expect(const OnboardingProgress(stepId: 'gone', stepIndex: 2).indexIn(screens), isNull);
    });

    test('the saved position picks between screens that share an id', () {
      final twoWarmups = [...screens.take(6), screens[5], ...screens.skip(6)]; // warmup at 5 and 6
      expect(twoWarmups[5].stepId, twoWarmups[6].stepId);
      expect(const OnboardingProgress(stepId: 'warmup', stepIndex: 6).indexIn(twoWarmups), 6);
      expect(const OnboardingProgress(stepId: 'warmup', stepIndex: 9).indexIn(twoWarmups), 5);
    });
  });

  group('OnboardingProgressStore', () {
    test('round-trips, clears, and reads unreadable JSON as no progress', () async {
      await start();
      expect(store.read(), isNull);

      await store.write(const OnboardingProgress(stepId: 'vibe', stepIndex: 1, answers: {'hurdles': ['starting']}));
      final read = store.read()!;
      expect(read.stepId, 'vibe');
      expect(read.stepIndex, 1);
      expect(read.answers, {'hurdles': ['starting']});

      await store.clear();
      expect(prefs.containsKey(PrefsKeys.onboardingProgress), isFalse);

      await prefs.setString(PrefsKeys.onboardingProgress, '{not json');
      expect(store.read(), isNull);
      await prefs.setString(PrefsKeys.onboardingProgress, '{"step_index": 3}');
      expect(store.read(), isNull);
    });
  });

  group('OnboardingBloc resume', () {
    test('with nothing saved, starts on the first screen with no answers', () async {
      await start();
      final bloc = newBloc();
      final loaded = await load(bloc);
      expect(loaded.startIndex, 0);
      expect(loaded.answers, isEmpty);
      await bloc.close();
    });

    test('reopens on the saved step with the answers back on their screens', () async {
      await start(
        saved: savedProgress(const OnboardingProgress(stepId: 'deal_size', stepIndex: 4, answers: {
          'hurdles': ['starting', 'fair_price'],
          'vibe': 'tactical',
          'push': 60,
          'marketplace': 'ebay',
          'deals_per_month': '3_5',
        })),
      );
      final bloc = newBloc();
      final loaded = await load(bloc);
      expect(loaded.startIndex, 4);
      expect(loaded.answers, {
        0: ['starting', 'fair_price'],
        1: 'tactical',
        2: 60,
        3: {'marketplace': 'ebay', 'deals_per_month': '3_5'},
      });
      await bloc.close();
    });

    test('follows the step when the template has moved it', () async {
      await start(
        saved: savedProgress(const OnboardingProgress(stepId: 'vibe', stepIndex: 1, answers: {'hurdles': ['starting']})),
      );
      service.screens = [screens[2], screens[0], screens[1], ...screens.skip(3)]; // push, hurdles, vibe, …
      final bloc = newBloc();
      final loaded = await load(bloc);
      expect(loaded.startIndex, 2);
      expect(loaded.answers, {1: ['starting']});
      await bloc.close();
    });

    test('starts over, and forgets the progress, when the saved step is no longer configured', () async {
      await start(
        saved: savedProgress(const OnboardingProgress(stepId: 'retired_question', stepIndex: 3, answers: {'vibe': 'tactical'})),
      );
      final bloc = newBloc();
      final loaded = await load(bloc);
      expect(loaded.startIndex, 0);
      expect(loaded.answers, isEmpty);
      expect(store.read(), isNull);
      await bloc.close();
    });

    test('saves the step and the answers as the flow moves, and clears them on completion', () async {
      await start();
      final bloc = newBloc();
      await load(bloc);

      bloc
        ..add(const OnboardingAnswerChanged(screenIndex: 0, answer: ['being_rude']))
        ..add(const OnboardingAnswerChanged(screenIndex: 3, answer: {'marketplace': 'olx'}))
        ..add(const OnboardingStepChanged(1));
      await pumpEventQueue();
      final saved = store.read()!;
      expect(saved.stepId, 'vibe');
      expect(saved.stepIndex, 1);
      expect(saved.answers, {'hurdles': ['being_rude'], 'marketplace': 'olx'});

      bloc.add(const SubmitOnboardingRequested());
      await bloc.stream.firstWhere((s) => s is OnboardingCompleted);
      expect(repository.saved!.isCompleted, isTrue);
      expect(store.read(), isNull);
      await bloc.close();
    });

    test('ignores a step outside the screen list', () async {
      await start();
      final bloc = newBloc();
      await load(bloc);
      bloc.add(OnboardingStepChanged(screens.length));
      await pumpEventQueue();
      expect(store.read(), isNull);
      await bloc.close();
    });
  });
}
