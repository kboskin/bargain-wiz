// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gradient_background_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GradientBackgroundConfig _$GradientBackgroundConfigFromJson(
  Map<String, dynamic> json,
) => GradientBackgroundConfig(
  colors: (json['colors'] as List<dynamic>).map((e) => e as String).toList(),
  stops: (json['stops'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
);

Map<String, dynamic> _$GradientBackgroundConfigToJson(
  GradientBackgroundConfig instance,
) => <String, dynamic>{'colors': instance.colors, 'stops': instance.stops};
