import 'package:flutter/material.dart';

/// Utility class for parsing and converting color strings
class ColorHelper {
  /// Parse color from hex string with optional opacity/alpha channel
  /// Supports formats:
  /// - 6 characters: "#FFC107" or "FFC107" (RGB, full opacity)
  /// - 8 characters: "#80FFC107" or "80FFC107" (ARGB with alpha channel)
  /// 
  /// Returns the parsed Color, or [defaultColor] if parsing fails
  Color parseHexColor(
    String colorString, {
    Color defaultColor = const Color(0xFFFFC107), // Amber as default
  }) {
    // Remove # if present and trim whitespace
    final hexCode = colorString.replaceAll('#', '').trim();

    // Validate hex format (6 or 8 characters)
    if (!RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
      return defaultColor;
    }

    try {
      // If 6 characters, add FF for full opacity
      // If 8 characters, use as-is (includes alpha channel)
      final fullHex = hexCode.length == 6 ? 'FF$hexCode' : hexCode;
      return Color(int.parse(fullHex, radix: 16));
    } catch (e) {
      return defaultColor;
    }
  }

  /// Get color from string (hex code) with optional default color
  /// Convenience method that wraps parseHexColor
  Color getColor(
    String? colorString, {
    Color defaultColor = const Color(0xFFFFC107), // Amber as default
  }) {
    if (colorString == null || colorString.isEmpty) {
      return defaultColor;
    }
    return parseHexColor(colorString, defaultColor: defaultColor);
  }
}

