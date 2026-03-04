import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:appwizard/data/models/remote_config/button_config.dart';

/// Remote config for the Rate Us / satisfaction modal.
/// Same structure as the permission screen: title, optional visual, buttons (ButtonConfig).
/// Key in RC: [rate_us_modal_config].
class RateUsModalConfig {
  RateUsModalConfig({
    required this.title,
    this.description,
    this.visual,
    this.visualWidth = 80.0,
    this.visualHeight = 80.0,
    required this.buttons,
    this.highlightWords,
    this.highlightColor,
  });

  final dynamic title; // MultilocaleText from JSON
  final dynamic description;
  final String? visual;
  final double visualWidth;
  final double visualHeight;
  final List<ButtonConfig> buttons;
  /// Optional. Map e.g. {"title": {"word": "#hex"}} or list; same as onboarding.
  final dynamic highlightWords;
  /// Default highlight color (hex string) when word has no specific color.
  final String? highlightColor;

  factory RateUsModalConfig.fromJson(Map<String, dynamic> json) {
    final buttonsList = json['buttons'] as List<dynamic>? ?? [];
    return RateUsModalConfig(
      title: json['title'] != null ? MultilocaleText.fromJson(json['title']) : null,
      description: json['description'] != null ? MultilocaleText.fromJson(json['description']) : null,
      visual: json['visual'] as String?,
      visualWidth: (json['visual_width'] as num?)?.toDouble() ?? 80.0,
      visualHeight: (json['visual_height'] as num?)?.toDouble() ?? 80.0,
      buttons: buttonsList
          .whereType<Map<String, dynamic>>()
          .map(ButtonConfig.fromJson)
          .toList(),
      highlightWords: json['highlight_words'],
      highlightColor: json['highlight_color'] as String?,
    );
  }
}
