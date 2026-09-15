import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Onboarding events
abstract class OnboardingEvent extends BaseEvent {
  const OnboardingEvent();
}

/// Load onboarding configuration
class LoadOnboardingConfigRequested extends OnboardingEvent {
  const LoadOnboardingConfigRequested();
}

/// Answer changed for a screen.
///
/// [answer] is the screen's value: a scalar / list for single-key screens, or a
/// `Map<String, dynamic>` of `{answerKey: value}` for multi-key screens
/// (`select_group`). `null` clears the answer.
class OnboardingAnswerChanged extends OnboardingEvent {
  const OnboardingAnswerChanged({
    required this.screenIndex,
    required this.answer,
  });

  final int screenIndex;
  final dynamic answer;

  @override
  List<Object?> get props => [screenIndex, answer];
}

/// Submit onboarding answers (called when the data_upload screen finishes).
class SubmitOnboardingRequested extends OnboardingEvent {
  const SubmitOnboardingRequested();
}
