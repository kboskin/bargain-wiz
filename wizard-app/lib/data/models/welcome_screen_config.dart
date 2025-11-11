import 'json_serializable.dart';

/// Configuration for the welcome/landing screen
/// Separate from onboarding flow screens to allow full customization
class WelcomeScreenConfig implements JsonSerializable<WelcomeScreenConfig> {
  final dynamic title; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic description; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final String? visual; // Optional: Lottie animation path or asset path
  final dynamic primaryButtonText; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final GlassContainerConfig? glassContainer;
  final HighlightWordsConfig? highlightWords;
  final SecondaryActionConfig? secondaryAction;
  final String? highlightColor; // Optional: Hex color for highlights (defaults to amber)

  WelcomeScreenConfig({
    required this.title,
    required this.description,
    this.visual,
    required this.primaryButtonText,
    this.glassContainer,
    this.highlightWords,
    this.secondaryAction,
    this.highlightColor,
  });

  @override
  factory WelcomeScreenConfig.fromJson(Map<String, dynamic> json) {
    final config = WelcomeScreenConfig(
      title: JsonParser.requireMultilocaleText(json, 'title'),
      description: JsonParser.requireMultilocaleText(json, 'description'),
      visual: json['visual'] as String?,
      primaryButtonText: JsonParser.requireMultilocaleText(json, 'primary_button_text'),
      glassContainer: json['glass_container'] != null
          ? GlassContainerConfig.fromJson(
              json['glass_container'] as Map<String, dynamic>)
          : null,
      highlightWords: json['highlight_words'] != null
          ? HighlightWordsConfig.fromJson(
              json['highlight_words'] as Map<String, dynamic>)
          : null,
      secondaryAction: json['secondary_action'] != null
          ? SecondaryActionConfig.fromJson(
              json['secondary_action'] as Map<String, dynamic>)
          : null,
      highlightColor: json['highlight_color'] as String?,
    );
    config.validate();
    return config;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      if (visual != null) 'visual': visual,
      'primary_button_text': primaryButtonText,
      if (glassContainer != null) 'glass_container': glassContainer!.toJson(),
      if (highlightWords != null) 'highlight_words': highlightWords!.toJson(),
      if (secondaryAction != null) 'secondary_action': secondaryAction!.toJson(),
      if (highlightColor != null) 'highlight_color': highlightColor,
    };
  }

  @override
  void validate() {
    // Validate title - must be non-empty string or non-empty multilocale map
    if (title is String) {
      if ((title as String).isEmpty) {
        throw FormatException('WelcomeScreenConfig.title cannot be empty');
      }
    } else if (title is Map<String, dynamic>) {
      if (title.isEmpty) {
        throw FormatException('WelcomeScreenConfig.title multilocale map cannot be empty');
      }
      if (!title.containsKey('en')) {
        throw FormatException('WelcomeScreenConfig.title multilocale map must contain "en" key');
      }
    } else {
      throw FormatException('WelcomeScreenConfig.title must be a String or Map<String, String>');
    }

    // Validate description - must be non-empty string or non-empty multilocale map
    if (description is String) {
      if ((description as String).isEmpty) {
        throw FormatException('WelcomeScreenConfig.description cannot be empty');
      }
    } else if (description is Map<String, dynamic>) {
      if (description.isEmpty) {
        throw FormatException('WelcomeScreenConfig.description multilocale map cannot be empty');
      }
      if (!description.containsKey('en')) {
        throw FormatException('WelcomeScreenConfig.description multilocale map must contain "en" key');
      }
    } else {
      throw FormatException('WelcomeScreenConfig.description must be a String or Map<String, String>');
    }

    // Validate primaryButtonText - must be non-empty string or non-empty multilocale map
    if (primaryButtonText is String) {
      if ((primaryButtonText as String).isEmpty) {
        throw FormatException('WelcomeScreenConfig.primaryButtonText cannot be empty');
      }
    } else if (primaryButtonText is Map<String, dynamic>) {
      if (primaryButtonText.isEmpty) {
        throw FormatException('WelcomeScreenConfig.primaryButtonText multilocale map cannot be empty');
      }
      if (!primaryButtonText.containsKey('en')) {
        throw FormatException('WelcomeScreenConfig.primaryButtonText multilocale map must contain "en" key');
      }
    } else {
      throw FormatException('WelcomeScreenConfig.primaryButtonText must be a String or Map<String, String>');
    }

    glassContainer?.validate();
    highlightWords?.validate();
    secondaryAction?.validate();
    if (highlightColor != null) {
      final hexCode = highlightColor!.replaceAll('#', '');
      if (!RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
        throw FormatException('Invalid hex color format for highlightColor: $highlightColor');
      }
    }
  }
}

/// Configuration for the glass container placeholder
class GlassContainerConfig implements JsonSerializable<GlassContainerConfig> {
  final double blurSigma;
  final String color; // Hex color string
  final double opacity;
  final double borderRadius;
  final double height;
  final double iconSize;
  final double iconOpacity;

  GlassContainerConfig({
    required this.blurSigma,
    required this.color,
    required this.opacity,
    required this.borderRadius,
    required this.height,
    required this.iconSize,
    required this.iconOpacity,
  });

