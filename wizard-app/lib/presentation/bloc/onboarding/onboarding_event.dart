import '../base_bloc.dart';

/// Onboarding events
abstract class OnboardingEvent extends BaseEvent {
  const OnboardingEvent();
}

/// Load onboarding configuration
class LoadOnboardingConfigRequested extends OnboardingEvent {
  const LoadOnboardingConfigRequested();
}

/// Answer changed for a screen
class OnboardingAnswerChanged extends OnboardingEvent {
  final int screenIndex;
  final String screenTitle;
  final String screenType;
  final String? answerKey; // Key from answerStructure in screen config
  final dynamic answer;

  const OnboardingAnswerChanged({
    required this.screenIndex,
    required this.screenTitle,
    required this.screenType,
    this.answerKey,
    required this.answer,
  });

  @override
  List<Object?> get props => [screenIndex, screenTitle, screenType, answerKey, answer];
}

/// Submit onboarding answers
class SubmitOnboardingRequested extends OnboardingEvent {
  const SubmitOnboardingRequested();
}

/// Navigate to next screen
class NavigateToNextScreen extends OnboardingEvent {
  const NavigateToNextScreen();
}

/// Navigate to previous screen
class NavigateToPreviousScreen extends OnboardingEvent {
  const NavigateToPreviousScreen();
}

