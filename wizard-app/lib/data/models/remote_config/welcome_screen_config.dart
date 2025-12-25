import 'package:json_annotation/json_annotation.dart';

part 'welcome_screen_config.g.dart';

/// Configuration for the welcome/landing screen
/// Separate from onboarding flow screens to allow full customization
@JsonSerializable()
class WelcomeScreenConfig {
  final dynamic title; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic description; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final String? visual; // Optional: Lottie animation path or asset path
  @JsonKey(name: 'primary_button_text')
  final dynamic primaryButtonText; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  @JsonKey(name: 'glass_container')
  final GlassContainerConfig? glassContainer;
  @JsonKey(name: 'highlight_words')
  final HighlightWordsConfig? highlightWords;
  @JsonKey(name: 'secondary_action')
  final SecondaryActionConfig? secondaryAction;
  @JsonKey(name: 'highlight_color')
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

  factory WelcomeScreenConfig.fromJson(Map<String, dynamic> json) =>
      _$WelcomeScreenConfigFromJson(json);

  Map<String, dynamic> toJson() => _$WelcomeScreenConfigToJson(this);

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
@JsonSerializable()
class GlassContainerConfig {
  @JsonKey(name: 'blur_sigma')
  final double blurSigma;
  final String color; // Hex color string
  final double opacity;
  @JsonKey(name: 'border_radius')
  final double borderRadius;
  final double height;
  @JsonKey(name: 'icon_size')
  final double iconSize;
  @JsonKey(name: 'icon_opacity')
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

  factory GlassContainerConfig.fromJson(Map<String, dynamic> json) =>
      _$GlassContainerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$GlassContainerConfigToJson(this);

  void validate() {
    if (blurSigma < 0) {
      throw FormatException('GlassContainerConfig.blurSigma must be >= 0');
    }
    if (opacity < 0 || opacity > 1) {
      throw FormatException('GlassContainerConfig.opacity must be between 0 and 1');
    }
    if (borderRadius < 0) {
      throw FormatException('GlassContainerConfig.borderRadius must be >= 0');
    }
    if (height <= 0) {
      throw FormatException('GlassContainerConfig.height must be > 0');
    }
    if (iconSize <= 0) {
      throw FormatException('GlassContainerConfig.iconSize must be > 0');
    }
    if (iconOpacity < 0 || iconOpacity > 1) {
      throw FormatException('GlassContainerConfig.iconOpacity must be between 0 and 1');
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
@JsonSerializable()
class HighlightWordsConfig {
  final dynamic title; // Can be Map<String, String> (word -> color) or List<String>
  final dynamic description; // Can be Map<String, String> (word -> color) or List<String>

  HighlightWordsConfig({
    required this.title,
    required this.description,
  });

  factory HighlightWordsConfig.fromJson(Map<String, dynamic> json) {
    dynamic titleData;
    if (json['title'] != null) {
      if (json['title'] is Map) {
        titleData = json['title'] as Map<String, dynamic>;
      } else if (json['title'] is List) {
        titleData = (json['title'] as List).map((item) => item.toString()).toList();
      }
    } else {
      titleData = <String>[];
    }

    dynamic descriptionData;
    if (json['description'] != null) {
      if (json['description'] is Map) {
        descriptionData = json['description'] as Map<String, dynamic>;
      } else if (json['description'] is List) {
        descriptionData = (json['description'] as List).map((item) => item.toString()).toList();
      }
    } else {
      descriptionData = <String>[];
    }

    return HighlightWordsConfig(
      title: titleData,
      description: descriptionData,
    );
  }

  Map<String, dynamic> toJson() => _$HighlightWordsConfigToJson(this);

  void validate() {
    // No validation needed - empty lists/maps are allowed
  }
}

/// Configuration for secondary action (e.g., Sign in link)
@JsonSerializable()
class SecondaryActionConfig {
  final String type; // e.g., "sign_in"
  final dynamic text; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  @JsonKey(name: 'prefix_text')
  final dynamic prefixText; // Can be Map<String, String> (multilocale) or String (backward compatibility)

  SecondaryActionConfig({
    required this.type,
    required this.text,
    required this.prefixText,
  });

  factory SecondaryActionConfig.fromJson(Map<String, dynamic> json) =>
      _$SecondaryActionConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SecondaryActionConfigToJson(this);

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
