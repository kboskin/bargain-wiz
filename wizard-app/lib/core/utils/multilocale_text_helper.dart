import 'package:flutter/material.dart';

/// Helper utility for extracting localized text from multilocale text objects
/// Supports both multilocale format: {"en": "text", "es": "texto"}
/// and simple string format for backward compatibility: "text"
class MultilocaleTextHelper {
  const MultilocaleTextHelper();

  /// Extract the localized text from a multilocale text object or simple string
  /// 
  /// If the input is a Map (multilocale format), returns the text for the current locale
  /// Falls back to 'en' if current locale is not available
  /// 
  /// If the input is a String, returns it as-is (backward compatibility)
  /// 
  /// Returns empty string if input is null or invalid
  String getText(BuildContext context, dynamic textData) {
    if (textData == null) {
      return '';
    }

    // If it's already a string, return as-is (backward compatibility)
    if (textData is String) {
      return textData;
    }

    // If it's a Map, extract based on locale
    if (textData is Map<String, dynamic>) {
      final locale = Localizations.localeOf(context);
      final languageCode = locale.languageCode;

      // Try to get text for current language
      if (textData.containsKey(languageCode)) {
        final text = textData[languageCode];
        if (text is String) {
          return text;
        }
      }

      // Fallback to 'en' if current language not available
      if (textData.containsKey('en')) {
        final text = textData['en'];
        if (text is String) {
          return text;
        }
      }

      // Fallback to first available value
      if (textData.isNotEmpty) {
        final firstValue = textData.values.first;
        if (firstValue is String) {
          return firstValue;
        }
      }
    }

    // If we can't parse it, try to convert to string
    return textData.toString();
  }

  /// Get the current language code from context
  String getLanguageCode(BuildContext context) {
    return Localizations.localeOf(context).languageCode;
  }
}

