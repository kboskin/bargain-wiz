import 'package:appwizard/features/conversation/data/models/pro_deal_closer_message_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'conversation_model.g.dart';

/// Data model for [Conversation]; [type] segregates which fields are used.
/// (De)serialization is generated; list fields default to empty when missing.
@JsonSerializable(
  explicitToJson: true,
)
class ConversationModel {
  ConversationModel({
    required this.id,
    this.type = 'express',
    List<String>? screenshotPaths,
    List<String>? replyOptions,
    List<Map<String, dynamic>>? replyLines,
    this.keyword,
    List<ProDealCloserMessageModel>? messages,
    required this.createdAtMillis,
    this.title,
    this.marketplace,
    this.status = 'open',
    this.priceBefore,
    this.priceAfter,
    this.seeing,
    this.vibe,
  })  : screenshotPaths = screenshotPaths ?? const [],
        replyOptions = replyOptions ?? const [],
        replyLines = replyLines ?? const [],
        messages = messages ?? const [];

  final String id;
  final String type;
  @JsonKey(name: 'screenshots')
  final List<String> screenshotPaths;
  final List<String> replyOptions;
  /// Serialized [DealLine]s (`{text, intent, why}`).
  final List<Map<String, dynamic>> replyLines;
  final String? keyword;
  final List<ProDealCloserMessageModel> messages;
  final int createdAtMillis;
  final String? title;
  final String? marketplace;
  @JsonKey(defaultValue: 'open')
  final String status;
  final String? priceBefore;
  final String? priceAfter;
  final String? seeing;
  final String? vibe;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final safe = Map<String, dynamic>.from(json)
      ..['id'] = json['id'] as String? ?? ''
      ..['createdAtMillis'] = (json['createdAtMillis'] as num?)?.toInt() ?? 0;
    return _$ConversationModelFromJson(safe);
  }

  Map<String, dynamic> toJson() => _$ConversationModelToJson(this);
}
