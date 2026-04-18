import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/highlight_words_config.dart';
import 'package:appwizard/features/shared/data/models/json_helpers.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/upload_progress_screen_config.dart';
import 'package:appwizard/features/shared/data/models/validatable_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_model.g.dart';

/// Alignment for side text annotation relative to the visual asset
enum SideTextAlignment {
  top,
  center,
  bottom,
  baseline;

  static SideTextAlignment fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'bottom':
        return SideTextAlignment.bottom;
      case 'center':
        return SideTextAlignment.center;
      case 'baseline':
        return SideTextAlignment.baseline;
      case 'top':
      default:
        return SideTextAlignment.top;
    }
  }
}

/// Structured metadata for onboarding screens
@JsonSerializable()
class OnboardingMetadata {

  OnboardingMetadata({
    this.highlightWords,
    this.highlightColor,
    this.textColor,
    this.description,
    this.sideTextAlignment,
    this.sideText,
    this.width,
    this.height,
    this.color,
    this.animation,
    this.animationColor,
    this.buttons,
    this.options,
    this.paywallConfigKey,
    this.paywallId,
    this.placeholder,
    this.imageSpacing,
    this.imageWidth,
    this.imageHeight,
    this.buttonVisual,
    this.buttonVisualWidth,
    this.buttonVisualHeight,
    this.buttonColor,
    this.glowColor,
    this.glowIntensity,
    this.buttonText,
    this.buttonStyle,
    this.subtext,
    this.raw,
  });

  factory OnboardingMetadata.fromJson(Map<String, dynamic> json) {
    // We pass the full json to the generated constructor as well to populate 'raw'
    return _$OnboardingMetadataFromJson({...json, 'raw': json});
  }
  @JsonKey(name: 'highlight_words')
  final HighlightWordsConfig? highlightWords;
  @JsonKey(name: 'highlight_color')
  final String? highlightColor;
  /// Base text color for title/description (hex string). When null, use onboarding_config.text_color or black.
  @JsonKey(name: 'text_color')
  final String? textColor;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description; // Optional supplemental description
  @JsonKey(name: 'side_text_alignment', fromJson: _sideTextAlignmentFromJson, toJson: _sideTextAlignmentToJson)
  final SideTextAlignment? sideTextAlignment;
  @JsonKey(name: 'side_text', fromJson: _multilocaleFromJson)
  final dynamic sideText;
  final double? width;
  final double? height;
  final String? color; // Brand/tint color
  final String? animation;
  @JsonKey(name: 'animation_color')
  final String? animationColor;
  final List<dynamic>? buttons;
  final List<dynamic>? options;
  @JsonKey(name: 'paywall_config_key')
  final String? paywallConfigKey;
  @JsonKey(name: 'paywall_id')
  final String? paywallId;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic placeholder;
  @JsonKey(name: 'image_spacing')
  final double? imageSpacing;
  @JsonKey(name: 'image_width')
  final double? imageWidth;
  @JsonKey(name: 'image_height')
  final double? imageHeight;
  @JsonKey(name: 'button_visual')
  final String? buttonVisual;
  @JsonKey(name: 'button_visual_width')
  final double? buttonVisualWidth;
  @JsonKey(name: 'button_visual_height')
  final double? buttonVisualHeight;
  @JsonKey(name: 'button_color')
  final String? buttonColor;
  @JsonKey(name: 'glow_color')
  final String? glowColor;
  @JsonKey(name: 'glow_intensity')
  final double? glowIntensity;
  @JsonKey(name: 'button_text', fromJson: _multilocaleFromJson)
  final dynamic buttonText;
  @JsonKey(name: 'button_style')
  final String? buttonStyle;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic subtext;
  @JsonKey(includeFromJson: true, includeToJson: false)
  final Map<String, dynamic>? raw;

  Map<String, dynamic> toJson() => raw ?? _$OnboardingMetadataToJson(this);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  static SideTextAlignment? _sideTextAlignmentFromJson(String? value) =>
      value != null ? SideTextAlignment.fromString(value) : null;

  static String? _sideTextAlignmentToJson(SideTextAlignment? alignment) =>
      alignment?.name;

