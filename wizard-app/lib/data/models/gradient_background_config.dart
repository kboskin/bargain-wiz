import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/data/models/json_serializable.dart';
import 'package:flutter/material.dart';

/// Configuration for the app's gradient background
class GradientBackgroundConfig implements JsonSerializable<GradientBackgroundConfig> {
  GradientBackgroundConfig({
    required this.colors,
    required this.stops,
  });

  @override
  factory GradientBackgroundConfig.fromJson(Map<String, dynamic> json) {
    final config = GradientBackgroundConfig(
      colors: JsonParser.requireList<String>(
        json,
        'colors',
        (item) {
          if (item is! String) {
            throw FormatException(
              'Expected String for color, got ${item.runtimeType}',
            );
          }
          return item;
        },
      ),
      stops: JsonParser.requireList<double>(
        json,
        'stops',
        (item) {
          if (item is! num) {
            throw FormatException(
              'Expected num for stop, got ${item.runtimeType}',
            );
          }
          return item.toDouble();
        },
      ),
    );
    config.validate();
    return config;
  }

  final List<String> colors; // Hex color strings like ["#F3E5F5", "#E8EAF6", "#E0F2F1"]
  final List<double> stops; // Gradient stops like [0.0, 0.5, 1.0]

  /// Get colors as Color objects
  /// Supports hex colors with optional opacity (6 or 8 characters)
  List<Color> get colorObjects {
    final colorHelper = di.sl<ColorHelper>();
    return colors.map((c) => colorHelper.parseHexColor(c)).toList();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'colors': colors,
      'stops': stops,
    };
  }

  @override
  void validate() {
    if (colors.isEmpty) {
      throw FormatException('GradientBackgroundConfig.colors cannot be empty');
    }
    if (stops.isEmpty) {
      throw FormatException('GradientBackgroundConfig.stops cannot be empty');
    }
    if (colors.length != stops.length) {
      throw FormatException(
        'GradientBackgroundConfig: colors and stops must have the same length',
      );
    }
    // Validate hex colors (supports 6 or 8 characters with optional #)
    for (final color in colors) {
      final hexCode = color.replaceAll('#', '');
      if (!RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
        throw FormatException('Invalid hex color format: $color (expected 6 or 8 character hex code)');
      }
    }
    // Validate stops are between 0.0 and 1.0
    for (final stop in stops) {
      if (stop < 0.0 || stop > 1.0) {
        throw FormatException('Stop must be between 0.0 and 1.0: $stop');
      }
    }
  }
}

