import 'package:json_annotation/json_annotation.dart';

part 'ai_api_models.g.dart';

/// Request/response models of the AI Cloud Functions `express_dealmaker` and
/// `pro_deal_closer` (wizard-backend/functions). See AI_INTEGRATION.md.

/// One screenshot: `{"mime_type": "image/jpeg", "data": "<base64>"}`.
@JsonSerializable()
class AiImagePayload {
  const AiImagePayload({required this.mimeType, required this.data});

  factory AiImagePayload.fromJson(Map<String, dynamic> json) => _$AiImagePayloadFromJson(json);

  @JsonKey(name: 'mime_type')
  final String mimeType;
  final String data;

  Map<String, dynamic> toJson() => _$AiImagePayloadToJson(this);
}

/// A ready-to-paste negotiation line with its intent and rationale.
@JsonSerializable()
class AiDealLine {
  const AiDealLine({required this.text, this.intent, this.why});

  factory AiDealLine.fromJson(Map<String, dynamic> json) => _$AiDealLineFromJson(json);

  /// "opener" | "counter" | "close"
  final String? intent;
  @JsonKey(defaultValue: '')
  final String text;
  final String? why;

  Map<String, dynamic> toJson() => _$AiDealLineToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ExpressDealmakerResponse {
  const ExpressDealmakerResponse({required this.seeing, required this.lines, this.model});

  factory ExpressDealmakerResponse.fromJson(Map<String, dynamic> json) => _$ExpressDealmakerResponseFromJson(json);

  @JsonKey(defaultValue: '')
  final String seeing;
  @JsonKey(defaultValue: <AiDealLine>[])
  final List<AiDealLine> lines;
  final String? model;

  Map<String, dynamic> toJson() => _$ExpressDealmakerResponseToJson(this);
}

/// One turn of the Pro Deal Closer chat as sent to the function.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class AiChatMessage {
  const AiChatMessage({required this.role, required this.text, this.images});

  factory AiChatMessage.fromJson(Map<String, dynamic> json) => _$AiChatMessageFromJson(json);

  /// "user" | "wizard"
  final String role;
  final String text;
  final List<AiImagePayload>? images;

  Map<String, dynamic> toJson() => _$AiChatMessageToJson(this);
}

@JsonSerializable()
class ProReplyResponse {
  const ProReplyResponse({required this.reply, this.model});

  factory ProReplyResponse.fromJson(Map<String, dynamic> json) => _$ProReplyResponseFromJson(json);

  @JsonKey(defaultValue: '')
  final String reply;
  final String? model;

  Map<String, dynamic> toJson() => _$ProReplyResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProOptionsResponse {
  const ProOptionsResponse({required this.lines, this.model});

  factory ProOptionsResponse.fromJson(Map<String, dynamic> json) => _$ProOptionsResponseFromJson(json);

  @JsonKey(defaultValue: <AiDealLine>[])
  final List<AiDealLine> lines;
  final String? model;

  Map<String, dynamic> toJson() => _$ProOptionsResponseToJson(this);
}
