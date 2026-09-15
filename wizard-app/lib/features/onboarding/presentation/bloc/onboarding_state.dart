import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_answer_flattener.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Onboarding states
abstract class OnboardingState extends BaseState {
  const OnboardingState();
}

/// Initial state
class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

/// Loading state
class OnboardingLoading extends OnboardingState {
  const OnboardingLoading();
}

/// Configuration loaded state
class OnboardingConfigLoaded extends OnboardingState {
  const OnboardingConfigLoaded({
    required this.screens,
    this.answers = const {},
  });

  final List<OnboardingModel> screens;

  /// Answers by screen index. Multi-key screens store `{answerKey: value}` maps.
  final Map<int, dynamic> answers;

  /// Answers by `answer_key_name` (multi-key screens flattened).
  Map<String, dynamic> get answersByKey => OnboardingAnswerFlattener.byKey(screens, answers);

  dynamic answerFor(String key) => answersByKey[key];

  OnboardingConfigLoaded copyWith({
    List<OnboardingModel>? screens,
    Map<int, dynamic>? answers,
  }) =>
      OnboardingConfigLoaded(
        screens: screens ?? this.screens,
        answers: answers ?? this.answers,
      );

  @override
  List<Object> get props => [screens, answers];
}

/// Submitting state (keeps the loaded screens so the UI can stay put).
class OnboardingSubmitting extends OnboardingConfigLoaded {
  const OnboardingSubmitting({required super.screens, super.answers});
}

/// Onboarding completed state
class OnboardingCompleted extends OnboardingState {
  const OnboardingCompleted();
}

/// Error state
class OnboardingError extends OnboardingState {
  const OnboardingError(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}
