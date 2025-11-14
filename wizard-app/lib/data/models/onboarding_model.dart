import 'json_serializable.dart';

/// Abstract base class for all onboarding screen models
/// Each screen type (engagement, select, slider) extends this class
abstract class OnboardingModel implements JsonSerializable<OnboardingModel> {
  final dynamic title; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic description; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final dynamic nextButtonText; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final AnswerStructure? answerStructure;
  final bool showTopBar; // Controls visibility of progress bar and back button

  OnboardingModel({
    required this.title,
    this.description, // Made optional
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = true, // Default to true for backward compatibility
  });

  /// Factory constructor that parses JSON and returns the appropriate model type
  factory OnboardingModel.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) {
      throw FormatException('Required field "type" is missing');
    }

    switch (type.toLowerCase()) {
      case 'engagement':
        return EngagementScreenModel.fromJson(json);
      case 'select':
        return SelectScreenModel.fromJson(json);
      case 'slider':
        return SliderScreenModel.fromJson(json);
      default:
        throw FormatException('Unknown screen type: $type');
    }
  }

  /// Get the screen type as a string
  String get type;

  @override
  Map<String, dynamic> toJson();

  @override
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
class AnswerStructure implements JsonSerializable<AnswerStructure> {
  final String answerKeyName;

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

/// Model for engagement-type onboarding screens
class EngagementScreenModel extends OnboardingModel {
  final String? visual; // Lottie resource path or asset path
  final Map<String, dynamic>? metadata; // Optional metadata for visual configuration (width, height, etc.)

  EngagementScreenModel({
    required super.title,
    super.description,
    this.visual,
    this.metadata,
    super.nextButtonText,
    super.answerStructure,
    super.showTopBar,
  });

  @override
  String get type => 'engagement';

  @override
  factory EngagementScreenModel.fromJson(Map<String, dynamic> json) {
    final model = EngagementScreenModel(
      title: JsonParser.requireMultilocaleText(json, 'title'),
      description: JsonParser.optionalMultilocaleText(json, 'description'),
      visual: JsonParser.optionalString(json, 'visual'),
      metadata: JsonParser.optionalMap(json, 'metadata'),
      nextButtonText: JsonParser.optionalMultilocaleText(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonParser.requireMap(json, 'answer_structure'),
            )
          : null,
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      if (description != null) 'description': description,
      if (visual != null) 'visual': visual,
      if (metadata != null) 'metadata': metadata,
      if (nextButtonText != null) 'next_button_text': nextButtonText,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
      if (!showTopBar) 'show_top_bar': showTopBar,
    };
  }
}

/// Option for select-type screens
class OnboardingOption implements JsonSerializable<OnboardingOption> {
  final dynamic label; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic value; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final String? icon; // Material icon name (e.g., "tiktok", "youtube", "search", "store")
  final String? tintColor; // Optional hex color string for brand/tint color (e.g., "#FF6600")
  final Map<String, dynamic>? metadata;

  OnboardingOption({
    required this.label,
    this.value,
    this.icon,
    this.tintColor,
    this.metadata,
  });

  @override
  factory OnboardingOption.fromJson(Map<String, dynamic> json) {
    final option = OnboardingOption(
      label: JsonParser.requireMultilocaleText(json, 'label'),
      value: JsonParser.optionalMultilocaleText(json, 'value'),
      icon: JsonParser.optionalString(json, 'icon'),
      tintColor: JsonParser.optionalString(json, 'tint_color'),
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
      if (icon != null) 'icon': icon,
      if (tintColor != null) 'tint_color': tintColor,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
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
  String get type => 'select';

  @override
  factory SelectScreenModel.fromJson(Map<String, dynamic> json) {
    final model = SelectScreenModel(
      title: JsonParser.requireMultilocaleText(json, 'title'),
      description: JsonParser.optionalMultilocaleText(json, 'description'),
      options: JsonParser.requireList<OnboardingOption>(
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
      nextButtonText: JsonParser.optionalMultilocaleText(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonParser.requireMap(json, 'answer_structure'),
            )
          : null,
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      if (description != null) 'description': description,
      'options': options.map((e) => e.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (nextButtonText != null) 'next_button_text': nextButtonText,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
      if (!showTopBar) 'show_top_bar': showTopBar,
    };
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
class SliderOption {
  final double value;
  final dynamic label; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final String? animation;
  final double? animationWidth;
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
      label: JsonParser.requireMultilocaleText(json, 'label'),
      animation: JsonParser.optionalString(json, 'animation'),
      animationWidth: animationWidth,
      animationHeight: animationHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
      if (animation != null) 'animation': animation,
      if (animationWidth != null) 'animation_width': animationWidth,
      if (animationHeight != null) 'animation_height': animationHeight,
    };
  }
}

/// Model for slider-type onboarding screens
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
  String get type => 'slider';

  @override
  factory SliderScreenModel.fromJson(Map<String, dynamic> json) {
    // Check if this is a discrete slider with options in metadata
    final metadata = JsonParser.optionalMap(json, 'metadata');
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
      title: JsonParser.requireMultilocaleText(json, 'title'),
      description: JsonParser.optionalMultilocaleText(json, 'description'),
      options: options,
      metadata: metadata,
      nextButtonText: JsonParser.optionalMultilocaleText(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonParser.requireMap(json, 'answer_structure'),
            )
          : null,
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      if (description != null) 'description': description,
      if (options.isNotEmpty)
        'metadata': {
          'options': options.map((e) => e.toJson()).toList(),
          if (metadata != null) ...metadata!,
        },
      if (nextButtonText != null) 'next_button_text': nextButtonText,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
      if (!showTopBar) 'show_top_bar': showTopBar,
    };
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

