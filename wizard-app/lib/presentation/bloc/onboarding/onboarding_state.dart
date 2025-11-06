import '../base_bloc.dart';
import '../../../data/models/onboarding_screen_config.dart';

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
  final OnboardingConfig config;
  final Map<int, dynamic> answers;

  const OnboardingConfigLoaded({
    required this.config,
    this.answers = const {},
  });

  OnboardingConfigLoaded copyWith({
    OnboardingConfig? config,
    Map<int, dynamic>? answers,
  }) {
    return OnboardingConfigLoaded(
      config: config ?? this.config,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object> get props => [config, answers];
}

/// Submitting state
class OnboardingSubmitting extends OnboardingState {
  const OnboardingSubmitting();
}

/// Onboarding completed state
class OnboardingCompleted extends OnboardingState {
  const OnboardingCompleted();
}

/// Error state
class OnboardingError extends OnboardingState {
  final String message;

  const OnboardingError(this.message);

  @override
  List<Object> get props => [message];
}

