// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lines_that_land_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinesThatLandResponse _$LinesThatLandResponseFromJson(
  Map<String, dynamic> json,
) => LinesThatLandResponse(
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => LinesCategoryDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  locales:
      (json['locales'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  updatedAt: LinesThatLandResponse._dateFromJson(json['updated_at']),
  refreshIntervalHours: json['refresh_interval_hours'] == null
      ? LinesThatLandResponse.defaultRefreshIntervalHours
      : LinesThatLandResponse._hoursFromJson(json['refresh_interval_hours']),
  source: json['source'] as String? ?? 'unknown',
);

Map<String, dynamic> _$LinesThatLandResponseToJson(
  LinesThatLandResponse instance,
) => <String, dynamic>{
  'categories': instance.categories.map((e) => e.toJson()).toList(),
  'locales': instance.locales,
  'updated_at': instance.updatedAt?.toIso8601String(),
  'refresh_interval_hours': instance.refreshIntervalHours,
  'source': instance.source,
};

LinesCategoryDto _$LinesCategoryDtoFromJson(Map<String, dynamic> json) =>
    LinesCategoryDto(
      id: json['id'] as String? ?? '',
      name: LinesCategoryDto._textFromJson(json['name']),
      tips: json['tips'] == null
          ? const []
          : LinesCategoryDto._tipsFromJson(json['tips']),
    );

Map<String, dynamic> _$LinesCategoryDtoToJson(LinesCategoryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': LinesCategoryDto._textToJson(instance.name),
      'tips': LinesCategoryDto._tipsToJson(instance.tips),
    };
