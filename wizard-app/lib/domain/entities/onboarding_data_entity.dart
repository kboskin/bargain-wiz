import 'package:equatable/equatable.dart';

/// Domain entity for onboarding data
/// This represents the business logic layer entity
class OnboardingDataEntity extends Equatable {
  final List<OnboardingAnswer> answers;
  final bool isCompleted;

  const OnboardingDataEntity({
    required this.answers,
    this.isCompleted = false,
  });

  OnboardingDataEntity copyWith({
    List<OnboardingAnswer>? answers,
    bool? isCompleted,
  }) {
    return OnboardingDataEntity(
      answers: answers ?? this.answers,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object> get props => [answers, isCompleted];
}

/// Represents a single onboarding answer
class OnboardingAnswer extends Equatable {
  final int screenIndex;
  final String screenTitle;
  final String screenType;
  final String? answerKey; // Key from answerStructure in screen config
  final dynamic answer;

  const OnboardingAnswer({
    required this.screenIndex,
    required this.screenTitle,
    required this.screenType,
    this.answerKey,
    required this.answer,
  });

  Map<String, dynamic> toJson() {
    return {
      'screenIndex': screenIndex,
      'screenTitle': screenTitle,
      'screenType': screenType,
      'answerKey': answerKey,
      'answer': answer,
    };
  }

  factory OnboardingAnswer.fromJson(Map<String, dynamic> json) {
    return OnboardingAnswer(
      screenIndex: json['screenIndex'] as int,
      screenTitle: json['screenTitle'] as String,
      screenType: json['screenType'] as String,
      answerKey: json['answerKey'] as String?,
      answer: json['answer'],
    );
  }

  @override
  List<Object?> get props => [screenIndex, screenTitle, screenType, answerKey, answer];
}