  static OnboardingMetadata? fromOptionalMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return OnboardingMetadata.fromJson(map);
  }
}

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
abstract class OnboardingModel extends ValidatableEntity {
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
      case OnboardingScreenType.imageList:
        return ImageListScreenModel.fromJson(json);
      case OnboardingScreenType.referralCode:
        return ReferralCodeScreenModel.fromJson(json);
      case OnboardingScreenType.paywall:
        return PaywallScreenModel.fromJson(json);
      case OnboardingScreenType.warmup:
        return WarmupScreenModel.fromJson(json);
      case OnboardingScreenType.dataUpload:
        return DataUploadScreenModel.fromJson(json);
      case OnboardingScreenType.createAccount:
        return CreateAccountScreenModel.fromJson(json);
      case OnboardingScreenType.sliderLottie:
        return SliderLottieScreenModel.fromJson(json);
    }
  }

  final dynamic title; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final dynamic description; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final dynamic nextButtonText; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final AnswerStructure? answerStructure;
  final bool showTopBar; // Controls visibility of progress bar and back button

  /// Whether to show the next/bottom button. From RC "show_next_button"; default true.
  bool get showNextButton => true;

  /// Get the screen type as an enum
  OnboardingScreenType get type;

  /// Optional metadata (highlight words, text color, etc.). Subclasses with metadata override this.
  OnboardingMetadata? get metadata => null;

  Map<String, dynamic> toJson();

  @override
  void validate() {
    super.validate();
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
class AnswerStructure extends ValidatableEntity {
  AnswerStructure({
    required this.answerKeyName,
  });

  factory AnswerStructure.fromJson(Map<String, dynamic> json) =>
      _$AnswerStructureFromJson(json);
  @JsonKey(name: 'answer_key_name')
  final String answerKeyName;

  Map<String, dynamic> toJson() => _$AnswerStructureToJson(this);

  @override
  void validate() {
    super.validate();
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

  EngagementScreenModel({
    required this.title,
    this.description,
    this.visual,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }): super(title: title);

  factory EngagementScreenModel.fromJson(Map<String, dynamic> json) => _$EngagementScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final String? visual; // Lottie resource path or asset path
  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.engagement;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$EngagementScreenModelToJson(this), type);
}

/// Option for select-type screens
@JsonSerializable()
class OnboardingOption extends ValidatableEntity {
  OnboardingOption({
    required this.label,
    this.value,
    this.icon,
    this.tintColor,
    this.metadata,
  });

  factory OnboardingOption.fromJson(Map<String, dynamic> json) => _$OnboardingOptionFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic label; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic value; // Can be Map<String, String> (multilocale) or String (backward compatibility), optional
  final String? icon; // Material icon name (e.g., "tiktok", "youtube", "search", "store")
  @JsonKey(name: 'tint_color')
  final String? tintColor; // Optional hex color string for brand/tint color (e.g., "#FF6600")
  final OnboardingMetadata? metadata;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$OnboardingOptionToJson(this);

  @override
  void validate() {
    super.validate();
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
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SelectScreenModel extends OnboardingModel {

  SelectScreenModel({
    required this.title,
    required this.description,
    required this.options,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }): super(title: title);

  factory SelectScreenModel.fromJson(Map<String, dynamic> json) => _$SelectScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final List<OnboardingOption> options;
  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.select;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

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

  SliderOption({
    required this.value,
    required this.label,
    this.animation,
    this.animationWidth,
    this.animationHeight,
  });

  factory SliderOption.fromJson(Map<String, dynamic> json) => _$SliderOptionFromJson(json);
  final double value;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic label; // Can be Map<String, String> (multilocale) or String (backward compatibility)
  final String? animation;
  @JsonKey(name: 'animation_width')
  final double? animationWidth;
  @JsonKey(name: 'animation_height')
  final double? animationHeight;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$SliderOptionToJson(this);
}

/// Model for slider-type onboarding screens
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SliderScreenModel extends OnboardingModel {

  SliderScreenModel({
    required this.title,
    this.description,
    required this.options,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }) : super(title: title);

  factory SliderScreenModel.fromJson(Map<String, dynamic> json) {
    // Note: Slider possibilities are complex because options can be in metadata
    // We'll handle the metadata.options extraction if needed, but the basic model
    // should be parseable via _$SliderScreenModelFromJson.
    final model = _$SliderScreenModelFromJson(json);

    // Check if this is a discrete slider with options in metadata
    if (model.options.isEmpty) {
      final metadataMap = json['metadata'];
      if (metadataMap is Map && metadataMap.containsKey('options')) {
        final optionsList = metadataMap['options'];
        if (optionsList is List) {
          final options = optionsList
              .map((item) => SliderOption.fromJson(item as Map<String, dynamic>))
              .toList();
          return SliderScreenModel(
            title: model.title,
            description: model.description,
            options: options,
            metadata: model.metadata,
            nextButtonText: model.nextButtonText,
            answerStructure: model.answerStructure,
            showTopBar: model.showTopBar,
          );
        }
      }
    }

    return model;
  }
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  @JsonKey(fromJson: _sliderOptionsFromJson)
  final List<SliderOption> options;
  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.slider;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  static List<SliderOption> _sliderOptionsFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .map((final e) => SliderOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$SliderScreenModelToJson(this);
    
    // Handle special case: options are stored in metadata.options
    if (options.isNotEmpty) {
      final metadataMap = metadata?.toJson() ?? {};
      metadataMap['options'] = options.map((e) => e.toJson()).toList();
      json['metadata'] = metadataMap;
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
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class PermissionScreenModel extends OnboardingModel {

  PermissionScreenModel({
    required this.title,
    this.description,
    required this.subtype,
    this.visual,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }) : super(title: title);

  factory PermissionScreenModel.fromJson(final Map<String, dynamic> json) => _$PermissionScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final String subtype; // e.g., "notifications"
  final String? visual; // Optional Lottie resource path or asset path for frame/animation
  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.permission;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

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

/// Model for image list-type onboarding screens
/// Displays a title and scrollable list of images
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class ImageListScreenModel extends OnboardingModel {

  ImageListScreenModel({
    required this.title,
    this.description,
    required this.images,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }) : super(title: title);

  factory ImageListScreenModel.fromJson(Map<String, dynamic> json) => _$ImageListScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final List<String> images; // List of image paths (Lottie, SVG, or regular images)
  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.imageList;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() {
    final json = _$ImageListScreenModelToJson(this);
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    if (images.isEmpty) {
      throw FormatException('ImageListScreenModel.images cannot be empty');
    }
  }
}

/// Model for referral code-type onboarding screens
/// Displays a referral code that users can copy or share
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class ReferralCodeScreenModel extends OnboardingModel {

  ReferralCodeScreenModel({
    required this.title,
    this.description,
    this.referralCode,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }) : super(title: title);

  factory ReferralCodeScreenModel.fromJson(Map<String, dynamic> json) => _$ReferralCodeScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  @JsonKey(name: 'referral_code')
  final String? referralCode; // The referral code to display (can be null if fetched from service)
  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.referralCode;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() {
    final json = _$ReferralCodeScreenModelToJson(this);
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    // Referral code can be null if it's fetched from a service
  }
}

/// Model for paywall reference screen (lightweight placeholder)
/// Contains only metadata pointing to separate paywall config
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class PaywallScreenModel extends OnboardingModel {

  PaywallScreenModel({
    required this.title, // Required by base class but not used for paywall
    this.description,
    this.metadata,
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = true,
  }): super(title: title);

  factory PaywallScreenModel.fromJson(Map<String, dynamic> json) => _$PaywallScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.paywall;

  /// Get paywall config key from metadata, default to "paywall_config"
  /// Supports both "paywall_config_key" and "paywall_id" for flexibility
  String get paywallConfigKey {
    return metadata?.paywallConfigKey ?? metadata?.paywallId ?? 'paywall_config';
  }

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$PaywallScreenModelToJson(this), type);

  @override
  void validate() {
    super.validate();
    // Paywall screen is just a reference, minimal validation
  }
}

/// Model for data upload progress screen (upload user data to backend).
/// Config is inline like other onboarding screens: [visual] and [metadata]
/// (texts, text_interval_seconds, progress_ramp_seconds).
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class DataUploadScreenModel extends OnboardingModel {
  DataUploadScreenModel({
    required this.title,
    this.description,
    this.visual,
    this.metadata,
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = false,
    this.showNextButton = false,
  }) : super(title: title);

  factory DataUploadScreenModel.fromJson(Map<String, dynamic> json) =>
      _$DataUploadScreenModelFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  /// Lottie asset path (e.g. assets/lottie/pot.json), same pattern as engagement/warmup.
  final String? visual;

  final OnboardingMetadata? metadata;

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: false)
  @override
  final bool showTopBar;

  @JsonKey(name: 'show_next_button', defaultValue: false)
  @override
  final bool showNextButton;

  @override
  OnboardingScreenType get type => OnboardingScreenType.dataUpload;

  /// Builds upload progress config from this screen's inline config (visual + metadata).
  /// Returns null if lottie asset is missing (screen not fully configured).
  UploadProgressScreenConfig? toUploadProgressConfig() {
    final raw = metadata?.raw;
    final lottieAsset = visual ?? (raw?['lottie_asset'] as String?);
    if (lottieAsset == null || lottieAsset.isEmpty) return null;
    final textsRaw = raw?['texts'];
    final texts = _parseUploadTexts(textsRaw);
    final textIntervalSeconds =
        (raw?['text_interval_seconds'] as num?)?.toDouble() ?? 2.5;
    final progressRampSeconds =
        (raw?['progress_ramp_seconds'] as num?)?.toDouble() ?? 5.0;
    return UploadProgressScreenConfig(
      lottieAsset: lottieAsset,
      texts: texts,
      textIntervalSeconds: textIntervalSeconds,
      progressRampSeconds: progressRampSeconds,
    );
  }

  static List<dynamic> _parseUploadTexts(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .map((e) =>
            e != null && e is Map<String, dynamic>
                ? MultilocaleText.fromJson(e)
                : null)
        .whereType<MultilocaleText>()
        .toList();
  }

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$DataUploadScreenModelToJson(this), type);

  @override
  void validate() {
    super.validate();
  }
}

/// Model for create-account / sign-in onboarding screen.
/// Shows Login with Google, optionally Sign in with Apple, and Continue (skip).
/// Button labels and which platforms show each button come from remote config.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class CreateAccountScreenModel extends OnboardingModel {
  CreateAccountScreenModel({
    required this.title,
    this.description,
    this.nextButtonText,
    this.showTopBar = true,
    this.googleButtonLabel,
    this.appleButtonLabel,
    this.googlePlatforms,
    this.applePlatforms,
  }) : super(title: title);

  factory CreateAccountScreenModel.fromJson(Map<String, dynamic> json) =>
      _$CreateAccountScreenModelFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  /// Button label for Google sign-in (e.g. "Google"). Multilocale; default "Google".
  @JsonKey(name: 'google_button_label', fromJson: _multilocaleFromJson)
  final dynamic googleButtonLabel;

  /// Button label for Apple sign-in (e.g. "Apple"). Multilocale; default "Apple".
  @JsonKey(name: 'apple_button_label', fromJson: _multilocaleFromJson)
  final dynamic appleButtonLabel;

  /// Platforms where Google button is shown: ["android", "ios", "web", "macos", "windows", "linux"].
  /// Null or empty = show on all platforms.
  @JsonKey(name: 'google_platforms')
  final List<String>? googlePlatforms;

  /// Platforms where Apple button is shown. Null or empty = show on all platforms.
  @JsonKey(name: 'apple_platforms')
  final List<String>? applePlatforms;

  @override
  OnboardingScreenType get type => OnboardingScreenType.createAccount;

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$CreateAccountScreenModelToJson(this), type);
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
    required T Function(ImageListScreenModel) imageList,
    required T Function(ReferralCodeScreenModel) referralCode,
    required T Function(PaywallScreenModel) paywall,
    required T Function(WarmupScreenModel) warmup,
    required T Function(DataUploadScreenModel) dataUpload,
    required T Function(CreateAccountScreenModel) createAccount,
    required T Function(SliderLottieScreenModel) sliderLottie,
    T Function()? orElse,
  }) {
    if (this is EngagementScreenModel) {
      return engagement(this as EngagementScreenModel);
    } else if (this is CreateAccountScreenModel) {
      return createAccount(this as CreateAccountScreenModel);
    } else if (this is SelectScreenModel) {
      return select(this as SelectScreenModel);
    } else if (this is SliderScreenModel) {
      return slider(this as SliderScreenModel);
    } else if (this is PermissionScreenModel) {
      return permission(this as PermissionScreenModel);
    } else if (this is ImageListScreenModel) {
      return imageList(this as ImageListScreenModel);
    } else if (this is ReferralCodeScreenModel) {
      return referralCode(this as ReferralCodeScreenModel);
    } else if (this is PaywallScreenModel) {
      return paywall(this as PaywallScreenModel);
    } else if (this is WarmupScreenModel) {
      return warmup(this as WarmupScreenModel);
    } else if (this is DataUploadScreenModel) {
      return dataUpload(this as DataUploadScreenModel);
    } else if (this is SliderLottieScreenModel) {
      return sliderLottie(this as SliderLottieScreenModel);
    } else {
      return orElse?.call() ?? 
        (throw FormatException('Unknown screen type: ${runtimeType}')) as T;
    }
  }
}

