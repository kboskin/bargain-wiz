// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_progress_screen_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadProgressScreenConfig _$UploadProgressScreenConfigFromJson(
  Map<String, dynamic> json,
) => UploadProgressScreenConfig(
  lottieAsset: json['lottie_asset'] as String,
  texts: UploadProgressScreenConfig._textsFromJson(json['texts']),
  textIntervalSeconds:
      (json['text_interval_seconds'] as num?)?.toDouble() ?? 2.5,
  progressRampSeconds:
      (json['progress_ramp_seconds'] as num?)?.toDouble() ?? 5.0,
);

Map<String, dynamic> _$UploadProgressScreenConfigToJson(
  UploadProgressScreenConfig instance,
) => <String, dynamic>{
  'lottie_asset': instance.lottieAsset,
  'texts': instance.texts,
  'text_interval_seconds': instance.textIntervalSeconds,
  'progress_ramp_seconds': instance.progressRampSeconds,
};
