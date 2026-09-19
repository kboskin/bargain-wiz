import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';
import 'package:json_annotation/json_annotation.dart';

part 'conversation_api_models.g.dart';

/// Request/response models of the `conversations` Cloud Function (CONVERSATIONS.md).
/// Requests carry the buyer profile flat at the top level, like the AI functions do.

/// Buyer profile sent with every write (it drives the prompt): the `{field: value}` pairs the
/// onboarding screens declare a `key` for, plus the device locale. The app copies the fields
/// remote config declares; the backend owns their meaning and ignores what its contract does
/// not define (AI_INTEGRATION.md).
class ConversationProfile {
  const ConversationProfile(this.fields, {required this.locale});

  /// Profile fields as remote config maps them (`vibe`, `push`, `marketplace`, …).
  final Map<String, dynamic> fields;

  /// Language of the lines to generate; a device fact, not an answer.
  final String locale;

  /// One field of the profile, however remote config named the answer behind it.
  dynamic operator [](String field) => fields[field];

  Map<String, dynamic> toJson() => {...fields, 'locale': locale};
}

/// `POST /conversations`: the first turn (text and/or screenshots) opens the conversation.
@JsonSerializable(createFactory: false, explicitToJson: true, includeIfNull: false)
class CreateConversationRequest {
  const CreateConversationRequest({
    required this.type,
    required this.profile,
    this.text,
    this.images,
    this.keyword,
  });

  /// "pro" | "express"
  final String type;
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
  const SendMessageRequest({required this.profile, this.text, this.images});

  final String? text;
  final List<AiImagePayload>? images;
  @JsonKey(includeToJson: false)
  final ConversationProfile profile;

  Map<String, dynamic> toJson() => {...profile.toJson(), ..._$SendMessageRequestToJson(this)};
}

/// `POST /conversations/{cid}/options` and `POST /conversations/{cid}/redo`.
@JsonSerializable(createFactory: false, includeIfNull: false)
class ConversationActionRequest {
  const ConversationActionRequest({required this.profile, this.messageId, this.keyword});

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

/// Response of every write: just the ids to subscribe with. The backend queues the model
/// call, so results (reply text, express lines, option lines) arrive through the listener.
@JsonSerializable(createToJson: false)
class ConversationWriteResponse {
  const ConversationWriteResponse({required this.conversationId, this.messageId, this.replyId});

  factory ConversationWriteResponse.fromJson(Map<String, dynamic> json) => _$ConversationWriteResponseFromJson(json);

  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'message_id')
  final String? messageId;

  /// The wizard message that will hold the answer.
  @JsonKey(name: 'reply_id')
  final String? replyId;
}
