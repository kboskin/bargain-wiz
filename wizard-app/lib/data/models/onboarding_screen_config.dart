import 'dart:convert';

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
class OnboardingOption {
  final String label;
  final String? value;
  final Map<String, dynamic>? metadata;

  OnboardingOption({
    required this.label,
    this.value,
    this.metadata,
  });

  factory OnboardingOption.fromJson(Map<String, dynamic> json) {
    return OnboardingOption(
      label: json['label'] as String,
      value: json['value'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      'metadata': metadata,
    };
  }
}

/// Answer structure configuration
class AnswerStructure {
  final String answerKeyName; // Unique key for storing the answer (e.g., "marketplace", "deal_count")

  AnswerStructure({
    required this.answerKeyName,
  });

  factory AnswerStructure.fromJson(Map<String, dynamic> json) {
    return AnswerStructure(
      answerKeyName: json['answer_key_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer_key_name': answerKeyName,
    };
  }
}

/// Onboarding screen configuration model
class OnboardingScreenConfig {
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

  factory OnboardingScreenConfig.fromJson(Map<String, dynamic> json) {
    return OnboardingScreenConfig(
      title: json['title'] as String,
      description: json['description'] as String,
      type: OnboardingScreenType.fromString(json['type'] as String? ?? 'engagement'),
      visual: json['visual'] as String?,
      options: json['options'] != null
          ? (json['options'] as List)
              .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(json['answer_structure'] as Map<String, dynamic>)
          : null,
      nextButtonText: json['next_button_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'visual': visual,
      'options': options?.map((e) => e.toJson()).toList(),
      'metadata': metadata,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
      if (nextButtonText != null) 'next_button_text': nextButtonText,
    };
  }

  /// Create from JSON string
  factory OnboardingScreenConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return OnboardingScreenConfig.fromJson(json);
  }

  /// Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

/// Collection of onboarding screens
class OnboardingConfig {
  final List<OnboardingScreenConfig> screens;

  OnboardingConfig({required this.screens});

  factory OnboardingConfig.fromJson(List<dynamic> json) {
    return OnboardingConfig(
      screens: json
          .map((e) => OnboardingScreenConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  List<Map<String, dynamic>> toJson() {
    return screens.map((e) => e.toJson()).toList();
  }

  /// Create from JSON string
  factory OnboardingConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as List<dynamic>;
    return OnboardingConfig.fromJson(json);
  }

  /// Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

