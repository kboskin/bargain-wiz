import 'package:json_annotation/json_annotation.dart';
import 'package:appwizard/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/data/models/remote_config/json_helpers.dart';

part 'onboarding_model.g.dart';

/// Helper to fix JSON keys from generated code to match expected format
Map<String, dynamic> _fixOnboardingModelJsonKeys(
  Map<String, dynamic> json,
  OnboardingScreenType type,
) {
  // Add type field
  json['type'] = type.name;
  
  // Fix JSON key names from camelCase to snake_case
  if (json.containsKey('nextButtonText')) {
    json['next_button_text'] = json.remove('nextButtonText');
  }
  if (json.containsKey('answerStructure')) {
    json['answer_structure'] = json.remove('answerStructure');
  }
  if (json.containsKey('showTopBar')) {
    json['show_top_bar'] = json.remove('showTopBar');
  }
  
  // Remove null values (matching includeIfNull: false behavior)
  json.removeWhere((key, value) => value == null);
  
  return json;
}

/// Abstract base class for all onboarding screen models
/// Each screen type (engagement, select, slider) extends this class
/// Note: Abstract classes can't use @JsonSerializable, so we keep the factory pattern
abstract class OnboardingModel {
  OnboardingModel({
    required this.title,
    this.description, // Made optional
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = true, // Default to true for backward compatibility
  });

  /// Factory constructor that parses JSON and returns the appropriate model type
  factory OnboardingModel.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    if (typeString == null) {
      throw FormatException('Required field "type" is missing');
    }

    final screenType = OnboardingScreenType.fromString(typeString);

    switch (screenType) {
      case OnboardingScreenType.engagement:
        return EngagementScreenModel.fromJson(json);
      case OnboardingScreenType.select:
        return SelectScreenModel.fromJson(json);
      case OnboardingScreenType.slider:
        return SliderScreenModel.fromJson(json);
      case OnboardingScreenType.permission:
        return PermissionScreenModel.fromJson(json);
    }
  }

  final dynamic title; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic description; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final dynamic nextButtonText; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final AnswerStructure? answerStructure;
  final bool showTopBar; // Controls visibility of progress bar and back button

  /// Get the screen type as an enum
  OnboardingScreenType get type;

  Map<String, dynamic> toJson();

  void validate() {
    // Validate title - must be non-empty string or non-empty multilocale map
    if (title is String) {
      if ((title as String).isEmpty) {
        throw FormatException('$runtimeType.title cannot be empty');
      }
    } else if (title is Map<String, dynamic>) {
      if (title.isEmpty) {
        throw FormatException('$runtimeType.title multilocale map cannot be empty');
      }
      // Validate that at least 'en' is present
      if (!title.containsKey('en')) {
        throw FormatException('$runtimeType.title multilocale map must contain "en" key');
      }
    } else {
      throw FormatException('$runtimeType.title must be a String or Map<String, String>');
    }
    // Description is now optional, so no validation needed
    answerStructure?.validate();
  }
}

/// Answer structure configuration
@JsonSerializable()
class AnswerStructure {
  @JsonKey(name: 'answer_key_name')
  final String answerKeyName;

  AnswerStructure({
    required this.answerKeyName,
  });

  factory AnswerStructure.fromJson(Map<String, dynamic> json) =>
      _$AnswerStructureFromJson(json);

  Map<String, dynamic> toJson() => _$AnswerStructureToJson(this);

  void validate() {
    if (answerKeyName.isEmpty) {
      throw FormatException('AnswerStructure.answerKeyName cannot be empty');
    }
  }
}

