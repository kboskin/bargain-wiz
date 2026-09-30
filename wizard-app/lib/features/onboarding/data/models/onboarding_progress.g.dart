// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingProgress _$OnboardingProgressFromJson(Map<String, dynamic> json) =>
    OnboardingProgress(
      stepId: json['step_id'] as String,
      stepIndex: (json['step_index'] as num).toInt(),
      answers: json['answers'] as Map<String, dynamic>? ?? {},
    );

Map<String, dynamic> _$OnboardingProgressToJson(OnboardingProgress instance) =>
    <String, dynamic>{
      'step_id': instance.stepId,
      'step_index': instance.stepIndex,
      'answers': instance.answers,
    };
