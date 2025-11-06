import 'package:flutter/material.dart';
import 'json_serializable.dart';

/// Configuration for the app's gradient background
class GradientBackgroundConfig implements JsonSerializable<GradientBackgroundConfig> {
  final List<String> colors; // Hex color strings like ["#F3E5F5", "#E8EAF6", "#E0F2F1"]
  final List<double> stops; // Gradient stops like [0.0, 0.5, 1.0]

  GradientBackgroundConfig({
    required this.colors,
    required this.stops,
  });

  /// Convert hex string to Color
  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  /// Get colors as Color objects
  List<Color> get colorObjects => colors.map((c) => _hexToColor(c)).toList();

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
    // Validate hex colors
    for (final color in colors) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
        throw FormatException('Invalid hex color format: $color');
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

