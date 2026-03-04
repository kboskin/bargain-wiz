import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/highlight_words_config.dart';
import 'package:appwizard/features/shared/data/models/validatable_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'welcome_screen_config.g.dart';

/// Configuration for the welcome/landing screen
/// Separate from onboarding flow screens to allow full customization
@JsonSerializable()
class WelcomeScreenConfig extends ValidatableEntity {
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  final String? visual; // Optional: Lottie animation path or asset path
  @JsonKey(name: 'primary_button_text', fromJson: _multilocaleFromJson)
  final dynamic primaryButtonText;
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

  factory WelcomeScreenConfig.fromJson(Map<String, dynamic> json) => _$WelcomeScreenConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$WelcomeScreenConfigToJson(this);

  @override
  void validate() {
    super.validate();
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
class GlassContainerConfig extends ValidatableEntity {
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

  @override
  void validate() {
    super.validate();
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


/// Configuration for secondary action (e.g., Sign in link)
@JsonSerializable()
class SecondaryActionConfig extends ValidatableEntity {
  final String type; // e.g., "sign_in"
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic text;
  @JsonKey(name: 'prefix_text', fromJson: _multilocaleFromJson)
  final dynamic prefixText;

  SecondaryActionConfig({
    required this.type,
    required this.text,
    required this.prefixText,
  });

  factory SecondaryActionConfig.fromJson(Map<String, dynamic> json) => _$SecondaryActionConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$SecondaryActionConfigToJson(this);

  @override
  void validate() {
    super.validate();
    if (type.isEmpty) {
      throw FormatException('SecondaryActionConfig.type cannot be empty');
    }
  }
}
