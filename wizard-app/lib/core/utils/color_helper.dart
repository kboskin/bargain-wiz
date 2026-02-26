import 'package:flutter/material.dart';

import 'package:appwizard/core/utils/app_logger.dart';

/// Utility class for parsing and converting color strings
class ColorHelper {
  ColorHelper([this._logger]);

  final AppLogger? _logger;

  /// Parse color from hex string with optional opacity/alpha channel
  /// Supports formats:
  /// - 6 characters: "#FFC107" or "FFC107" (RGB, full opacity)
  /// - 8 characters: "#80FFC107" or "80FFC107" (ARGB with alpha channel)
  ///
  /// Returns the parsed Color, or null if parsing fails
  Color? parseHexColor(String colorString) {
    // Remove # if present and trim whitespace
    final hexCode = colorString.replaceAll('#', '').trim();

    // Validate hex format (6 or 8 characters)
    if (!RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
      return null;
    }

    try {
      // If 6 characters, add FF for full opacity
      // If 8 characters, use as-is (includes alpha channel)
      final fullHex = hexCode.length == 6 ? 'FF$hexCode' : hexCode;
      return Color(int.parse(fullHex, radix: 16));
    } catch (e) {
      _logger?.w('Failed to parse hex color "$colorString": $e');
      return null;
    }
  }

  /// Get color from string (hex code)
  /// Returns null if colorString is null, empty, or parsing fails
  Color? getColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }
    return parseHexColor(colorString);
  }
}

