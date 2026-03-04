import 'package:json_annotation/json_annotation.dart';

part 'onboarding_data.g.dart';

/// Data Transfer Object (DTO) for local storage of onboarding data
/// Used by OnboardingLocalDataSource for SharedPreferences persistence
/// Answers are stored abstractly based on answerKey from screen configuration
@JsonSerializable()
class OnboardingData {
  OnboardingData({
    this.isCompleted = false,
    required this.answers,
  });

  @JsonKey(defaultValue: false)
  final bool isCompleted;

  /// Key-value pairs: answerKey -> answer value
  @JsonKey(fromJson: _answersFromJson)
  final Map<String, dynamic> answers;

  factory OnboardingData.fromJson(Map<String, dynamic> json) =>
      _$OnboardingDataFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingDataToJson(this);

  static Map<String, dynamic> _answersFromJson(dynamic json) =>
      (json as Map<String, dynamic>?) ?? {};

  OnboardingData copyWith({
    bool? isCompleted,
    Map<String, dynamic>? answers,
  }) {
    return OnboardingData(
      isCompleted: isCompleted ?? this.isCompleted,
      answers: answers ?? this.answers,
    );
  }
}
