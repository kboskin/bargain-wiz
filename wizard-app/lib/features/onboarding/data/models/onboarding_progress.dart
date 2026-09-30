import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_progress.g.dart';

/// Where an unfinished onboarding stopped: the step the person was on and everything they had
/// answered, by answer key. Kept in SharedPreferences (`PrefsKeys.onboardingProgress`) by
/// `OnboardingProgressStore`; local only — the profile already gets the answers step by step.
///
/// The step is found again by [stepId] (`OnboardingModel.stepId`), not by position, so a
/// template reordered in the meantime still lands on the same question; [stepIndex] only
/// breaks a tie between screens that share an id.
@JsonSerializable()
class OnboardingProgress {
  const OnboardingProgress({
    required this.stepId,
    required this.stepIndex,
    this.answers = const {},
  });

  factory OnboardingProgress.fromJson(final Map<String, dynamic> json) => _$OnboardingProgressFromJson(json);

  @JsonKey(name: 'step_id')
  final String stepId;

  @JsonKey(name: 'step_index')
  final int stepIndex;

  /// Answers by `answer_key_name` (a `select_group`'s keys flattened).
  @JsonKey(defaultValue: <String, dynamic>{})
  final Map<String, dynamic> answers;

  Map<String, dynamic> toJson() => _$OnboardingProgressToJson(this);

  /// Index of the saved step in [screens]: the saved position when that screen is still the
  /// same step, otherwise the first screen with the step's id; null when the step is gone.
  int? indexIn(final List<OnboardingModel> screens) {
    if (stepIndex >= 0 && stepIndex < screens.length && screens[stepIndex].stepId == stepId) {
      return stepIndex;
    }
    final index = screens.indexWhere((final s) => s.stepId == stepId);
    return index < 0 ? null : index;
  }
}
