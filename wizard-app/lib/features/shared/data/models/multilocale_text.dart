import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'multilocale_text.g.dart';

/// Represents text that can be localized or a simple string.
/// 
/// Supported formats in JSON:
/// 1. Simple String: "Hello"
/// 2. Localized Map: {"en": "Hello", "es": "Hola"}
@JsonSerializable(createToJson: true)
class MultilocaleText {
  @JsonKey(includeFromJson: true, includeToJson: true)
  final dynamic _data;

  const MultilocaleText(this._data);

  /// Factory constructor for JSON deserialization
  /// This is used by json_serializable when this class is a field in another class
  factory MultilocaleText.fromJson(dynamic json) {
    if (json == null) return const MultilocaleText('');
    return MultilocaleText(json);
  }

  /// Converts to JSON format (either String or Map)
  dynamic toJson() => _data;

  /// Gets the text for the current locale from the given [context].
  /// Falls back to 'en' if the current language is not available.
  String get(BuildContext context) {
    if (_data == null) return '';
    if (_data is String) return _data;
    
    if (_data is Map) {
      final map = _data;
      final locale = Localizations.localeOf(context).languageCode;
      
      // Try current locale
      final localized = map[locale];
      if (localized is String) return localized;
      
      // Fallback to English
      final english = map['en'] ?? map['en-US'];
      if (english is String) return english;
      
      // Final fallback to first value
      if (map.isNotEmpty) {
        final firstValue = map.values.first;
        if (firstValue is String) return firstValue;
        return firstValue.toString();
      }
    }
    
    return _data.toString();
  }

  /// Returns true if the text is empty for the current context
  bool isEmpty(BuildContext context) => get(context).isEmpty;

  /// Returns true if the text is not empty for the current context
  bool isNotEmpty(BuildContext context) => get(context).isNotEmpty;

  @override
  String toString() => _data.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultilocaleText &&
          runtimeType == other.runtimeType &&
          _data == other._data;

  @override
  int get hashCode => _data.hashCode;
}
