import 'dart:convert';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/validatable_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_screen_config.g.dart';

/// Onboarding screen type enum
enum OnboardingScreenType {
  select,
  slider,
  engagement,
  permission,
  imageList,
  referralCode,
  paywall,
  warmup,
  dataUpload,
  createAccount;

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
      case 'imagelist':
      case 'image_list':
        return OnboardingScreenType.imageList;
      case 'referralcode':
      case 'referral_code':
        return OnboardingScreenType.referralCode;
      case 'paywall':
        return OnboardingScreenType.paywall;
      case 'warmup':
        return OnboardingScreenType.warmup;
      case 'dataupload':
      case 'data_upload':
        return OnboardingScreenType.dataUpload;
      case 'createaccount':
      case 'create_account':
        return OnboardingScreenType.createAccount;
      default:
        return OnboardingScreenType.engagement;
    }
  }
}

/// Onboarding screen configuration model
@JsonSerializable()
class OnboardingScreenConfig extends ValidatableEntity {
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  @JsonKey(fromJson: _typeFromJson, toJson: _typeToJson)
  final OnboardingScreenType type;
  final String? visual; // Lottie resource path or asset path
  final List<OnboardingScreenConfigOption>? options; // For select type
  final Map<String, dynamic>? metadata; // Additional config (e.g., min/max for slider)
  @JsonKey(name: 'answer_structure')
  final AnswerStructureConfig? answerStructure; // Structure for storing the answer
  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  final dynamic nextButtonText; // Custom button text for this step (e.g., "Next", "Get Started", "Continue")

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

  factory OnboardingScreenConfig.fromJson(Map<String, dynamic> json) => _$OnboardingScreenConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$OnboardingScreenConfigToJson(this);

  @override
  void validate() {
    super.validate();
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
class OnboardingScreenConfigOption extends ValidatableEntity {
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic label;
  final String? value;
  final Map<String, dynamic>? metadata;

  OnboardingScreenConfigOption({
    required this.label,
    this.value,
    this.metadata,
  });

  factory OnboardingScreenConfigOption.fromJson(Map<String, dynamic> json) => _$OnboardingScreenConfigOptionFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$OnboardingScreenConfigOptionToJson(this);

  @override
  void validate() {
    super.validate();
  }
}

/// Answer structure configuration (legacy - use AnswerStructure from onboarding_model.dart)
@JsonSerializable()
class AnswerStructureConfig extends ValidatableEntity {
  @JsonKey(name: 'answer_key_name')
  final String answerKeyName; // Unique key for storing the answer (e.g., "marketplace", "deal_count")

  AnswerStructureConfig({
    required this.answerKeyName,
  });

  factory AnswerStructureConfig.fromJson(Map<String, dynamic> json) =>
      _$AnswerStructureConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AnswerStructureConfigToJson(this);

  @override
  void validate() {
    super.validate();
    if (answerKeyName.isEmpty) {
      throw FormatException('AnswerStructureConfig.answerKeyName cannot be empty');
    }
  }
}

/// Collection of onboarding screens
@JsonSerializable()
class OnboardingConfig extends ValidatableEntity {
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

  @override
  void validate() {
    super.validate();
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
