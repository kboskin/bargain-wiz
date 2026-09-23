import 'dart:async';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/services/push_topic_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_answer_flattener.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding BLoC: loads the remote screen list, collects answers per screen
/// and persists them (flattened by answer key) when the flow completes.
class OnboardingBloc extends BaseBloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required OnboardingRepository repository,
    required OnboardingService onboardingService,
    required AppLogger logger,
    SharedPreferences? preferences,
    UserProfileService? profileService,
    PushTopicService? pushTopics,
  })  : _repository = repository,
        _onboardingService = onboardingService,
        _logger = logger,
        _preferences = preferences,
        _profileService = profileService,
        _pushTopics = pushTopics,
        super(const OnboardingInitial()) {
    on<LoadOnboardingConfigRequested>(_onLoadOnboardingConfig);
    on<OnboardingAnswerChanged>(_onAnswerChanged);
    on<SubmitOnboardingRequested>(_onSubmitOnboarding);
  }

  final OnboardingRepository _repository;
  final OnboardingService _onboardingService;
  final AppLogger _logger;
  final SharedPreferences? _preferences;
  final UserProfileService? _profileService;
  final PushTopicService? _pushTopics;

  Future<void> _onLoadOnboardingConfig(
    LoadOnboardingConfigRequested event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());
    try {
      // Paywall screens are retired from the default order but stay supported:
      // the shell opens PaywallLauncher when the flow reaches one.
      final screens = await _onboardingService.getOnboardingConfig();
      _logger.i(
        'Onboarding screens loaded: ${screens.length} (types: ${screens.map((s) => s.type.name).join(", ")})',
      );
      if (screens.isNotEmpty && screens.last.type != OnboardingScreenType.dataUpload) {
        _logger.w(
          'Last onboarding screen is ${screens.last.type.name}, not data_upload; '
          'the flow will submit from the CTA of the last screen instead.',
        );
      }
      emit(OnboardingConfigLoaded(screens: screens));
    } on Object catch (e, stackTrace) {
      _logger.e('Error loading onboarding config', e, stackTrace);
      emit(OnboardingError('Failed to load onboarding configuration: $e'));
    }
  }

  void _onAnswerChanged(
    OnboardingAnswerChanged event,
    Emitter<OnboardingState> emit,
  ) {
    final current = state;
    if (current is! OnboardingConfigLoaded) return;
    final updated = Map<int, dynamic>.from(current.answers);
    if (event.answer == null) {
      updated.remove(event.screenIndex);
    } else {
      updated[event.screenIndex] = event.answer;
    }
    emit(OnboardingConfigLoaded(screens: current.screens, answers: updated));
  }

  Future<void> _onSubmitOnboarding(
    SubmitOnboardingRequested event,
    Emitter<OnboardingState> emit,
  ) async {
    final current = state;
    if (current is! OnboardingConfigLoaded) {
      emit(const OnboardingError('Cannot submit: configuration not loaded'));
      return;
    }
    if (current is OnboardingSubmitting) return;

    emit(OnboardingSubmitting(screens: current.screens, answers: current.answers));

    final entity = buildEntity(current);

    try {
      final result = await _repository.saveOnboardingData(entity);
      await result.fold(
        (failure) async {
          _logger.e('Failed to save onboarding data', failure, StackTrace.current);
          emit(OnboardingError('Failed to save onboarding data: ${failure.message}'));
        },
        (_) async {
          await _markFirstRun();
          await _profileService?.refresh();
          unawaited(_pushTopics?.sync()); // onboarding_phase → subscription_phase
          emit(const OnboardingCompleted());
        },
      );
    } on Object catch (e, stackTrace) {
      _logger.e('Unexpected error saving onboarding data', e, stackTrace);
      emit(OnboardingError('Failed to save onboarding data: $e'));
    }
  }

  Future<void> _markFirstRun() async {
    try {
      await _preferences?.setBool(PrefsKeys.firstRunNudgePending, true);
    } on Object catch (e) {
      _logger.w('OnboardingBloc: could not set first-run nudge flag: $e');
    }
  }

  /// Flattens the in-flow answers into the entity persisted at the end (also
  /// used by the flow to build the profile pushes; [completed] is false for the ones sent
  /// as each step is left).
  static OnboardingDataEntity buildEntity(OnboardingConfigLoaded state, {bool completed = true}) =>
      OnboardingDataEntity(
        answers: OnboardingAnswerFlattener.flatten(state.screens, state.answers),
        isCompleted: completed,
      );
}
