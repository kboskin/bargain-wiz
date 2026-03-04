import 'package:appwizard/features/shared/data/models/validatable_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'highlight_words_config.g.dart';

/// Configuration for words to highlight in title and description.
/// Both title and description can be a Map (word -> color) or List (backward compatibility).
@JsonSerializable()
class HighlightWordsConfig extends ValidatableEntity {
  @JsonKey(fromJson: _highlightWordsFieldFromJson)
  final dynamic title; // Map<String, String> (word -> color) or List<String>

  @JsonKey(fromJson: _highlightWordsFieldFromJson)
  final dynamic description; // Map<String, String> (word -> color) or List<String>

  HighlightWordsConfig({
    this.title,
    this.description,
  });

  factory HighlightWordsConfig.fromJson(Map<String, dynamic> json) =>
      _$HighlightWordsConfigFromJson(json);

  Map<String, dynamic> toJson() => _$HighlightWordsConfigToJson(this);

  static dynamic _highlightWordsFieldFromJson(dynamic json) {
    if (json == null) return null;
    if (json is Map) return json as Map<String, dynamic>;
    if (json is List) return (json as List).map((e) => e.toString()).toList();
    return null;
  }
}
