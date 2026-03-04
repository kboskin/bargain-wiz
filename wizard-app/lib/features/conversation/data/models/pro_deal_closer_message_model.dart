import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pro_deal_closer_message_model.g.dart';

/// Data model for a single Pro Deal Closer message; (de)serialization is generated.
@JsonSerializable()
class ProDealCloserMessageModel {
  ProDealCloserMessageModel({
    this.text = '',
    List<String>? attachmentPaths,
  }) : attachmentPaths = attachmentPaths ?? const [];

  final String text;
  final List<String> attachmentPaths;

  factory ProDealCloserMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ProDealCloserMessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProDealCloserMessageModelToJson(this);

  ProDealCloserMessage toEntity() {
    return ProDealCloserMessage(
      text: text,
      attachmentPaths: List<String>.from(attachmentPaths),
    );
  }

  static ProDealCloserMessageModel fromEntity(ProDealCloserMessage entity) {
    return ProDealCloserMessageModel(
      text: entity.text,
      attachmentPaths: List<String>.from(entity.attachmentPaths),
    );
  }
}
