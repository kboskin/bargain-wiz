/// Model for storing onboarding user data
/// Answers are stored abstractly based on answerKey from screen configuration
class OnboardingData {
  OnboardingData({
    this.isCompleted = false,
    required this.answers,
  });

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      isCompleted: json['isCompleted'] as bool? ?? false,
      answers: (json['answers'] as Map<String, dynamic>?) ?? {},
    );
  }

  final bool isCompleted;
  final Map<String, dynamic> answers; // Key-value pairs: answerKey -> answer value

  OnboardingData copyWith({
    bool? isCompleted,
    Map<String, dynamic>? answers,
  }) {
    return OnboardingData(
      isCompleted: isCompleted ?? this.isCompleted,
      answers: answers ?? this.answers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isCompleted': isCompleted,
      'answers': answers,
    };
  }
}

