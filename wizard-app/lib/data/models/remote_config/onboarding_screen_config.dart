import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_screen_config.g.dart';

/// Onboarding screen type enum
enum OnboardingScreenType {
  select,
  slider,
  engagement,
  permission;

  static OnboardingScreenType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'select':
        return OnboardingScreenType.select;
      case 'slider':
        return OnboardingScreenType.slider;
      case 'engagement':
        return OnboardingScreenType.engagement;
      case 'permission':
        return OnboardingScreenType.permission;
      default:
        return OnboardingScreenType.engagement;
    }
  }
}

/// Onboarding screen configuration model
@JsonSerializable()
class OnboardingScreenConfig {
  final String title;
  final String description;
  @JsonKey(fromJson: _typeFromJson, toJson: _typeToJson)
  final OnboardingScreenType type;
  final String? visual; // Lottie resource path or asset path
  final List<OnboardingScreenConfigOption>? options; // For select type
  final Map<String, dynamic>? metadata; // Additional config (e.g., min/max for slider)
  @JsonKey(name: 'answer_structure')
  final AnswerStructureConfig? answerStructure; // Structure for storing the answer
  @JsonKey(name: 'next_button_text')
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

  factory OnboardingScreenConfig.fromJson(Map<String, dynamic> json) =>
      _$OnboardingScreenConfigFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingScreenConfigToJson(this);

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

  static OnboardingScreenType _typeFromJson(String value) =>
      OnboardingScreenType.fromString(value);

  static String _typeToJson(OnboardingScreenType type) => type.name;

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

/// Option for select type screens (legacy - use OnboardingOption from onboarding_model.dart)
@JsonSerializable()
class OnboardingScreenConfigOption {
  final String label;
  final String? value;
  final Map<String, dynamic>? metadata;

  OnboardingScreenConfigOption({
    required this.label,
    this.value,
    this.metadata,
  });

  factory OnboardingScreenConfigOption.fromJson(Map<String, dynamic> json) =>
      _$OnboardingScreenConfigOptionFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingScreenConfigOptionToJson(this);

  void validate() {
    if (label.isEmpty) {
      throw FormatException('OnboardingScreenConfigOption.label cannot be empty');
    }
  }
}

/// Answer structure configuration (legacy - use AnswerStructure from onboarding_model.dart)
@JsonSerializable()
class AnswerStructureConfig {
  @JsonKey(name: 'answer_key_name')
  final String answerKeyName; // Unique key for storing the answer (e.g., "marketplace", "deal_count")

  AnswerStructureConfig({
    required this.answerKeyName,
  });

  factory AnswerStructureConfig.fromJson(Map<String, dynamic> json) =>
      _$AnswerStructureConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AnswerStructureConfigToJson(this);

  void validate() {
    if (answerKeyName.isEmpty) {
      throw FormatException('AnswerStructureConfig.answerKeyName cannot be empty');
    }
  }
}

/// Collection of onboarding screens
@JsonSerializable()
class OnboardingConfig {
  final List<OnboardingScreenConfig> screens;

  OnboardingConfig({required this.screens});

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
      screens: json
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw FormatException(
                'Expected Map<String, dynamic> for screen, got ${item.runtimeType}',
              );
            }
            return OnboardingScreenConfig.fromJson(item);
          })
          .toList(),
    );
    config.validate();
    return config;
  }

  Map<String, dynamic> toJson() => _$OnboardingConfigToJson(this);

  /// Convert to JSON list (for compatibility with existing format)
  List<Map<String, dynamic>> toJsonList() {
    return screens.map((e) => e.toJson()).toList();
  }

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
