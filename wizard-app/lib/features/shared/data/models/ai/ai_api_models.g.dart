// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiImagePayload _$AiImagePayloadFromJson(Map<String, dynamic> json) =>
    AiImagePayload(
      mimeType: json['mime_type'] as String,
      data: json['data'] as String,
    );

Map<String, dynamic> _$AiImagePayloadToJson(AiImagePayload instance) =>
    <String, dynamic>{'mime_type': instance.mimeType, 'data': instance.data};

AiDealLine _$AiDealLineFromJson(Map<String, dynamic> json) => AiDealLine(
  text: json['text'] as String? ?? '',
  intent: json['intent'] as String?,
  why: json['why'] as String?,
);

Map<String, dynamic> _$AiDealLineToJson(AiDealLine instance) =>
    <String, dynamic>{
      'intent': instance.intent,
      'text': instance.text,
      'why': instance.why,
    };

ExpressDealmakerRequest _$ExpressDealmakerRequestFromJson(
  Map<String, dynamic> json,
) => ExpressDealmakerRequest(
  images: (json['images'] as List<dynamic>)
      .map((e) => AiImagePayload.fromJson(e as Map<String, dynamic>))
      .toList(),
  locale: json['locale'] as String,
  vibe: json['vibe'] as String,
  push: (json['push'] as num).toInt(),
  text: json['text'] as String?,
  keyword: json['keyword'] as String?,
  marketplace: json['marketplace'] as String?,
  dealSize: json['deal_size'] as num?,
  dealsPerMonth: json['deals_per_month'] as String?,
  hurdles: (json['hurdles'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ExpressDealmakerRequestToJson(
  ExpressDealmakerRequest instance,
) => <String, dynamic>{
  'images': instance.images.map((e) => e.toJson()).toList(),
  'text': ?instance.text,
  'keyword': ?instance.keyword,
  'locale': instance.locale,
  'vibe': instance.vibe,
  'push': instance.push,
  'marketplace': ?instance.marketplace,
  'deal_size': ?instance.dealSize,
  'deals_per_month': ?instance.dealsPerMonth,
  'hurdles': ?instance.hurdles,
};

ExpressDealmakerResponse _$ExpressDealmakerResponseFromJson(
  Map<String, dynamic> json,
) => ExpressDealmakerResponse(
  seeing: json['seeing'] as String? ?? '',
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => AiDealLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  model: json['model'] as String?,
);

Map<String, dynamic> _$ExpressDealmakerResponseToJson(
  ExpressDealmakerResponse instance,
) => <String, dynamic>{
  'seeing': instance.seeing,
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'model': instance.model,
};

AiChatMessage _$AiChatMessageFromJson(Map<String, dynamic> json) =>
    AiChatMessage(
      role: json['role'] as String,
      text: json['text'] as String,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => AiImagePayload.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AiChatMessageToJson(AiChatMessage instance) =>
    <String, dynamic>{
      'role': instance.role,
      'text': instance.text,
      'images': ?instance.images?.map((e) => e.toJson()).toList(),
    };

ProDealCloserRequest _$ProDealCloserRequestFromJson(
  Map<String, dynamic> json,
) => ProDealCloserRequest(
  messages: (json['messages'] as List<dynamic>)
      .map((e) => AiChatMessage.fromJson(e as Map<String, dynamic>))
      .toList(),
  mode: json['mode'] as String,
  locale: json['locale'] as String,
  vibe: json['vibe'] as String,
  push: (json['push'] as num).toInt(),
  regenerate: json['regenerate'] as bool? ?? false,
  marketplace: json['marketplace'] as String?,
  dealSize: json['deal_size'] as num?,
  dealsPerMonth: json['deals_per_month'] as String?,
  hurdles: (json['hurdles'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ProDealCloserRequestToJson(
  ProDealCloserRequest instance,
) => <String, dynamic>{
  'messages': instance.messages.map((e) => e.toJson()).toList(),
  'mode': instance.mode,
  'regenerate': instance.regenerate,
  'locale': instance.locale,
  'vibe': instance.vibe,
  'push': instance.push,
  'marketplace': ?instance.marketplace,
  'deal_size': ?instance.dealSize,
  'deals_per_month': ?instance.dealsPerMonth,
  'hurdles': ?instance.hurdles,
};

ProReplyResponse _$ProReplyResponseFromJson(Map<String, dynamic> json) =>
    ProReplyResponse(
      reply: json['reply'] as String? ?? '',
      model: json['model'] as String?,
    );

Map<String, dynamic> _$ProReplyResponseToJson(ProReplyResponse instance) =>
    <String, dynamic>{'reply': instance.reply, 'model': instance.model};

ProOptionsResponse _$ProOptionsResponseFromJson(Map<String, dynamic> json) =>
    ProOptionsResponse(
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map((e) => AiDealLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      model: json['model'] as String?,
    );

Map<String, dynamic> _$ProOptionsResponseToJson(ProOptionsResponse instance) =>
    <String, dynamic>{
      'lines': instance.lines.map((e) => e.toJson()).toList(),
      'model': instance.model,
    };