/// Model for engagement-type onboarding screens
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class EngagementScreenModel extends OnboardingModel {
  final String? visual; // Lottie resource path or asset path
  final Map<String, dynamic>? metadata; // Optional metadata for visual configuration (width, height, etc.)

  @JsonKey(name: 'next_button_text')
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  EngagementScreenModel({
    required super.title,
    super.description,
    this.visual,
    this.metadata,
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = true,
  });

  @override
  OnboardingScreenType get type => OnboardingScreenType.engagement;

  factory EngagementScreenModel.fromJson(Map<String, dynamic> json) {
    final model = EngagementScreenModel(
      title: JsonHelpers.requireMultilocaleText(json, 'title'),
      description: JsonHelpers.optionalMultilocaleText(json, 'description'),
      visual: JsonHelpers.optionalString(json, 'visual'),
      metadata: JsonHelpers.optionalMap(json, 'metadata'),
      nextButtonText: JsonHelpers.optionalMultilocaleText(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonHelpers.requireMap(json, 'answer_structure'),
            )
          : null,
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$EngagementScreenModelToJson(this), type);
}

/// Option for select-type screens
@JsonSerializable()
class OnboardingOption {
  final dynamic label; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic value; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final String? icon; // Material icon name (e.g., "tiktok", "youtube", "search", "store")
  @JsonKey(name: 'tint_color')
  final String? tintColor; // Optional hex color string for brand/tint color (e.g., "#FF6600")
  final Map<String, dynamic>? metadata;

  OnboardingOption({
    required this.label,
    this.value,
    this.icon,
    this.tintColor,
    this.metadata,
  });

  factory OnboardingOption.fromJson(Map<String, dynamic> json) {
    final option = OnboardingOption(
      label: JsonHelpers.requireMultilocaleText(json, 'label'),
      value: JsonHelpers.optionalMultilocaleText(json, 'value'),
      icon: JsonHelpers.optionalString(json, 'icon'),
      tintColor: JsonHelpers.optionalString(json, 'tint_color'),
      metadata: JsonHelpers.optionalMap(json, 'metadata'),
    );
    option.validate();
    return option;
  }

  Map<String, dynamic> toJson() => _$OnboardingOptionToJson(this);

  void validate() {
    // Validate label - must be non-empty string or non-empty multilocale map
    if (label is String) {
      if ((label as String).isEmpty) {
        throw FormatException('OnboardingOption.label cannot be empty');
      }
    } else if (label is Map<String, dynamic>) {
      if (label.isEmpty) {
        throw FormatException('OnboardingOption.label multilocale map cannot be empty');
      }
      // Validate that at least 'en' is present
      if (!label.containsKey('en')) {
        throw FormatException('OnboardingOption.label multilocale map must contain "en" key');
      }
    } else {
      throw FormatException('OnboardingOption.label must be a String or Map<String, String>');
    }
  }
}

/// Model for select-type onboarding screens
@JsonSerializable()
class SelectScreenModel extends OnboardingModel {
  final List<OnboardingOption> options;
  final Map<String, dynamic>? metadata; // Optional metadata for configuration (star_animation, etc.)

  SelectScreenModel({
    required super.title,
    required super.description,
    required this.options,
    this.metadata,
    super.nextButtonText,
    super.answerStructure,
    super.showTopBar,
  });

  @override
  OnboardingScreenType get type => OnboardingScreenType.select;

  factory SelectScreenModel.fromJson(Map<String, dynamic> json) {
    final model = SelectScreenModel(
      title: JsonHelpers.requireMultilocaleText(json, 'title'),
      description: JsonHelpers.optionalMultilocaleText(json, 'description'),
      options: JsonHelpers.requireList<OnboardingOption>(
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
      metadata: JsonHelpers.optionalMap(json, 'metadata'),
      nextButtonText: JsonHelpers.optionalMultilocaleText(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonHelpers.requireMap(json, 'answer_structure'),
            )
          : null,
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$SelectScreenModelToJson(this);
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    if (options.isEmpty) {
      throw FormatException('SelectScreenModel.options cannot be empty');
    }
    for (final option in options) {
      option.validate();
    }
  }
}

/// Slider option with value, label, and optional animation
@JsonSerializable()
class SliderOption {
  final double value;
  final dynamic label; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final String? animation;
  @JsonKey(name: 'animation_width')
  final double? animationWidth;
  @JsonKey(name: 'animation_height')
  final double? animationHeight;

  SliderOption({
    required this.value,
    required this.label,
    this.animation,
    this.animationWidth,
    this.animationHeight,
  });

  factory SliderOption.fromJson(Map<String, dynamic> json) {
    final value = json['value'];
    if (value is! num) {
      throw FormatException(
        'Expected num for slider option value, got ${value.runtimeType}',
      );
    }

    // Parse optional animation dimensions
    double? animationWidth;
    double? animationHeight;
    if (json.containsKey('animation_width')) {
      final width = json['animation_width'];
      if (width is num) {
        animationWidth = width.toDouble();
      }
    }
    if (json.containsKey('animation_height')) {
      final height = json['animation_height'];
      if (height is num) {
        animationHeight = height.toDouble();
      }
    }

    return SliderOption(
      value: value.toDouble(),
      label: JsonHelpers.requireMultilocaleText(json, 'label'),
      animation: JsonHelpers.optionalString(json, 'animation'),
      animationWidth: animationWidth,
      animationHeight: animationHeight,
    );
  }

  Map<String, dynamic> toJson() => _$SliderOptionToJson(this);
}

/// Model for slider-type onboarding screens
@JsonSerializable()
class SliderScreenModel extends OnboardingModel {
  final List<SliderOption> options;
  final Map<String, dynamic>? metadata; // Additional config for legacy continuous sliders

  SliderScreenModel({
    required super.title,
    super.description,
    required this.options,
    this.metadata,
    super.nextButtonText,
    super.answerStructure,
    super.showTopBar,
  });

  @override
  OnboardingScreenType get type => OnboardingScreenType.slider;

  factory SliderScreenModel.fromJson(Map<String, dynamic> json) {
    // Check if this is a discrete slider with options in metadata
    final metadata = JsonHelpers.optionalMap(json, 'metadata');
    List<SliderOption> options = [];

    if (metadata != null && metadata.containsKey('options')) {
      // Discrete slider with options
      final optionsList = metadata['options'];
      if (optionsList is! List) {
        throw FormatException(
          'Expected List for metadata.options, got ${optionsList.runtimeType}',
        );
      }
      options = optionsList
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw FormatException(
                'Expected Map<String, dynamic> for slider option, got ${item.runtimeType}',
              );
            }
            return SliderOption.fromJson(item);
          })
          .toList();
    }

    final model = SliderScreenModel(
      title: JsonHelpers.requireMultilocaleText(json, 'title'),
      description: JsonHelpers.optionalMultilocaleText(json, 'description'),
      options: options,
      metadata: metadata,
      nextButtonText: JsonHelpers.optionalMultilocaleText(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonHelpers.requireMap(json, 'answer_structure'),
            )
          : null,
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$SliderScreenModelToJson(this);
    // Handle special case: options are stored in metadata.options
    if (options.isNotEmpty && json.containsKey('metadata')) {
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      metadata['options'] = options.map((e) => e.toJson()).toList();
      json['metadata'] = metadata;
    } else if (options.isNotEmpty) {
      json['metadata'] = {'options': options.map((e) => e.toJson()).toList()};
    }
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    // Options are required for discrete sliders
    if (options.isEmpty && metadata == null) {
      throw FormatException(
        'SliderScreenModel must have either options or metadata',
      );
    }
    for (final option in options) {
      if (option.label.isEmpty) {
        throw FormatException('SliderOption.label cannot be empty');
      }
    }
  }
}

/// Model for permission-type onboarding screens
@JsonSerializable()
class PermissionScreenModel extends OnboardingModel {
  final String subtype; // e.g., "notifications"
  final String? visual; // Optional Lottie resource path or asset path for frame/animation
  final Map<String, dynamic>? metadata; // Optional metadata for button styling, visual configuration, etc.

  PermissionScreenModel({
    required super.title,
    super.description,
    required this.subtype,
    this.visual,
    this.metadata,
    super.nextButtonText,
    super.answerStructure,
    super.showTopBar,
  });

  @override
  OnboardingScreenType get type => OnboardingScreenType.permission;

  factory PermissionScreenModel.fromJson(Map<String, dynamic> json) {
    final model = PermissionScreenModel(
      title: JsonHelpers.requireMultilocaleText(json, 'title'),
      description: JsonHelpers.optionalMultilocaleText(json, 'description'),
      subtype: JsonHelpers.requireString(json, 'subtype'),
      visual: JsonHelpers.optionalString(json, 'visual'),
      metadata: JsonHelpers.optionalMap(json, 'metadata'),
      nextButtonText: JsonHelpers.optionalMultilocaleText(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonHelpers.requireMap(json, 'answer_structure'),
            )
          : null,
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$PermissionScreenModelToJson(this);
    // Add subtype field (not in generated code)
    json['subtype'] = subtype;
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    if (subtype.isEmpty) {
      throw FormatException('PermissionScreenModel.subtype cannot be empty');
    }
  }
}

/// Extension for pattern matching with when-like syntax
extension OnboardingModelWhen<T> on OnboardingModel {
  /// Pattern matching method similar to Kotlin's when expression
  /// Provides type-safe pattern matching for all screen types
  T when<T>({
    required T Function(EngagementScreenModel) engagement,
    required T Function(SelectScreenModel) select,
    required T Function(SliderScreenModel) slider,
    required T Function(PermissionScreenModel) permission,
    T Function()? orElse,
  }) {
    if (this is EngagementScreenModel) {
      return engagement(this as EngagementScreenModel);
    } else if (this is SelectScreenModel) {
      return select(this as SelectScreenModel);
    } else if (this is SliderScreenModel) {
      return slider(this as SliderScreenModel);
    } else if (this is PermissionScreenModel) {
      return permission(this as PermissionScreenModel);
    } else {
      return orElse?.call() ?? 
        (throw FormatException('Unknown screen type: ${runtimeType}')) as T;
    }
  }
}
