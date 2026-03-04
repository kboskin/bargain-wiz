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
    this.keyword,
    List<ProDealCloserMessageModel>? messages,
    required this.createdAtMillis,
  })  : screenshotPaths = screenshotPaths ?? const [],
        replyOptions = replyOptions ?? const [],
        messages = messages ?? const [];

  final String id;
  final String type;
  @JsonKey(name: 'screenshots')
  final List<String> screenshotPaths;
  final List<String> replyOptions;
  final String? keyword;
  final List<ProDealCloserMessageModel> messages;
  final int createdAtMillis;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final safe = Map<String, dynamic>.from(json)
      ..['id'] = json['id'] as String? ?? ''
      ..['createdAtMillis'] = (json['createdAtMillis'] as num?)?.toInt() ?? 0;
    return _$ConversationModelFromJson(safe);
  }

  Map<String, dynamic> toJson() => _$ConversationModelToJson(this);
}
