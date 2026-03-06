// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingConfig _$OnboardingConfigFromJson(Map<String, dynamic> json) =>
    OnboardingConfig(
      background: json['background'] == null
          ? null
          : GradientBackgroundConfig.fromJson(
              json['background'] as Map<String, dynamic>,
            ),
      textColor: json['text_color'] as String?,
    );

Map<String, dynamic> _$OnboardingConfigToJson(OnboardingConfig instance) =>
    <String, dynamic>{
      'background': instance.background,
      'text_color': instance.textColor,
    };
