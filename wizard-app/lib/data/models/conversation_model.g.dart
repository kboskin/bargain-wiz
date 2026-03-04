// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationModel _$ConversationModelFromJson(Map<String, dynamic> json) =>
    ConversationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'express',
      screenshotPaths: (json['screenshots'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      replyOptions: (json['replyOptions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      keyword: json['keyword'] as String?,
      messages: (json['messages'] as List<dynamic>?)
          ?.map(
            (e) =>
                ProDealCloserMessageModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      createdAtMillis: (json['createdAtMillis'] as num).toInt(),
    );

Map<String, dynamic> _$ConversationModelToJson(ConversationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'screenshots': instance.screenshotPaths,
      'replyOptions': instance.replyOptions,
      'keyword': instance.keyword,
      'messages': instance.messages.map((e) => e.toJson()).toList(),
      'createdAtMillis': instance.createdAtMillis,
    };
