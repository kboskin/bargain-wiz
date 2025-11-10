/// Generic interface for JSON serializable models
/// Ensures all models have consistent serialization/deserialization methods
abstract class JsonSerializable<T> {
  /// Creates an instance from a JSON map
  /// Throws [FormatException] if required fields are missing or invalid
  factory JsonSerializable.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('fromJson must be implemented');
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson();

  /// Validates that required fields are present and valid
  /// Throws [FormatException] if validation fails
  void validate() {
    // Override in subclasses to add validation logic
  }
}

/// Extension for parsing JSON lists with strict type checking
extension JsonListExtension on List<dynamic> {
  /// Maps a JSON list to a list of serializable objects with strict type checking
  List<T> mapToModel<T extends JsonSerializable<T>>(
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return map((item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException(
          'Expected Map<String, dynamic>, got ${item.runtimeType}',
        );
      }
      return fromJson(item);
    }).toList();
  }
}

/// Helper class for strict JSON parsing with validation
class JsonParser {
  /// Safely extracts a required string field
  static String requireString(
    Map<String, dynamic> json,
    String key,
  ) {
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
  static String? optionalString(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException(
        'Field "$key" must be a String or null, got ${value.runtimeType}',
      );
    }
    return value;
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
}

