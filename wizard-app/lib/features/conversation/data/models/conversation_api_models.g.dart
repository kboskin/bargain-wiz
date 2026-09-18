// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationProfile _$ConversationProfileFromJson(Map<String, dynamic> json) =>
    ConversationProfile(
      vibe: json['vibe'] as String,
      push: (json['push'] as num).toInt(),
      locale: json['locale'] as String,
      marketplace: json['marketplace'] as String?,
      dealSize: json['deal_size'] as num?,
      dealsPerMonth: json['deals_per_month'] as String?,
      hurdles: (json['hurdles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ConversationProfileToJson(
  ConversationProfile instance,
) => <String, dynamic>{
  'vibe': instance.vibe,
  'push': instance.push,
  'locale': instance.locale,
  'marketplace': ?instance.marketplace,
  'deal_size': ?instance.dealSize,
  'deals_per_month': ?instance.dealsPerMonth,
  'hurdles': ?instance.hurdles,
};

Map<String, dynamic> _$CreateConversationRequestToJson(
  CreateConversationRequest instance,
) => <String, dynamic>{
  'type': instance.type,
  'request_id': instance.requestId,
  'text': ?instance.text,
  'images': ?instance.images?.map((e) => e.toJson()).toList(),
  'keyword': ?instance.keyword,
};

Map<String, dynamic> _$SendMessageRequestToJson(SendMessageRequest instance) =>
    <String, dynamic>{
      'request_id': instance.requestId,
      'text': ?instance.text,
      'images': ?instance.images?.map((e) => e.toJson()).toList(),
    };

Map<String, dynamic> _$ConversationActionRequestToJson(
  ConversationActionRequest instance,
) => <String, dynamic>{
  'request_id': instance.requestId,
  'message_id': ?instance.messageId,
  'keyword': ?instance.keyword,
};

Map<String, dynamic> _$ConversationPatchRequestToJson(
  ConversationPatchRequest instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'status': ?instance.status,
  'price_before': ?instance.priceBefore,
  'price_after': ?instance.priceAfter,
  'vibe': ?instance.vibe,
  'marketplace': ?instance.marketplace,
};

ExpressResultPayload _$ExpressResultPayloadFromJson(
  Map<String, dynamic> json,
) => ExpressResultPayload(
  seeing: json['seeing'] as String? ?? '',
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => AiDealLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

ConversationWriteResponse _$ConversationWriteResponseFromJson(
  Map<String, dynamic> json,
) => ConversationWriteResponse(
  conversationId: json['conversation_id'] as String,
  messageId: json['message_id'] as String?,
  replyId: json['reply_id'] as String?,
  express: json['express'] == null
      ? null
      : ExpressResultPayload.fromJson(json['express'] as Map<String, dynamic>),
  lines: (json['lines'] as List<dynamic>?)
      ?.map((e) => AiDealLine.fromJson(e as Map<String, dynamic>))
      .toList(),
);
