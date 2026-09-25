import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:json_annotation/json_annotation.dart';

part 'deal_objective.g.dart';

/// One objective a deal can be started for (`main_page_config.deal_closer_objectives`).
///
/// [prompt] is the objective itself — plain text, what the model is told the deal is for. It
/// belongs to the deal, not the buyer: the app sends it once, with the request that creates
/// the conversation, and the backend keeps it there and puts it in every prompt of that deal
/// (CONVERSATIONS.md, AI_INTEGRATION.md). [label] and [emoji] are only how the chip reads.
@JsonSerializable(createToJson: false)
class DealObjective {
  const DealObjective({this.label, this.emoji, this.prompt});

  factory DealObjective.fromJson(final Map<String, dynamic> json) => _$DealObjectiveFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  final MultilocaleText? label;
  final String? emoji;
  final String? prompt;

  static MultilocaleText? _multilocaleFromJson(final dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;
}
