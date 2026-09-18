import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';
import 'package:json_annotation/json_annotation.dart';

part 'conversation_api_models.g.dart';

/// Request/response models of the `conversations` Cloud Function (CONVERSATIONS.md).
/// Requests carry the buyer profile flat at the top level, like the AI functions do.

/// Buyer profile fields sent with every write (they drive the prompt).
@JsonSerializable(includeIfNull: false)
class ConversationProfile {
  const ConversationProfile({
    required this.vibe,
    required this.push,
    required this.locale,
    this.marketplace,
    this.dealSize,
    this.dealsPerMonth,
    this.hurdles,
  });

  factory ConversationProfile.fromJson(Map<String, dynamic> json) => _$ConversationProfileFromJson(json);

  final String vibe;
  final int push;
  final String locale;
  final String? marketplace;
  @JsonKey(name: 'deal_size')
  final num? dealSize;
  @JsonKey(name: 'deals_per_month')
  final String? dealsPerMonth;
  final List<String>? hurdles;

  Map<String, dynamic> toJson() => _$ConversationProfileToJson(this);
}

/// `POST /conversations`: the first turn (text and/or screenshots) opens the conversation.
@JsonSerializable(createFactory: false, explicitToJson: true, includeIfNull: false)
class CreateConversationRequest {
  const CreateConversationRequest({
    required this.type,
    required this.requestId,
    required this.profile,
    this.text,
    this.images,
    this.keyword,
  });

  /// "pro" | "express"
  final String type;
  @JsonKey(name: 'request_id')
  final String requestId;
  final String? text;
  final List<AiImagePayload>? images;
  /// Express only: what the buyer wants to focus on.
  final String? keyword;
  @JsonKey(includeToJson: false)
  final ConversationProfile profile;

  Map<String, dynamic> toJson() => {...profile.toJson(), ..._$CreateConversationRequestToJson(this)};
}

/// `POST /conversations/{cid}/messages`.
@JsonSerializable(createFactory: false, explicitToJson: true, includeIfNull: false)
class SendMessageRequest {
  const SendMessageRequest({required this.requestId, required this.profile, this.text, this.images});

  @JsonKey(name: 'request_id')
  final String requestId;
  final String? text;
  final List<AiImagePayload>? images;
  @JsonKey(includeToJson: false)
  final ConversationProfile profile;

  Map<String, dynamic> toJson() => {...profile.toJson(), ..._$SendMessageRequestToJson(this)};
}

/// `POST /conversations/{cid}/options` and `POST /conversations/{cid}/redo`.
@JsonSerializable(createFactory: false, includeIfNull: false)
class ConversationActionRequest {
  const ConversationActionRequest({required this.requestId, required this.profile, this.messageId, this.keyword});

  @JsonKey(name: 'request_id')
  final String requestId;
  /// Target wizard message; the latest one when omitted.
  @JsonKey(name: 'message_id')
  final String? messageId;
  /// Express only: the focus keyword for a regenerated result.
  final String? keyword;
  @JsonKey(includeToJson: false)
  final ConversationProfile profile;

  Map<String, dynamic> toJson() => {...profile.toJson(), ..._$ConversationActionRequestToJson(this)};
}

/// `PATCH /conversations/{cid}`: history metadata; only the fields sent change.
@JsonSerializable(createFactory: false, includeIfNull: false)
class ConversationPatchRequest {
  const ConversationPatchRequest({
    this.title,
    this.status,
    this.priceBefore,
    this.priceAfter,
    this.vibe,
    this.marketplace,
  });

  final String? title;
  /// "open" | "won" | "lost"
  final String? status;
  @JsonKey(name: 'price_before')
  final String? priceBefore;
  @JsonKey(name: 'price_after')
  final String? priceAfter;
  final String? vibe;
  final String? marketplace;

  Map<String, dynamic> toJson() => _$ConversationPatchRequestToJson(this);
}

/// Express result echoed inline so the results screen can render before the listener catches up.
@JsonSerializable(createToJson: false)
class ExpressResultPayload {
  const ExpressResultPayload({required this.seeing, required this.lines});

  factory ExpressResultPayload.fromJson(Map<String, dynamic> json) => _$ExpressResultPayloadFromJson(json);

  @JsonKey(defaultValue: '')
  final String seeing;
  @JsonKey(defaultValue: <AiDealLine>[])
  final List<AiDealLine> lines;
}

/// Response of every write: ids to subscribe with, plus the express result or option lines.
@JsonSerializable(createToJson: false)
class ConversationWriteResponse {
  const ConversationWriteResponse({
    required this.conversationId,
    this.messageId,
    this.replyId,
    this.express,
    this.lines,
  });

  factory ConversationWriteResponse.fromJson(Map<String, dynamic> json) => _$ConversationWriteResponseFromJson(json);

  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'message_id')
  final String? messageId;
  @JsonKey(name: 'reply_id')
  final String? replyId;
  final ExpressResultPayload? express;
  final List<AiDealLine>? lines;
}
