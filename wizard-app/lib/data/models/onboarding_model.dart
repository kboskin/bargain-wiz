import 'json_serializable.dart';

/// Abstract base class for all onboarding screen models
/// Each screen type (engagement, select, slider) extends this class
abstract class OnboardingModel implements JsonSerializable<OnboardingModel> {
  final String title;
  final String description;
  final String? nextButtonText;
  final AnswerStructure? answerStructure;

  OnboardingModel({
    required this.title,
    required this.description,
    this.nextButtonText,
    this.answerStructure,
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
    if (title.isEmpty) {
      throw FormatException('$runtimeType.title cannot be empty');
    }
    if (description.isEmpty) {
      throw FormatException('$runtimeType.description cannot be empty');
    }
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

  EngagementScreenModel({
    required super.title,
    required super.description,
    this.visual,
    super.nextButtonText,
    super.answerStructure,
  });

  @override
  String get type => 'engagement';

  @override
  factory EngagementScreenModel.fromJson(Map<String, dynamic> json) {
    final model = EngagementScreenModel(
      title: JsonParser.requireString(json, 'title'),
      description: JsonParser.requireString(json, 'description'),
      visual: JsonParser.optionalString(json, 'visual'),
      nextButtonText: JsonParser.optionalString(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonParser.requireMap(json, 'answer_structure'),
            )
          : null,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type,
      if (visual != null) 'visual': visual,
      if (nextButtonText != null) 'next_button_text': nextButtonText,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
    };
  }
}

/// Option for select-type screens
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

/// Model for select-type onboarding screens
class SelectScreenModel extends OnboardingModel {
  final List<OnboardingOption> options;

  SelectScreenModel({
    required super.title,
    required super.description,
    required this.options,
    super.nextButtonText,
    super.answerStructure,
  });

  @override
  String get type => 'select';

  @override
  factory SelectScreenModel.fromJson(Map<String, dynamic> json) {
    final model = SelectScreenModel(
      title: JsonParser.requireString(json, 'title'),
      description: JsonParser.requireString(json, 'description'),
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
      nextButtonText: JsonParser.optionalString(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonParser.requireMap(json, 'answer_structure'),
            )
          : null,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'options': options.map((e) => e.toJson()).toList(),
      if (nextButtonText != null) 'next_button_text': nextButtonText,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
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
  final String label;
  final String? animation;

  SliderOption({
    required this.value,
    required this.label,
    this.animation,
  });

  factory SliderOption.fromJson(Map<String, dynamic> json) {
    final value = json['value'];
    if (value is! num) {
      throw FormatException(
        'Expected num for slider option value, got ${value.runtimeType}',
      );
    }

    return SliderOption(
      value: value.toDouble(),
      label: JsonParser.requireString(json, 'label'),
      animation: JsonParser.optionalString(json, 'animation'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
      if (animation != null) 'animation': animation,
    };
  }
}

/// Model for slider-type onboarding screens
class SliderScreenModel extends OnboardingModel {
  final List<SliderOption> options;
  final Map<String, dynamic>? metadata; // Additional config for legacy continuous sliders

  SliderScreenModel({
    required super.title,
    required super.description,
    required this.options,
    this.metadata,
    super.nextButtonText,
    super.answerStructure,
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
      title: JsonParser.requireString(json, 'title'),
      description: JsonParser.requireString(json, 'description'),
      options: options,
      metadata: metadata,
      nextButtonText: JsonParser.optionalString(json, 'next_button_text'),
      answerStructure: json['answer_structure'] != null
          ? AnswerStructure.fromJson(
              JsonParser.requireMap(json, 'answer_structure'),
            )
          : null,
    );
    model.validate();
    return model;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type,
      if (options.isNotEmpty)
        'metadata': {
          'options': options.map((e) => e.toJson()).toList(),
          if (metadata != null) ...metadata!,
        },
      if (nextButtonText != null) 'next_button_text': nextButtonText,
      if (answerStructure != null) 'answer_structure': answerStructure!.toJson(),
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

