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
  doneText: UploadProgressScreenConfig._multilocaleFromJson(json['done_text']),
  doneHoldSeconds: (json['done_hold_seconds'] as num?)?.toDouble() ?? 1.4,
  progressGradient: (json['progress_gradient'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$UploadProgressScreenConfigToJson(
  UploadProgressScreenConfig instance,
) => <String, dynamic>{
  'lottie_asset': instance.lottieAsset,
  'texts': instance.texts,
  'text_interval_seconds': instance.textIntervalSeconds,
  'progress_ramp_seconds': instance.progressRampSeconds,
  'done_text': instance.doneText,
  'done_hold_seconds': instance.doneHoldSeconds,
  'progress_gradient': instance.progressGradient,
};