  @override
  factory GlassContainerConfig.fromJson(Map<String, dynamic> json) {
    final config = GlassContainerConfig(
      blurSigma: JsonParser.requireDouble(json, 'blur_sigma'),
      color: JsonParser.requireString(json, 'color'),
      opacity: JsonParser.requireDouble(json, 'opacity'),
      borderRadius: JsonParser.requireDouble(json, 'border_radius'),
      height: JsonParser.requireDouble(json, 'height'),
      iconSize: JsonParser.requireDouble(json, 'icon_size'),
      iconOpacity: JsonParser.requireDouble(json, 'icon_opacity'),
    );
    config.validate();
    return config;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'blur_sigma': blurSigma,
      'color': color,
      'opacity': opacity,
      'border_radius': borderRadius,
      'height': height,
      'icon_size': iconSize,
      'icon_opacity': iconOpacity,
    };
  }

  @override
  void validate() {
    if (blurSigma < 0) {
      throw FormatException('GlassContainerConfig.blurSigma must be >= 0');
    }
    if (opacity < 0 || opacity > 1) {
      throw FormatException(
          'GlassContainerConfig.opacity must be between 0 and 1');
    }
    if (borderRadius < 0) {
      throw FormatException(
          'GlassContainerConfig.borderRadius must be >= 0');
    }
    if (height <= 0) {
      throw FormatException('GlassContainerConfig.height must be > 0');
    }
    if (iconSize <= 0) {
      throw FormatException('GlassContainerConfig.iconSize must be > 0');
    }
    if (iconOpacity < 0 || iconOpacity > 1) {
      throw FormatException(
          'GlassContainerConfig.iconOpacity must be between 0 and 1');
    }
    // Validate hex color
    final hexCode = color.replaceAll('#', '');
    if (!RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
      throw FormatException('Invalid hex color format: $color');
    }
  }
}

/// Configuration for words to highlight in title and description
/// Both title and description can be a Map (word -> color) or List (backward compatibility)
class HighlightWordsConfig
    implements JsonSerializable<HighlightWordsConfig> {
  final dynamic title; // Can be Map<String, String> (word -> color) or List<String>
  final dynamic description; // Can be Map<String, String> (word -> color) or List<String>

  HighlightWordsConfig({
    required this.title,
    required this.description,
  });

  @override
  factory HighlightWordsConfig.fromJson(Map<String, dynamic> json) {
    dynamic titleData;
    if (json['title'] != null) {
      if (json['title'] is Map) {
        // Map format: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4"}
        titleData = json['title'] as Map<String, dynamic>;
      } else if (json['title'] is List) {
        // List format: ["best", "deals"] - backward compatibility
        titleData = JsonParser.requireList<String>(
          json,
          'title',
          (item) => item.toString(),
        );
      }
    } else {
      titleData = <String>[];
    }

    dynamic descriptionData;
    if (json['description'] != null) {
      if (json['description'] is Map) {
        // Map format: {"the": "#FF6B35", "best": "#4ECDC4", "deal": "#FF6B35"}
        descriptionData = json['description'] as Map<String, dynamic>;
      } else if (json['description'] is List) {
        // List format: ["the", "best", "deal"] - backward compatibility
        descriptionData = JsonParser.requireList<String>(
          json,
          'description',
          (item) => item.toString(),
        );
      }
    } else {
      descriptionData = <String>[];
    }

    return HighlightWordsConfig(
      title: titleData,
      description: descriptionData,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
    };
  }

  @override
  void validate() {
    // No validation needed - empty lists/maps are allowed
  }
}

/// Configuration for secondary action (e.g., Sign in link)
class SecondaryActionConfig
    implements JsonSerializable<SecondaryActionConfig> {
  final String type; // e.g., "sign_in"
  final dynamic text; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic prefixText; // Can be Map<String, String> (multilocale) or String (backward compatibility)

  SecondaryActionConfig({
    required this.type,
    required this.text,
    required this.prefixText,
  });

  @override
  factory SecondaryActionConfig.fromJson(Map<String, dynamic> json) {
    final config = SecondaryActionConfig(
      type: JsonParser.requireString(json, 'type'),
      text: JsonParser.requireMultilocaleText(json, 'text'),
      prefixText: JsonParser.requireMultilocaleText(json, 'prefix_text'),
    );
    config.validate();
    return config;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'prefix_text': prefixText,
    };
  }

  @override
  void validate() {
    if (type.isEmpty) {
      throw FormatException('SecondaryActionConfig.type cannot be empty');
    }
    // Validate text - must be non-empty string or non-empty multilocale map
    if (text is String) {
      if ((text as String).isEmpty) {
        throw FormatException('SecondaryActionConfig.text cannot be empty');
      }
    } else if (text is Map<String, dynamic>) {
      if (text.isEmpty) {
        throw FormatException('SecondaryActionConfig.text multilocale map cannot be empty');
      }
      if (!text.containsKey('en')) {
        throw FormatException('SecondaryActionConfig.text multilocale map must contain "en" key');
      }
    } else {
      throw FormatException('SecondaryActionConfig.text must be a String or Map<String, String>');
    }
    // Validate prefixText - must be non-empty string or non-empty multilocale map
    if (prefixText is String) {
      if ((prefixText as String).isEmpty) {
        throw FormatException('SecondaryActionConfig.prefixText cannot be empty');
      }
    } else if (prefixText is Map<String, dynamic>) {
      if (prefixText.isEmpty) {
        throw FormatException('SecondaryActionConfig.prefixText multilocale map cannot be empty');
      }
      if (!prefixText.containsKey('en')) {
        throw FormatException('SecondaryActionConfig.prefixText multilocale map must contain "en" key');
      }
    } else {
      throw FormatException('SecondaryActionConfig.prefixText must be a String or Map<String, String>');
    }
  }
}

