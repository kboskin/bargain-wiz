import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pro_deal_closer_message_model.g.dart';

/// Data model for a single Pro Deal Closer message; (de)serialization is generated.
@JsonSerializable(explicitToJson: true)
class ProDealCloserMessageModel {
  ProDealCloserMessageModel({
    this.text = '',
    List<String>? attachmentPaths,
    this.isWizard = false,
    List<Map<String, dynamic>>? options,
  })  : attachmentPaths = attachmentPaths ?? const [],
        options = options ?? const [];

  final String text;
  final List<String> attachmentPaths;
  @JsonKey(defaultValue: false)
  final bool isWizard;
  /// Serialized [DealLine]s (`{text, intent, why}`).
  final List<Map<String, dynamic>> options;

  factory ProDealCloserMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ProDealCloserMessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProDealCloserMessageModelToJson(this);

  ProDealCloserMessage toEntity() {
    return ProDealCloserMessage(
      text: text,
      attachmentPaths: List<String>.from(attachmentPaths),
      isWizard: isWizard,
      options: options.map(DealLine.fromJson).toList(),
    );
  }

  static ProDealCloserMessageModel fromEntity(ProDealCloserMessage entity) {
    return ProDealCloserMessageModel(
      text: entity.text,
      attachmentPaths: List<String>.from(entity.attachmentPaths),
      isWizard: entity.isWizard,
      options: entity.options.map((o) => o.toJson()).toList(),
    );
  }
}
