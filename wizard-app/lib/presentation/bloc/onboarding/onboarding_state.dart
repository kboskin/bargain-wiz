import 'package:appwizard/presentation/bloc/base_bloc.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';

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
  final List<OnboardingModel> screens;
  final Map<int, dynamic> answers;

  const OnboardingConfigLoaded({
    required this.screens,
    this.answers = const {},
  });

  OnboardingConfigLoaded copyWith({
    List<OnboardingModel>? screens,
    Map<int, dynamic>? answers,
  }) {
    return OnboardingConfigLoaded(
      screens: screens ?? this.screens,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object> get props => [screens, answers];
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

