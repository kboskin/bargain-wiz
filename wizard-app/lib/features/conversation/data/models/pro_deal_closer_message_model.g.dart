// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_deal_closer_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProDealCloserMessageModel _$ProDealCloserMessageModelFromJson(
  Map<String, dynamic> json,
) => ProDealCloserMessageModel(
  text: json['text'] as String? ?? '',
  attachmentPaths: (json['attachmentPaths'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ProDealCloserMessageModelToJson(
  ProDealCloserMessageModel instance,
) => <String, dynamic>{
  'text': instance.text,
  'attachmentPaths': instance.attachmentPaths,
};
