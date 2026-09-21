// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$CreateConversationRequestToJson(
  CreateConversationRequest instance,
) => <String, dynamic>{
  'type': instance.type,
  'text': ?instance.text,
  'images': ?instance.images?.map((e) => e.toJson()).toList(),
  'keyword': ?instance.keyword,
  'overrides': instance.overrides,
};

Map<String, dynamic> _$SendMessageRequestToJson(SendMessageRequest instance) =>
    <String, dynamic>{
      'text': ?instance.text,
      'images': ?instance.images?.map((e) => e.toJson()).toList(),
      'overrides': instance.overrides,
    };

Map<String, dynamic> _$ConversationActionRequestToJson(
  ConversationActionRequest instance,
) => <String, dynamic>{
  'message_id': ?instance.messageId,
  'keyword': ?instance.keyword,
  'overrides': instance.overrides,
};

Map<String, dynamic> _$ConversationPatchRequestToJson(
  ConversationPatchRequest instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'status': ?instance.status,
  'price_before': ?instance.priceBefore,
  'price_after': ?instance.priceAfter,
  'overrides': ?instance.overrides,
};

ConversationWriteResponse _$ConversationWriteResponseFromJson(
  Map<String, dynamic> json,
) => ConversationWriteResponse(
  conversationId: json['conversation_id'] as String,
  messageId: json['message_id'] as String?,
  replyId: json['reply_id'] as String?,
);
