import 'package:flutter/material.dart';

/// Utility class to resolve icons from properties.
class IconResolver {
  /// Result of an icon resolution.
  static ({IconData icon, bool isFontAwesome}) resolve(dynamic input) {
    if (input == null) {
      return (icon: Icons.help_outline, isFontAwesome: false);
    }

    if (input is Map<String, dynamic>) {
      final code = input['code'];
      final font = input['font'] as String?;
      
      int codePoint = 0;
      if (code is int) {
        codePoint = code;
      } else if (code is String) {
        // Handle hex string (e.g., "0xe61b") or decimal
        codePoint = int.tryParse(code) ?? (code.startsWith('0x') ? int.tryParse(code.substring(2), radix: 16) ?? 0 : 0);
      }
      
      String? fontFamily;
      String? fontPackage;
      bool isFontAwesome = false;
      
      final normalizedFont = font?.toLowerCase();
      switch (normalizedFont) {
        case 'brands':
          fontFamily = 'FontAwesomeBrands';
          fontPackage = 'font_awesome_flutter';
          isFontAwesome = true;
          break;
        case 'solid':
          fontFamily = 'FontAwesomeSolid';
          fontPackage = 'font_awesome_flutter';
          isFontAwesome = true;
          break;
        case 'regular':
          fontFamily = 'FontAwesomeRegular';
          fontPackage = 'font_awesome_flutter';
          isFontAwesome = true;
          break;
        case 'material':
          fontFamily = 'MaterialIcons';
          isFontAwesome = false;
          break;
        default:
          fontFamily = 'MaterialIcons';
      }
      
      return (
        // Icons come from Remote Config, so they cannot be const. Release builds must
        // pass --no-tree-shake-icons (see README / build docs).
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(codePoint, fontFamily: fontFamily, fontPackage: fontPackage),
        isFontAwesome: isFontAwesome,
      );
    }

    // Legacy fallback or unknown format
    return (icon: Icons.help_outline, isFontAwesome: false);
  }
}
