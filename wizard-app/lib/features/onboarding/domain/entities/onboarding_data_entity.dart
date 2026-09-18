import 'package:equatable/equatable.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';

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
  final OnboardingScreenType screenType;
  final String? answerKey; // Key from answerStructure in screen config
  final dynamic answer;

  /// Option ids the screen offered for this key (select-type and slider screens), so the
  /// answer stays interpretable across experiments. Captured at completion; null when
  /// unknown (e.g. entities rebuilt from local storage).
  final List<String>? options;

  const OnboardingAnswer({
    required this.screenIndex,
    required this.screenTitle,
    required this.screenType,
    this.answerKey,
    required this.answer,
    this.options,
  });

  Map<String, dynamic> toJson() {
    return {
      'screenIndex': screenIndex,
      'screenTitle': screenTitle,
      'screenType': screenType.name,
      'answerKey': answerKey,
      'answer': answer,
      if (options != null) 'options': options,
    };
  }

  factory OnboardingAnswer.fromJson(Map<String, dynamic> json) {
    return OnboardingAnswer(
      screenIndex: json['screenIndex'] as int,
      screenTitle: json['screenTitle'] as String,
      screenType: OnboardingScreenType.fromString(json['screenType'] as String),
      answerKey: json['answerKey'] as String?,
      answer: json['answer'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  @override
  List<Object?> get props => [screenIndex, screenTitle, screenType, answerKey, answer, options];
}

