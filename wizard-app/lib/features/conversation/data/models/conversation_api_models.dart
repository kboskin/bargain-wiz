import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';
import 'package:json_annotation/json_annotation.dart';

part 'conversation_api_models.g.dart';

/// Request/response models of the `conversations` Cloud Function (CONVERSATIONS.md).
/// Requests nest the buyer profile under `profile`, like the AI functions do.

/// Buyer profile sent with every write, because it drives the prompt: the answers the
/// onboarding screens collect, in screen order, each carrying the sentence remote config
/// writes for the option that was picked. The app copies what the template declares; the
/// backend renders the sentences and knows nothing about the keys (AI_INTEGRATION.md).
class ConversationProfile {
  const ConversationProfile(this.answers, {required this.locale});

  /// Straight from one resolution, so the values and their sentences cannot disagree.
  factory ConversationProfile.of(ProfileSnapshot snapshot, {required String locale}) =>
      ConversationProfile(snapshot.answers, locale: locale);

  /// One entry per pick, in onboarding screen order — which is the order the buyer block
  /// reads in, so the template controls the prompt's shape as well as its words.
  final List<ProfileAnswer> answers;

  /// Language of the lines to generate; a device fact, not an answer.
  final String locale;

  Map<String, dynamic> toJson() => {
        'answers': [for (final a in answers) a.toJson()],
        'locale': locale,
      };
}

/// `POST /conversations`: the first turn (text and/or screenshots) opens the conversation.
@JsonSerializable(createFactory: false, explicitToJson: true, includeIfNull: false)
class CreateConversationRequest {
  const CreateConversationRequest({
    required this.type,
    required this.profile,
    this.overrides = const {},
    this.text,
    this.images,
    this.keyword,
    this.objective,
  });

  /// "pro" | "express"
  final String type;
  final String? text;
  final List<AiImagePayload>? images;
  /// Express only: what the buyer wants to focus on.
  final String? keyword;
  /// What the deal is for, picked before it started — plain text, the objective's sentence.
  /// Set here and nowhere else: the conversation keeps it for every later turn.
  final String? objective;

  /// The conversation-scoped answers this deal carries; stored on the conversation so
  /// reopening it restores them (CONVERSATIONS.md).
  final Map<String, dynamic> overrides;
  @JsonKey(includeToJson: false)
  final ConversationProfile profile;

  Map<String, dynamic> toJson() => {'profile': profile.toJson(), ..._$CreateConversationRequestToJson(this)};
}

/// `POST /conversations/{cid}/messages`.
@JsonSerializable(createFactory: false, explicitToJson: true, includeIfNull: false)
class SendMessageRequest {
  const SendMessageRequest({required this.profile, this.overrides = const {}, this.text, this.images});

  final String? text;
  final List<AiImagePayload>? images;

  /// As on [CreateConversationRequest]: re-stamped on the conversation with every turn.
  final Map<String, dynamic> overrides;
  @JsonKey(includeToJson: false)
  final ConversationProfile profile;

  Map<String, dynamic> toJson() => {'profile': profile.toJson(), ..._$SendMessageRequestToJson(this)};
}

/// `POST /conversations/{cid}/options` and `POST /conversations/{cid}/redo`.
@JsonSerializable(createFactory: false, includeIfNull: false)
class ConversationActionRequest {
  const ConversationActionRequest({
    required this.profile,
    this.overrides = const {},
    this.messageId,
    this.keyword,
  });

  /// Target wizard message; the latest one when omitted.
  @JsonKey(name: 'message_id')
  final String? messageId;
  /// Express only: the focus keyword for a regenerated result.
  final String? keyword;

  /// As on [CreateConversationRequest]: a redo is how an override change is applied.
  final Map<String, dynamic> overrides;
  @JsonKey(includeToJson: false)
  final ConversationProfile profile;

  Map<String, dynamic> toJson() => {'profile': profile.toJson(), ..._$ConversationActionRequestToJson(this)};
}

/// `PATCH /conversations/{cid}`: history metadata; only the fields sent change.
@JsonSerializable(createFactory: false, includeIfNull: false)
class ConversationPatchRequest {
  const ConversationPatchRequest({
    this.title,
    this.status,
    this.priceBefore,
    this.priceAfter,
    this.overrides,
  });

  final String? title;
  /// "open" | "won" | "lost"
  final String? status;
  @JsonKey(name: 'price_before')
  final String? priceBefore;
  @JsonKey(name: 'price_after')
  final String? priceAfter;

  /// The conversation-scoped answers this deal carries, `{answer key: value}` — the ones
  /// the template marks `scope: "conversation"`. Null leaves them untouched.
  final Map<String, dynamic>? overrides;

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
