import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/color_helper.dart';

part 'gradient_background_config.g.dart';

/// Configuration for gradient background
@JsonSerializable()
class GradientBackgroundConfig {
  final List<String> colors; // Hex color strings
  final List<double> stops; // Gradient stops (0.0 to 1.0)

  GradientBackgroundConfig({
    required this.colors,
    required this.stops,
  });

  factory GradientBackgroundConfig.fromJson(Map<String, dynamic> json) =>
      _$GradientBackgroundConfigFromJson(json);

  Map<String, dynamic> toJson() => _$GradientBackgroundConfigToJson(this);

  /// Get colors as Color objects
  /// Supports hex colors with optional opacity (6 or 8 characters)
  /// Filters out invalid colors (returns null if parsing fails)
  List<Color> get colorObjects {
    final colorHelper = di.sl<ColorHelper>();
    return colors
        .map(colorHelper.parseHexColor)
        .whereType<Color>()
        .toList();
  }

  /// Convert to Flutter LinearGradient
  LinearGradient toLinearGradient() => LinearGradient(
      colors: colorObjects,
      stops: stops,
    );
}
