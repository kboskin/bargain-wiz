import 'dart:convert';
import 'json_serializable.dart';

/// Onboarding screen type enum
enum OnboardingScreenType {
  select,
  slider,
  engagement;

  static OnboardingScreenType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'select':
        return OnboardingScreenType.select;
      case 'slider':
        return OnboardingScreenType.slider;
      case 'engagement':
        return OnboardingScreenType.engagement;
      default:
        return OnboardingScreenType.engagement;
    }
  }
}

/// Option for select type screens
class OnboardingOption implements JsonSerializable<OnboardingOption> {
  final String label;
  final String? value;
  final Map<String, dynamic>? metadata;

  OnboardingOption({
    required this.label,
    this.value,
    this.metadata,
  });

  @override
  factory OnboardingOption.fromJson(Map<String, dynamic> json) {
    final option = OnboardingOption(
      label: JsonParser.requireString(json, 'label'),
      value: JsonParser.optionalString(json, 'value'),
      metadata: JsonParser.optionalMap(json, 'metadata'),
    );
    option.validate();
    return option;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      if (value != null) 'value': value,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  void validate() {
    if (label.isEmpty) {
      throw FormatException('OnboardingOption.label cannot be empty');
    }
  }
}

/// Answer structure configuration
class AnswerStructure implements JsonSerializable<AnswerStructure> {
  final String answerKeyName; // Unique key for storing the answer (e.g., "marketplace", "deal_count")

  AnswerStructure({
    required this.answerKeyName,
  });

  @override
  factory AnswerStructure.fromJson(Map<String, dynamic> json) {
    final structure = AnswerStructure(
      answerKeyName: JsonParser.requireString(json, 'answer_key_name'),
    );
    structure.validate();
    return structure;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'answer_key_name': answerKeyName,
    };
  }

  @override
  void validate() {
    if (answerKeyName.isEmpty) {
      throw FormatException('AnswerStructure.answerKeyName cannot be empty');
    }
  }
}

/// Onboarding screen configuration model
class OnboardingScreenConfig implements JsonSerializable<OnboardingScreenConfig> {
  final String title;
  final String description;
  final OnboardingScreenType type;
  final String? visual; // Lottie resource path or asset path
  final List<OnboardingOption>? options; // For select type
  final Map<String, dynamic>? metadata; // Additional config (e.g., min/max for slider)
  final AnswerStructure? answerStructure; // Structure for storing the answer
  final String? nextButtonText; // Custom button text for this step (e.g., "Next", "Get Started", "Continue")

  OnboardingScreenConfig({
    required this.title,
    required this.description,
    required this.type,
    this.visual,
    this.options,
    this.metadata,
    this.answerStructure,
    this.nextButtonText,
  });

  @override
  factory OnboardingScreenConfig.fromJson(Map<String, dynamic> json) {
    final config = OnboardingScreenConfig(
      title: JsonParser.requireString(json, 'title'),
      description: JsonParser.requireString(json, 'description'),
      type: OnboardingScreenType.fromString(
        JsonParser.requireString(json, 'type'),
      ),
      visual: JsonParser.optionalString(json, 'visual'),
      options: JsonParser.optionalList<OnboardingOption>(
        json,
        'options',
        (item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException(
              'Expected Map<String, dynamic> for option, got ${item.runtimeType}',
            );
          }
          return OnboardingOption.fromJson(item);
        },
      ),
      metadata: JsonParser.optionalMap(json, 'metadata'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonParser.requireMap(json, 'answer_structure'),
            )
          : null,
      nextButtonText: JsonParser.optionalString(json, 'next_button_text'),
    );
    config.validate();
    return config;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      if (visual != null) 'visual': visual,
      if (options != null) 'options': options!.map((e) => e.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
      if (nextButtonText != null) 'next_button_text': nextButtonText,
    };
  }

  @override
  void validate() {
    if (title.isEmpty) {
      throw FormatException('OnboardingScreenConfig.title cannot be empty');
    }
    if (description.isEmpty) {
      throw FormatException('OnboardingScreenConfig.description cannot be empty');
    }
    // Validate options if present
    if (options != null) {
      for (final option in options!) {
        option.validate();
      }
    }
    // Validate answer structure if present
    answerStructure?.validate();
  }

  /// Create from JSON string
  factory OnboardingScreenConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString);
    if (json is! Map<String, dynamic>) {
      throw FormatException(
        'Expected Map<String, dynamic>, got ${json.runtimeType}',
      );
    }
    return OnboardingScreenConfig.fromJson(json);
  }

  /// Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

/// Collection of onboarding screens
class OnboardingConfig implements JsonSerializable<OnboardingConfig> {
  final List<OnboardingScreenConfig> screens;

  OnboardingConfig({required this.screens});

  @override
  factory OnboardingConfig.fromJson(Map<String, dynamic> json) {
    // For OnboardingConfig, we expect a list at the root level
    // This is a special case - we'll handle it differently
    throw UnimplementedError(
      'Use OnboardingConfig.fromJsonList instead for list-based JSON',
    );
  }

  /// Create from JSON list (special case for root-level array)
  factory OnboardingConfig.fromJsonList(List<dynamic> json) {
    final config = OnboardingConfig(
      screens: json.mapToModel<OnboardingScreenConfig>(
        (item) => OnboardingScreenConfig.fromJson(item),
      ),
    );
    config.validate();
    return config;
  }

  @override
  Map<String, dynamic> toJson() {
    // Return as a map with 'screens' key for consistency
    return {
      'screens': screens.map((e) => e.toJson()).toList(),
    };
  }

  /// Convert to JSON list (for compatibility with existing format)
  List<Map<String, dynamic>> toJsonList() {
    return screens.map((e) => e.toJson()).toList();
  }

  @override
  void validate() {
    // Empty screens is valid (e.g., when no config is found)
    // Only validate non-empty screens
    for (final screen in screens) {
      screen.validate();
    }
  }

  /// Create from JSON string
  factory OnboardingConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString);
    if (json is List) {
      return OnboardingConfig.fromJsonList(json);
    } else if (json is Map<String, dynamic>) {
      // Support both formats: list at root or map with 'screens' key
      if (json.containsKey('screens')) {
        final screensList = json['screens'];
        if (screensList is! List) {
          throw FormatException(
            'Expected List for screens, got ${screensList.runtimeType}',
          );
        }
        return OnboardingConfig.fromJsonList(screensList);
      }
      throw FormatException('Expected "screens" key in JSON map');
    } else {
      throw FormatException(
        'Expected List or Map<String, dynamic>, got ${json.runtimeType}',
      );
    }
  }

  /// Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJsonList());
  }
}

