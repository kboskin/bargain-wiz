// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'button_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ButtonConfig _$ButtonConfigFromJson(Map<String, dynamic> json) => ButtonConfig(
  text: ButtonConfig._textFromJson(json['text']),
  action: ButtonConfig._actionFromJson(json['action'] as String?),
  buttonColor: json['button_color'] as String?,
  glowColor: json['glow_color'] as String?,
  glowIntensity: (json['glow_intensity'] as num?)?.toDouble(),
  glowPulse: json['glow_pulse'] as bool?,
  buttonStyle: json['button_style'] == null
      ? ButtonVisualStyle.glow
      : ButtonConfig._buttonStyleFromJson(json['button_style'] as String?),
);

Map<String, dynamic> _$ButtonConfigToJson(ButtonConfig instance) =>
    <String, dynamic>{
      'text': instance.text,
      'action': ButtonConfig._actionToJson(instance.action),
      'button_color': instance.buttonColor,
      'glow_color': instance.glowColor,
      'glow_intensity': instance.glowIntensity,
      'glow_pulse': instance.glowPulse,
      'button_style': ButtonConfig._buttonStyleToJson(instance.buttonStyle),
    };
