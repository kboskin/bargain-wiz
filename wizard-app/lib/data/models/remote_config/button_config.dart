import 'package:json_annotation/json_annotation.dart';
import 'package:appwizard/core/theme/button_style.dart';

part 'button_config.g.dart';

/// Configuration model for button styling and behavior
/// Parses from metadata button configuration
@JsonSerializable()
class ButtonConfig {
  final dynamic text; // Can be multilocale map or string
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
