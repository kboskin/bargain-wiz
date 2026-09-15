import 'package:json_annotation/json_annotation.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:flutter/material.dart';
import 'package:appwizard/core/utils/color_helper.dart';

part 'gradient_background_config.g.dart';

/// Configuration for gradient background
@JsonSerializable()
class GradientBackgroundConfig {
  final List<String> colors; // Hex color strings
  final List<double> stops; // Gradient stops (0.0 to 1.0)
  /// CSS-style angle in degrees (0 = bottom→top, 90 = left→right). Default 135 (top-left → bottom-right).
  @JsonKey(name: 'angle_deg')
  final double? angleDeg;

  GradientBackgroundConfig({
    required this.colors,
    required this.stops,
    this.angleDeg,
  });

  factory GradientBackgroundConfig.fromJson(Map<String, dynamic> json) =>
      _$GradientBackgroundConfigFromJson(json);

  Map<String, dynamic> toJson() => _$GradientBackgroundConfigToJson(this);

  /// Get colors as Color objects
  /// Supports hex colors with optional opacity (6 or 8 characters)
  /// Filters out invalid colors (returns null if parsing fails)
  List<Color> get colorObjects {
    final colorHelper = ColorHelper();
    return colors
        .map(colorHelper.parseHexColor)
        .whereType<Color>()
        .toList();
  }

  /// Convert to Flutter LinearGradient
  LinearGradient toLinearGradient() {
    final colors = colorObjects;
    return WizColors.angledGradient(
      colors,
      stops.length == colors.length ? stops : null,
      angleDeg ?? 135,
    );
  }
}
