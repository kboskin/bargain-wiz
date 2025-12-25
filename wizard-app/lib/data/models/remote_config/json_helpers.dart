/// Helper functions for JSON parsing that work with json_annotation
/// These provide the same validation as the old JsonParser but are compatible with json_serializable
class JsonHelpers {
  /// Safely extracts a required string field
  static String requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      throw FormatException('Required field "$key" is missing');
    }
    if (value is! String) {
      throw FormatException(
        'Field "$key" must be a String, got ${value.runtimeType}',
      );
    }
    return value;
  }

  /// Safely extracts an optional string field
  static String? optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException(
        'Field "$key" must be a String or null, got ${value.runtimeType}',
      );
    }
    return value;
  }

  /// Safely extracts a required map field
  static Map<String, dynamic> requireMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) {
      throw FormatException('Required field "$key" is missing');
    }
    if (value is! Map<String, dynamic>) {
      throw FormatException(
        'Field "$key" must be a Map<String, dynamic>, got ${value.runtimeType}',
      );
    }
    return value;
  }

  /// Safely extracts an optional map field
  static Map<String, dynamic>? optionalMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw FormatException(
        'Field "$key" must be a Map<String, dynamic> or null, got ${value.runtimeType}',
      );
    }
    return value;
  }

  /// Safely extracts a required double field
  static double requireDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) {
      throw FormatException('Required field "$key" is missing');
    }
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException(
      'Field "$key" must be a number, got ${value.runtimeType}',
    );
  }

  /// Safely extracts a multilocale text field
  /// Supports both Map<String, String> (multilocale) and String (backward compatibility)
  /// Returns dynamic to allow both formats
  static dynamic requireMultilocaleText(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) {
      throw FormatException('Required field "$key" is missing');
    }
    if (value is String) {
      return value; // Backward compatibility
    }
    if (value is Map<String, dynamic>) {
      // Validate that all values in the map are strings
      for (final entry in value.entries) {
        if (entry.value is! String) {
          throw FormatException(
            'Field "$key" multilocale map values must be Strings, got ${entry.value.runtimeType} for key "${entry.key}"',
          );
        }
      }
      return value; // Multilocale format
    }
    throw FormatException(
      'Field "$key" must be a String or Map<String, String>, got ${value.runtimeType}',
    );
  }

  /// Safely extracts an optional multilocale text field
  /// Supports both Map<String, String> (multilocale) and String (backward compatibility)
  static dynamic optionalMultilocaleText(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) {
      return value; // Backward compatibility
    }
    if (value is Map<String, dynamic>) {
      // Validate that all values in the map are strings
      for (final entry in value.entries) {
        if (entry.value is! String) {
          throw FormatException(
            'Field "$key" multilocale map values must be Strings, got ${entry.value.runtimeType} for key "${entry.key}"',
          );
        }
      }
      return value; // Multilocale format
    }
    throw FormatException(
      'Field "$key" must be a String or Map<String, String> or null, got ${value.runtimeType}',
    );
  }

  /// Safely extracts a required list field
  static List<T> requireList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(dynamic) mapper,
  ) {
    final value = json[key];
    if (value == null) {
      throw FormatException('Required field "$key" is missing');
    }
    if (value is! List) {
      throw FormatException(
        'Field "$key" must be a List, got ${value.runtimeType}',
      );
    }
    return value.map((item) => mapper(item)).toList();
  }

  /// Safely extracts an optional list field
  static List<T>? optionalList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(dynamic) mapper,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! List) {
      throw FormatException(
        'Field "$key" must be a List or null, got ${value.runtimeType}',
      );
    }
    return value.map((item) => mapper(item)).toList();
  }
}

