import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:json_annotation/json_annotation.dart';

part 'button_config.g.dart';

/// Configuration model for button styling and behavior
/// Parses from metadata button configuration
@JsonSerializable()
class ButtonConfig {
  @JsonKey(name: 'text', fromJson: _textFromJson)
  final dynamic text;
  @JsonKey(name: 'action', fromJson: _actionFromJson, toJson: _actionToJson)
  final ButtonAction action;
  @JsonKey(name: 'button_color')
  final String? buttonColor; // Hex color string
  @JsonKey(name: 'glow_color')
  final String? glowColor; // Hex color string
  @JsonKey(name: 'glow_intensity')
  final double? glowIntensity; // 0.0 to 1.0
  @JsonKey(name: 'glow_pulse')
  final bool? glowPulse; // Whether glow should pulse/animate
  @JsonKey(name: 'button_style', fromJson: _buttonStyleFromJson, toJson: _buttonStyleToJson)
  final ButtonVisualStyle buttonStyle; // Visual style enum

  ButtonConfig({
    this.text,
    required this.action,
    this.buttonColor,
    this.glowColor,
    this.glowIntensity,
    this.glowPulse,
    this.buttonStyle = ButtonVisualStyle.glow,
  });

  /// Create from JSON (parses from metadata button config)
  factory ButtonConfig.fromJson(Map<String, dynamic> json) => _$ButtonConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ButtonConfigToJson(this);

  static dynamic _textFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  static ButtonAction _actionFromJson(String? value) {
    if (value == null) return ButtonAction.continueAction;
    return ButtonAction.fromString(value);
  }

  static String _actionToJson(ButtonAction action) => action.toJson();

  static ButtonVisualStyle _buttonStyleFromJson(String? value) {
    if (value == null) return ButtonVisualStyle.glow;
    return ButtonVisualStyle.fromString(value);
  }

  static String _buttonStyleToJson(ButtonVisualStyle style) => style.toJson();
}
