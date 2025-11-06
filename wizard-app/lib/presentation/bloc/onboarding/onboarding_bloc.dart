import 'package:flutter_bloc/flutter_bloc.dart';
import '../base_bloc.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';
import '../../../domain/repositories/onboarding_repository.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/onboarding_data_entity.dart';

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
      final config = await _onboardingService.getOnboardingConfig();
      emit(OnboardingConfigLoaded(
        config: config,
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

    emit(const OnboardingSubmitting());
    
    final currentState = state as OnboardingConfigLoaded;
    
    // Convert answers to entity
    final answers = currentState.answers.entries.map((entry) {
      final screenIndex = entry.key;
      if (screenIndex >= currentState.config.screens.length) {
        _logger.w('Screen index $screenIndex out of bounds, skipping');
        return null;
      }
      final screen = currentState.config.screens[screenIndex];
      return OnboardingAnswer(
        screenIndex: screenIndex,
        screenTitle: screen.title,
        screenType: screen.type.name,
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

