import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appwizard/presentation/bloc/base_bloc.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';
import 'package:appwizard/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/domain/entities/onboarding_data_entity.dart';

/// Onboarding BLoC
class OnboardingBloc extends BaseBloc<OnboardingEvent, OnboardingState> {
  final OnboardingRepository _repository;
  final OnboardingService _onboardingService;
  final AppLogger _logger;

  OnboardingBloc({
    required OnboardingRepository repository,
    required OnboardingService onboardingService,
    required AppLogger logger,
  })  : _repository = repository,
        _onboardingService = onboardingService,
        _logger = logger,
        super(const OnboardingInitial()) {
    on<LoadOnboardingConfigRequested>(_onLoadOnboardingConfig);
    on<OnboardingAnswerChanged>(_onAnswerChanged);
    on<SubmitOnboardingRequested>(_onSubmitOnboarding);
    on<NavigateToNextScreen>(_onNavigateToNext);
    on<NavigateToPreviousScreen>(_onNavigateToPrevious);
  }

  Future<void> _onLoadOnboardingConfig(
    LoadOnboardingConfigRequested event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());
    try {
      final allScreens = await _onboardingService.getOnboardingConfig();
      final screens = allScreens
          .where((s) => s.type != OnboardingScreenType.paywall)
          .toList();
      _logger.i(
        'Onboarding screens loaded: ${screens.length} (types: ${screens.map((s) => s.type.name).join(", ")})',
      );
      if (screens.isNotEmpty &&
          screens.last.type != OnboardingScreenType.dataUpload) {
        _logger.w(
          'Last screen is ${screens.last.type.name}, not data_upload. '
          'Upload screen will not appear. Ensure onboarding_screens in Remote Config includes a data_upload entry.',
        );
      }
      emit(OnboardingConfigLoaded(
        screens: screens,
        answers: {},
      ));
    } catch (e, stackTrace) {
      _logger.e('Error loading onboarding config', e, stackTrace);
      emit(OnboardingError('Failed to load onboarding configuration: $e'));
    }
  }

  void _onAnswerChanged(
    OnboardingAnswerChanged event,
    Emitter<OnboardingState> emit,
  ) {
    if (state is OnboardingConfigLoaded) {
      final currentState = state as OnboardingConfigLoaded;
      final updatedAnswers = Map<int, dynamic>.from(currentState.answers);
      updatedAnswers[event.screenIndex] = event.answer;

      emit(currentState.copyWith(answers: updatedAnswers));
    }
  }

  Future<void> _onSubmitOnboarding(
    SubmitOnboardingRequested event,
    Emitter<OnboardingState> emit,
  ) async {
    if (state is! OnboardingConfigLoaded) {
      emit(const OnboardingError('Cannot submit: configuration not loaded'));
      return;
    }

    // Capture state before emitting new state
    final currentState = state as OnboardingConfigLoaded;

    emit(const OnboardingSubmitting());
    
    // Convert answers to entity
    final answers = currentState.answers.entries.map((entry) {
      final screenIndex = entry.key;
      if (screenIndex >= currentState.screens.length) {
        _logger.w('Screen index $screenIndex out of bounds, skipping');
        return null;
      }
      final screen = currentState.screens[screenIndex];
      
      // Handle title that might be a Map (multilocale) at runtime
      String title = 'Onboarding';
      try {
        final dynamic rawTitle = screen.title;
        if (rawTitle is Map) {
          title = rawTitle['en']?.toString() ?? rawTitle.values.first?.toString() ?? 'Onboarding';
        } else {
          title = rawTitle?.toString() ?? 'Onboarding';
        }
      } catch (e) {
        _logger.w('Error parsing screen title: $e');
      }

      return OnboardingAnswer(
        screenIndex: screenIndex,
        screenTitle: title,
        screenType: screen.type,
        answerKey: screen.answerStructure?.answerKeyName,
        answer: entry.value,
      );
    }).whereType<OnboardingAnswer>().toList();

    final entity = OnboardingDataEntity(
      answers: answers,
      isCompleted: true,
    );

    try {
      final result = await _repository.saveOnboardingData(entity);
      
      result.fold(
        (failure) {
          _logger.e('Failed to save onboarding data', failure, StackTrace.current);
          emit(OnboardingError('Failed to save onboarding data: ${failure.message}'));
        },
        (_) => emit(const OnboardingCompleted()),
      );
    } catch (e, stackTrace) {
      _logger.e('Unexpected error saving onboarding data', e, stackTrace);
      emit(OnboardingError('Failed to save onboarding data: $e'));
    }
  }

  void _onNavigateToNext(
    NavigateToNextScreen event,
    Emitter<OnboardingState> emit,
  ) {
    // Navigation is handled by PageController, this is just a placeholder
    // The actual screen index is tracked by the PageView
  }

  void _onNavigateToPrevious(
    NavigateToPreviousScreen event,
    Emitter<OnboardingState> emit,
  ) {
    // Navigation is handled by PageController, this is just a placeholder
    // The actual screen index is tracked by the PageView
  }
}