/// Model for warmup-type onboarding screens
/// Displays an image and text to motivate the user
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class WarmupScreenModel extends OnboardingModel {

  factory WarmupScreenModel.fromJson(final Map<String, dynamic> json) => _$WarmupScreenModelFromJson(json);

  WarmupScreenModel({
    required this.title,
    this.description,
    this.visual,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }): super(title: title);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final String? visual; // Lottie resource path or asset path
  final OnboardingMetadata? metadata; // Typed metadata

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.warmup;

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$WarmupScreenModelToJson(this), type);
}

/// Model for slider_lottie-type onboarding screens.
/// User can select a percentage (0-100) by interacting with a Lottie animation.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SliderLottieScreenModel extends OnboardingModel {
  SliderLottieScreenModel({
    required this.title,
    this.description,
    this.visual,
    this.metadata,
    required this.nextButtonText,
    required this.answerStructure,
    this.showTopBar = true,
  }) : super(title: title);

  factory SliderLottieScreenModel.fromJson(Map<String, dynamic> json) =>
      _$SliderLottieScreenModelFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  /// Lottie asset path (e.g. assets/lottie/lottie_tube.json).
  final String? visual;

  final OnboardingMetadata? metadata;

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'answer_structure')
  @override
  final AnswerStructure? answerStructure;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  @override
  OnboardingScreenType get type => OnboardingScreenType.sliderLottie;

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$SliderLottieScreenModelToJson(this), type);
}
