// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_screen_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingScreenConfig _$OnboardingScreenConfigFromJson(
  Map<String, dynamic> json,
) => OnboardingScreenConfig(
  title: OnboardingScreenConfig._multilocaleFromJson(json['title']),
  description: OnboardingScreenConfig._multilocaleFromJson(json['description']),
  type: OnboardingScreenConfig._typeFromJson(json['type'] as String),
  visual: json['visual'] as String?,
  options: (json['options'] as List<dynamic>?)
      ?.map(
        (e) => OnboardingScreenConfigOption.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructureConfig.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  nextButtonText: OnboardingScreenConfig._multilocaleFromJson(
    json['next_button_text'],
  ),
);

Map<String, dynamic> _$OnboardingScreenConfigToJson(
  OnboardingScreenConfig instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'type': OnboardingScreenConfig._typeToJson(instance.type),
  'visual': instance.visual,
  'options': instance.options,
  'metadata': instance.metadata,
  'answer_structure': instance.answerStructure,
  'next_button_text': instance.nextButtonText,
};

OnboardingScreenConfigOption _$OnboardingScreenConfigOptionFromJson(
  Map<String, dynamic> json,
) => OnboardingScreenConfigOption(
  label: OnboardingScreenConfigOption._multilocaleFromJson(json['label']),
  value: json['value'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$OnboardingScreenConfigOptionToJson(
  OnboardingScreenConfigOption instance,
) => <String, dynamic>{
  'label': instance.label,
  'value': instance.value,
  'metadata': instance.metadata,
};

AnswerStructureConfig _$AnswerStructureConfigFromJson(
  Map<String, dynamic> json,
) => AnswerStructureConfig(answerKeyName: json['answer_key_name'] as String);

Map<String, dynamic> _$AnswerStructureConfigToJson(
  AnswerStructureConfig instance,
) => <String, dynamic>{'answer_key_name': instance.answerKeyName};

OnboardingConfig _$OnboardingConfigFromJson(Map<String, dynamic> json) =>
    OnboardingConfig(
      screens: (json['screens'] as List<dynamic>)
          .map(
            (e) => OnboardingScreenConfig.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$OnboardingConfigToJson(OnboardingConfig instance) =>
    <String, dynamic>{'screens': instance.screens};
