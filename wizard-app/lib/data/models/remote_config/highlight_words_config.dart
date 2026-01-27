import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:json_annotation/json_annotation.dart';

part 'highlight_words_config.g.dart';

/// Configuration for words to highlight in title and description
/// Both title and description can be a Map (word -> color) or List (backward compatibility)
@JsonSerializable()
class HighlightWordsConfig {
  final dynamic title; // Can be Map<String, String> (word -> color) or List<String>
  final dynamic description; // Can be Map<String, String> (word -> color) or List<String>

  HighlightWordsConfig({
    this.title,
    this.description,
  });

  factory HighlightWordsConfig.fromJson(Map<String, dynamic> json) {
    dynamic titleData;
    if (json['title'] != null) {
      if (json['title'] is Map) {
        titleData = json['title'] as Map<String, dynamic>;
      } else if (json['title'] is List) {
        titleData = (json['title'] as List).map((item) => item.toString()).toList();
      }
    }

    dynamic descriptionData;
    if (json['description'] != null) {
      if (json['description'] is Map) {
        descriptionData = json['description'] as Map<String, dynamic>;
      } else if (json['description'] is List) {
        descriptionData = (json['description'] as List).map((item) => item.toString()).toList();
      }
    }

    return HighlightWordsConfig(
      title: titleData,
      description: descriptionData,
    );
  }

  Map<String, dynamic> toJson() => _$HighlightWordsConfigToJson(this);

  void validate() {
    // No validation needed - nulls or empty lists/maps are allowed
  }
}
