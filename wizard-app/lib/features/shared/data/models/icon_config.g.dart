// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'icon_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IconConfig _$IconConfigFromJson(Map<String, dynamic> json) => IconConfig(
      iconData: IconConfig._iconDataFromJson(json['iconData'] as Map<String, dynamic>?),
      isFontAwesome: json['isFontAwesome'] as bool? ?? false,
    );

Map<String, dynamic> _$IconConfigToJson(IconConfig instance) =>
    <String, dynamic>{
      'iconData': IconConfig._iconDataToJson(instance.iconData),
      'isFontAwesome': instance.isFontAwesome,
    };
