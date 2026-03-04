// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingData _$OnboardingDataFromJson(Map<String, dynamic> json) =>
    OnboardingData(
      isCompleted: json['isCompleted'] as bool? ?? false,
      answers: OnboardingData._answersFromJson(json['answers']),
    );

Map<String, dynamic> _$OnboardingDataToJson(OnboardingData instance) =>
    <String, dynamic>{
      'isCompleted': instance.isCompleted,
      'answers': instance.answers,
    };
