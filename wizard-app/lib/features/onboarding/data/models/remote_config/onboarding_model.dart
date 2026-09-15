import 'dart:math' as math;

import 'package:appwizard/features/onboarding/data/models/remote_config/highlight_words_config.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/upload_progress_screen_config.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
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

dynamic _multilocaleFromJson(dynamic json) =>
    json != null ? MultilocaleText.fromJson(json) : null;

/// Structured metadata for onboarding screens. Unknown keys are kept in [raw]
/// so templates can read screen-specific settings (min_selected, savings_pill, …).
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
    this.short,
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
  /// Base text color for title/description (hex string). When null, use onboarding_config.text_color or ink.
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
  /// Short label (e.g. vibe chip "Friendly"). String or multilocale map.
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic short;
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

  /// Typed access to any raw metadata value.
  T? rawValue<T>(String key) {
    final v = raw?[key];
    return v is T ? v : null;
  }

  double? rawDouble(String key) => (raw?[key] as num?)?.toDouble();
  int? rawInt(String key) => (raw?[key] as num?)?.toInt();
  bool rawBool(String key, {bool fallback = false}) => raw?[key] is bool ? raw![key] as bool : fallback;

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
  if (json.containsKey('highlightWords')) {
    json['highlight_words'] = json.remove('highlightWords');
  }
  if (json.containsKey('highlightColor')) {
    json['highlight_color'] = json.remove('highlightColor');
  }

  // Remove null values (matching includeIfNull: false behavior)
  json.removeWhere((key, value) => value == null);

  return json;
}

/// Abstract base class for all onboarding screen models.
/// Each screen type (multi_select, select, slider, …) extends this class.
/// Note: Abstract classes can't use @JsonSerializable, so we keep the factory pattern.
abstract class OnboardingModel extends ValidatableEntity {
  OnboardingModel({
    required this.title,
    this.description,
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  });

  /// Factory constructor that parses JSON and returns the appropriate model type
  factory OnboardingModel.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    if (typeString == null) {
      throw const FormatException('Required field "type" is missing');
    }

    final screenType = OnboardingScreenType.fromString(typeString);

    switch (screenType) {
      case OnboardingScreenType.engagement:
        return EngagementScreenModel.fromJson(json);
      case OnboardingScreenType.select:
        return SelectScreenModel.fromJson(json);
      case OnboardingScreenType.multiSelect:
        return MultiSelectScreenModel.fromJson(json);
      case OnboardingScreenType.selectGroup:
        return SelectGroupScreenModel.fromJson(json);
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

  final dynamic title; // MultilocaleText (multilocale map or String)
  final dynamic description; // MultilocaleText, optional
  final dynamic nextButtonText; // MultilocaleText, optional
  final AnswerStructure? answerStructure;
  final bool showTopBar; // Controls visibility of progress bar and back button

  /// Screen-level `highlight_words` ({"title": {...}, "description": {...}}).
  /// Prefer [effectiveHighlightWords], which falls back to `metadata.highlight_words`.
  final HighlightWordsConfig? highlightWords;

  /// Screen-level default highlight color (hex). Prefer [effectiveHighlightColor].
  final String? highlightColor;

  /// Whether to show the next/bottom button. From RC "show_next_button"; default true.
  bool get showNextButton => true;

  /// Get the screen type as an enum
  OnboardingScreenType get type;

  /// Optional metadata (highlight words, text color, etc.). Subclasses with metadata override this.
  OnboardingMetadata? get metadata => null;

  /// Highlight words: screen-level first, then `metadata.highlight_words`.
  HighlightWordsConfig? get effectiveHighlightWords =>
      highlightWords ?? metadata?.highlightWords;

  /// Highlight color: screen-level first, then `metadata.highlight_color`.
  String? get effectiveHighlightColor =>
      highlightColor ?? metadata?.highlightColor;

  /// Title highlight map/list for the shell (`{"slipped away": "#C47A00"}`).
  dynamic get titleHighlights => effectiveHighlightWords?.title;

  /// Description highlight map/list for the shell.
  dynamic get descriptionHighlights => effectiveHighlightWords?.description;

  /// All answer keys this screen writes (empty for informational screens).
  List<String> get answerKeys {
    final k = answerStructure?.answerKeyName;
    return k == null || k.isEmpty ? const [] : [k];
  }

  /// English title used for stored answers / logging.
  String get titleForStorage {
    final dynamic raw = title is MultilocaleText ? (title as MultilocaleText).toJson() : title;
    if (raw is Map) {
      return raw['en']?.toString() ?? (raw.values.isEmpty ? 'Onboarding' : raw.values.first.toString());
    }
    return raw?.toString() ?? 'Onboarding';
  }

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
    } else if (title is! MultilocaleText) {
      throw FormatException('$runtimeType.title must be a String or Map<String, String>');
    }
    answerStructure?.validate();
  }
}

/// Answer structure configuration
@JsonSerializable()
class AnswerStructure extends ValidatableEntity {
  AnswerStructure({
    required this.answerKeyName,
    this.multi = false,
  });

  factory AnswerStructure.fromJson(Map<String, dynamic> json) =>
      _$AnswerStructureFromJson(json);
  @JsonKey(name: 'answer_key_name')
  final String answerKeyName;

  /// True when the answer is a list of values (multi_select).
  @JsonKey(defaultValue: false)
  final bool multi;

  Map<String, dynamic> toJson() => _$AnswerStructureToJson(this);

  @override
  void validate() {
    super.validate();
    if (answerKeyName.isEmpty) {
      throw const FormatException('AnswerStructure.answerKeyName cannot be empty');
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
    required this.nextButtonText,
    required this.answerStructure,
    this.description,
    this.visual,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }): super(title: title);

  factory EngagementScreenModel.fromJson(Map<String, dynamic> json) => _$EngagementScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final String? visual; // Lottie resource path or asset path
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.engagement;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$EngagementScreenModelToJson(this), type);
}

/// Option for select / multi_select / select_group screens
@JsonSerializable()
class OnboardingOption extends ValidatableEntity {
  OnboardingOption({
    required this.label,
    this.value,
    this.iconRaw,
    this.tintColor,
    this.metadata,
  });

  factory OnboardingOption.fromJson(Map<String, dynamic> json) => _$OnboardingOptionFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic label; // MultilocaleText
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic value; // MultilocaleText (plain string in practice), optional
  /// Raw icon config (legacy icon name or `{code, font}` map). Resolved to an
  /// `IconConfig` in the presentation layer so the data model stays free of icon-font packages.
  @JsonKey(name: 'icon')
  final dynamic iconRaw;
  @JsonKey(name: 'tint_color')
  final String? tintColor; // Optional hex color string for brand/tint color (e.g., "#FF6600")
  final OnboardingMetadata? metadata;

  /// Option accent color (hex): `metadata.color`, then `tint_color`.
  String? get colorHex {
    final c = metadata?.color;
    if (c != null && c.isNotEmpty) return c;
    if (tintColor != null && tintColor!.isNotEmpty) return tintColor;
    return null;
  }

  /// Secondary line under the label (MultilocaleText or null).
  dynamic get subtext => metadata?.subtext;

  /// Stable value used as the stored answer (falls back to the raw label).
  String get storedValue {
    final dynamic v = value is MultilocaleText ? (value as MultilocaleText).toJson() : value;
    if (v is String && v.isNotEmpty) return v;
    if (v is Map && v['en'] is String) return v['en'] as String;
    final dynamic l = label is MultilocaleText ? (label as MultilocaleText).toJson() : label;
    if (l is Map && l['en'] is String) return l['en'] as String;
    return l?.toString() ?? '';
  }

  /// Whether an icon is configured for this option (retired select screens: gender, source…).
  bool get hasIcon => iconRaw != null && iconRaw.toString().isNotEmpty;

  Map<String, dynamic> toJson() => _$OnboardingOptionToJson(this);

  @override
  void validate() {
    super.validate();
    if (label is String) {
      if ((label as String).isEmpty) {
        throw const FormatException('OnboardingOption.label cannot be empty');
      }
    } else if (label is Map<String, dynamic>) {
      if (label.isEmpty) {
        throw const FormatException('OnboardingOption.label multilocale map cannot be empty');
      }
      if (!label.containsKey('en')) {
        throw const FormatException('OnboardingOption.label multilocale map must contain "en" key');
      }
    } else if (label is! MultilocaleText) {
      throw const FormatException('OnboardingOption.label must be a String or Map<String, String>');
    }
  }
}

/// Model for select-type onboarding screens (single choice)
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SelectScreenModel extends OnboardingModel {

  SelectScreenModel({
    required this.title,
    required this.description,
    required this.options,
    required this.nextButtonText,
    required this.answerStructure,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }): super(title: title);

  factory SelectScreenModel.fromJson(Map<String, dynamic> json) => _$SelectScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final List<OnboardingOption> options;
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.select;

  /// When true the CTA stays disabled until the user taps an option, even if a default exists.
  bool get requireExplicitTap => metadata?.rawBool('require_explicit_tap') ?? false;

  /// Optional default option value (`metadata.default_value`).
  String? get defaultValue => metadata?.raw?['default_value']?.toString();

  @override
  Map<String, dynamic> toJson() {
    final json = _$SelectScreenModelToJson(this);
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    if (options.isEmpty) {
      throw const FormatException('SelectScreenModel.options cannot be empty');
    }
    for (final option in options) {
      option.validate();
    }
  }
}

/// Model for multi_select onboarding screens (checkbox rows, e.g. "money leaks").
/// Answer: `List<String>` of option values; first pick is the primary hurdle.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class MultiSelectScreenModel extends OnboardingModel {
  MultiSelectScreenModel({
    required this.title,
    required this.options,
    required this.nextButtonText,
    required this.answerStructure,
    this.description,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }) : super(title: title);

  factory MultiSelectScreenModel.fromJson(Map<String, dynamic> json) =>
      _$MultiSelectScreenModelFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final List<OnboardingOption> options;
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.multiSelect;

  /// Minimum number of picks before the CTA enables (`metadata.min_selected`, default 1).
  int get minSelected => metadata?.rawInt('min_selected') ?? 1;

  /// Reassurance panel texts indexed by pick count (1, 2, 3+).
  List<MultilocaleText> get reassuranceByCount {
    final raw = metadata?.raw?['reassurance_by_count'];
    if (raw is! List) return const [];
    return raw.where((e) => e != null).map(MultilocaleText.fromJson).toList();
  }

  /// Reassurance text for [count] picks: `reassurance_by_count[min(count-1, last)]`.
  MultilocaleText? reassuranceFor(int count) {
    final list = reassuranceByCount;
    if (list.isEmpty || count <= 0) return null;
    return list[math.min(count - 1, list.length - 1)];
  }

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$MultiSelectScreenModelToJson(this), type);

  @override
  void validate() {
    super.validate();
    if (options.isEmpty) {
      throw const FormatException('MultiSelectScreenModel.options cannot be empty');
    }
    for (final option in options) {
      option.validate();
    }
  }
}

/// One chip group inside a select_group screen. Writes [answerKeyName].
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SelectGroup extends ValidatableEntity {
  SelectGroup({
    required this.label,
    required this.answerKeyName,
    required this.options,
  });

  factory SelectGroup.fromJson(Map<String, dynamic> json) => _$SelectGroupFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic label; // MultilocaleText

  @JsonKey(name: 'answer_key_name')
  final String answerKeyName;

  final List<OnboardingOption> options;

  Map<String, dynamic> toJson() => _$SelectGroupToJson(this);

  @override
  void validate() {
    super.validate();
    if (answerKeyName.isEmpty) {
      throw const FormatException('SelectGroup.answerKeyName cannot be empty');
    }
    if (options.isEmpty) {
      throw const FormatException('SelectGroup.options cannot be empty');
    }
    for (final o in options) {
      o.validate();
    }
  }
}

/// Model for select_group onboarding screens: several chip groups on one page,
/// each writing its own answer key (e.g. favorite_marketplace + deals_per_month).
/// Answer: `Map<String, dynamic>` of `{answer_key_name: value}`.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SelectGroupScreenModel extends OnboardingModel {
  SelectGroupScreenModel({
    required this.title,
    required this.groups,
    required this.nextButtonText,
    this.description,
    this.metadata,
    this.answerStructure,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }) : super(title: title);

  factory SelectGroupScreenModel.fromJson(Map<String, dynamic> json) =>
      _$SelectGroupScreenModelFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final List<SelectGroup> groups;
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.selectGroup;

  @override
  List<String> get answerKeys => groups.map((g) => g.answerKeyName).toList();

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$SelectGroupScreenModelToJson(this), type);

  @override
  void validate() {
    super.validate();
    if (groups.isEmpty) {
      throw const FormatException('SelectGroupScreenModel.groups cannot be empty');
    }
    for (final g in groups) {
      g.validate();
    }
  }
}

/// Slider stop with value, label, optional subtext / savings / Lottie
@JsonSerializable()
class SliderOption {

  SliderOption({
    required this.value,
    required this.label,
    this.subtext,
    this.animation,
    this.animationWidth,
    this.animationHeight,
    this.savingsLow,
    this.savingsHigh,
    this.scale,
  });

  factory SliderOption.fromJson(Map<String, dynamic> json) => _$SliderOptionFromJson(json);
  final double value;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic label; // MultilocaleText
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic subtext; // MultilocaleText, optional
  final String? animation;
  @JsonKey(name: 'animation_width')
  final double? animationWidth;
  @JsonKey(name: 'animation_height')
  final double? animationHeight;
  @JsonKey(name: 'savings_low')
  final int? savingsLow;
  @JsonKey(name: 'savings_high')
  final int? savingsHigh;
  /// Visual scale of the Lottie for this stop (0.7 / 0.9 / 1.1).
  final double? scale;

  /// Integer answer value (deal size buckets are ints: 50 / 550 / 5000).
  int get intValue => value.round();

  /// "$lo–hi" or null when savings are not configured.
  String? get savingsRange =>
      savingsLow != null && savingsHigh != null ? '\$$savingsLow–$savingsHigh' : null;

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
    required this.options,
    required this.nextButtonText,
    required this.answerStructure,
    this.description,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }) : super(title: title);

  factory SliderScreenModel.fromJson(Map<String, dynamic> json) {
    final model = _$SliderScreenModelFromJson(json);

    // Discrete slider: options live in metadata.options
    if (model.options.isEmpty) {
      final metadataMap = json['metadata'];
      if (metadataMap is Map && metadataMap.containsKey('options')) {
        final optionsList = metadataMap['options'];
        if (optionsList is List) {
          final options = optionsList
              .map((item) => SliderOption.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
          return SliderScreenModel(
            title: model.title,
            description: model.description,
            options: options,
            metadata: model.metadata,
            nextButtonText: model.nextButtonText,
            answerStructure: model.answerStructure,
            showTopBar: model.showTopBar,
            highlightWords: model.highlightWords,
            highlightColor: model.highlightColor,
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
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.slider;

  /// Options sorted by value.
  List<SliderOption> get sortedOptions =>
      List<SliderOption>.from(options)..sort((a, b) => a.value.compareTo(b.value));

  /// Pill template with `{savings}` placeholder (`metadata.savings_pill`).
  dynamic get savingsPill {
    final raw = metadata?.raw?['savings_pill'];
    return raw == null ? null : MultilocaleText.fromJson(raw);
  }

  /// Default stop index (`metadata.default_index`), clamped to the option range.
  int get defaultIndex {
    if (options.isEmpty) return 0;
    final i = metadata?.rawInt('default_index') ?? 0;
    return i.clamp(0, options.length - 1);
  }

  static List<SliderOption> _sliderOptionsFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .map((final e) => SliderOption.fromJson(Map<String, dynamic>.from(e as Map)))
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
    if (options.isEmpty && metadata == null) {
      throw const FormatException(
        'SliderScreenModel must have either options or metadata',
      );
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
    required this.subtype,
    required this.nextButtonText,
    required this.answerStructure,
    this.description,
    this.visual,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }) : super(title: title);

  factory PermissionScreenModel.fromJson(final Map<String, dynamic> json) => _$PermissionScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  @JsonKey(defaultValue: 'notifications')
  final String subtype; // e.g., "notifications"
  final String? visual; // Optional Lottie resource path or asset path for frame/animation
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.permission;

  @override
  Map<String, dynamic> toJson() {
    final json = _$PermissionScreenModelToJson(this);
    json['subtype'] = subtype;
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    if (subtype.isEmpty) {
      throw const FormatException('PermissionScreenModel.subtype cannot be empty');
    }
  }
}

/// Model for image list-type onboarding screens
/// Displays a title and scrollable list of images (optionally with per-row title/subtitle rows).
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class ImageListScreenModel extends OnboardingModel {

  ImageListScreenModel({
    required this.title,
    required this.images,
    required this.nextButtonText,
    required this.answerStructure,
    this.description,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }) : super(title: title);

  factory ImageListScreenModel.fromJson(Map<String, dynamic> json) => _$ImageListScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final List<String> images; // List of image paths (Lottie, SVG, or regular images)
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.imageList;

  /// Optional row texts (`metadata.rows`: `[{"title": ..., "subtitle": ...}]`) aligned with [images].
  List<Map<String, dynamic>> get rows {
    final raw = metadata?.raw?['rows'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$ImageListScreenModelToJson(this);
    return _fixOnboardingModelJsonKeys(json, type);
  }

  @override
  void validate() {
    super.validate();
    if (images.isEmpty) {
      throw const FormatException('ImageListScreenModel.images cannot be empty');
    }
  }
}

/// Model for referral code-type onboarding screens
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class ReferralCodeScreenModel extends OnboardingModel {

  ReferralCodeScreenModel({
    required this.title,
    required this.nextButtonText,
    required this.answerStructure,
    this.description,
    this.referralCode,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
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
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.referralCode;

  /// Input placeholder (`metadata.placeholder`), MultilocaleText or null.
  dynamic get placeholder => metadata?.placeholder;

  @override
  Map<String, dynamic> toJson() {
    final json = _$ReferralCodeScreenModelToJson(this);
    return _fixOnboardingModelJsonKeys(json, type);
  }
}

/// Model for paywall reference screen (retired from the default order, still supported).
/// Contains only metadata pointing to separate paywall config.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class PaywallScreenModel extends OnboardingModel {

  PaywallScreenModel({
    required this.title,
    this.description,
    this.metadata,
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }): super(title: title);

  factory PaywallScreenModel.fromJson(Map<String, dynamic> json) => _$PaywallScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.paywall;

  /// Get paywall config key from metadata, default to "paywall_config"
  String get paywallConfigKey =>
      metadata?.paywallConfigKey ?? metadata?.paywallId ?? 'paywall_config';

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$PaywallScreenModelToJson(this), type);

  @override
  void validate() {
    // Paywall screen is a reference only; title is optional.
    answerStructure?.validate();
  }
}

/// Model for data upload progress screen (upload user data to backend).
/// Config is inline like other onboarding screens: [visual] and [metadata]
/// (texts, text_interval_seconds, progress_ramp_seconds, done_text, done_hold_seconds, progress_gradient).
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class DataUploadScreenModel extends OnboardingModel {
  DataUploadScreenModel({
    this.title,
    this.description,
    this.visual,
    this.metadata,
    this.nextButtonText,
    this.answerStructure,
    this.showTopBar = false,
    this.showNextButton = false,
    this.highlightWords,
    this.highlightColor,
  }) : super(title: title ?? const MultilocaleText('Setting up'));

  factory DataUploadScreenModel.fromJson(Map<String, dynamic> json) =>
      _$DataUploadScreenModelFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  /// Lottie asset path (e.g. assets/lottie/pot.json).
  final String? visual;

  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.dataUpload;

  /// Builds upload progress config from this screen's inline config (visual + metadata).
  /// Returns null if the Lottie asset is missing (screen not fully configured).
  UploadProgressScreenConfig? toUploadProgressConfig() {
    final raw = metadata?.raw;
    final lottieAsset = visual ?? (raw?['lottie_asset'] as String?);
    if (lottieAsset == null || lottieAsset.isEmpty) return null;
    final texts = _parseUploadTexts(raw?['texts']);
    final gradientRaw = raw?['progress_gradient'];
    return UploadProgressScreenConfig(
      lottieAsset: lottieAsset,
      texts: texts,
      textIntervalSeconds: (raw?['text_interval_seconds'] as num?)?.toDouble() ?? 2.5,
      progressRampSeconds: (raw?['progress_ramp_seconds'] as num?)?.toDouble() ?? 5.0,
      doneText: raw?['done_text'] != null ? MultilocaleText.fromJson(raw!['done_text']) : null,
      doneHoldSeconds: (raw?['done_hold_seconds'] as num?)?.toDouble() ?? 1.4,
      progressGradient: gradientRaw is List ? gradientRaw.map((e) => e.toString()).toList() : null,
    );
  }

  static List<dynamic> _parseUploadTexts(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .where((e) => e != null)
        .map(MultilocaleText.fromJson)
        .toList();
  }

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$DataUploadScreenModelToJson(this), type);

  @override
  void validate() {
    // Title is optional for the upload screen.
    answerStructure?.validate();
  }
}

/// Model for create-account / sign-in onboarding screen.
/// Shows Continue with Google, optionally Continue with Apple, and a skip CTA.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class CreateAccountScreenModel extends OnboardingModel {
  CreateAccountScreenModel({
    required this.title,
    this.description,
    this.visual,
    this.nextButtonText,
    this.showTopBar = true,
    this.googleButtonLabel,
    this.appleButtonLabel,
    this.googlePlatforms,
    this.applePlatforms,
    this.metadata,
    this.highlightWords,
    this.highlightColor,
  }) : super(title: title);

  factory CreateAccountScreenModel.fromJson(Map<String, dynamic> json) =>
      _$CreateAccountScreenModelFromJson(json);

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  /// Mascot / illustration path (PNG or Lottie). Defaults to the wizard cut-out.
  final String? visual;

  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  @override
  final dynamic nextButtonText;

  @JsonKey(name: 'show_top_bar', defaultValue: true)
  @override
  final bool showTopBar;

  /// Button label for Google sign-in. Multilocale; default "Continue with Google".
  @JsonKey(name: 'google_button_label', fromJson: _multilocaleFromJson)
  final dynamic googleButtonLabel;

  /// Button label for Apple sign-in. Multilocale; default "Continue with Apple".
  @JsonKey(name: 'apple_button_label', fromJson: _multilocaleFromJson)
  final dynamic appleButtonLabel;

  /// Platforms where Google button is shown. Null or empty = all platforms.
  @JsonKey(name: 'google_platforms')
  final List<String>? googlePlatforms;

  /// Platforms where Apple button is shown. Null or empty = all platforms.
  @JsonKey(name: 'apple_platforms')
  final List<String>? applePlatforms;

  @override
  final OnboardingMetadata? metadata;

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.createAccount;

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$CreateAccountScreenModelToJson(this), type);
}

/// Model for warmup-type onboarding screens (personalized mirror).
/// Title/description may contain `{monthly_leak}`, `{vibe}`, `{push}`, `{savings}`,
/// `{deal_size}`, `{platform}` placeholders filled from the in-flow answers.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class WarmupScreenModel extends OnboardingModel {

  WarmupScreenModel({
    required this.title,
    required this.nextButtonText,
    this.description,
    this.visual,
    this.metadata,
    this.answerStructure,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
  }): super(title: title);

  factory WarmupScreenModel.fromJson(final Map<String, dynamic> json) => _$WarmupScreenModelFromJson(json);
  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  @override
  final dynamic description;

  final String? visual; // Lottie resource path or asset path
  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.warmup;

  /// Summary chip templates for [languageCode] (`summary_chips_<lang>` then `summary_chips`).
  List<String> summaryChipsFor(String languageCode) {
    final raw = metadata?.raw;
    final localized = raw?['summary_chips_$languageCode'];
    final base = localized is List && localized.isNotEmpty ? localized : raw?['summary_chips'];
    if (base is! List) return const [];
    return base.map((e) => e.toString()).toList();
  }

  /// deals_per_month value → multiplier override (`metadata.deals_multiplier`).
  Map<String, int> get dealsMultiplier {
    final raw = metadata?.raw?['deals_multiplier'];
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toInt(),
    };
  }

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$WarmupScreenModelToJson(this), type);
}

/// One stop of the slider_lottie ("How hard do you push?") screen.
class PushStopOption {
  const PushStopOption({
    required this.value,
    required this.label,
    this.subtext,
    this.emoji = '',
    this.colorHex,
  });

  factory PushStopOption.fromJson(Map<String, dynamic> json) => PushStopOption(
        value: (json['value'] as num?)?.toInt() ?? 0,
        label: MultilocaleText.fromJson(json['label']),
        subtext: json['subtext'] != null ? MultilocaleText.fromJson(json['subtext']) : null,
        emoji: json['emoji']?.toString() ?? '',
        colorHex: json['color']?.toString(),
      );

  final int value;
  final MultilocaleText label;
  final MultilocaleText? subtext;
  final String emoji;
  final String? colorHex;
}

/// Model for slider_lottie-type onboarding screens.
/// User picks one of N stops (risk_tolerance 20/40/60/80/100) that fills a Lottie tube.
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SliderLottieScreenModel extends OnboardingModel {
  SliderLottieScreenModel({
    required this.title,
    required this.nextButtonText,
    required this.answerStructure,
    this.description,
    this.visual,
    this.metadata,
    this.showTopBar = true,
    this.highlightWords,
    this.highlightColor,
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

  @override
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

  @JsonKey(name: 'highlight_words')
  @override
  final HighlightWordsConfig? highlightWords;

  @JsonKey(name: 'highlight_color')
  @override
  final String? highlightColor;

  @override
  OnboardingScreenType get type => OnboardingScreenType.sliderLottie;

  /// Stops parsed from `metadata.options`, sorted by value.
  List<PushStopOption> get stops {
    final raw = metadata?.options;
    if (raw == null) return const [];
    final list = raw
        .whereType<Map>()
        .map((m) => PushStopOption.fromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  /// Default value (`metadata.default_value`, default 60).
  int get defaultValue => metadata?.rawInt('default_value') ?? 60;

  /// Index of the stop matching [value] (nearest stop at or above the value).
  int stopIndexFor(num? value) {
    final s = stops;
    if (s.isEmpty) return 0;
    final v = value ?? defaultValue;
    for (var i = 0; i < s.length; i++) {
      if (v <= s[i].value) return i;
    }
    return s.length - 1;
  }

  @override
  Map<String, dynamic> toJson() =>
      _fixOnboardingModelJsonKeys(_$SliderLottieScreenModelToJson(this), type);
}

/// Extension for pattern matching with when-like syntax
extension OnboardingModelWhen<T> on OnboardingModel {
  /// Pattern matching method similar to Kotlin's when expression
  /// Provides type-safe pattern matching for all screen types
  T when<T>({
    required T Function(EngagementScreenModel) engagement,
    required T Function(SelectScreenModel) select,
    required T Function(MultiSelectScreenModel) multiSelect,
    required T Function(SelectGroupScreenModel) selectGroup,
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
    final self = this;
    if (self is EngagementScreenModel) return engagement(self);
    if (self is CreateAccountScreenModel) return createAccount(self);
    if (self is SelectScreenModel) return select(self);
    if (self is MultiSelectScreenModel) return multiSelect(self);
    if (self is SelectGroupScreenModel) return selectGroup(self);
    if (self is SliderScreenModel) return slider(self);
    if (self is PermissionScreenModel) return permission(self);
    if (self is ImageListScreenModel) return imageList(self);
    if (self is ReferralCodeScreenModel) return referralCode(self);
    if (self is PaywallScreenModel) return paywall(self);
    if (self is WarmupScreenModel) return warmup(self);
    if (self is DataUploadScreenModel) return dataUpload(self);
    if (self is SliderLottieScreenModel) return sliderLottie(self);
    if (orElse != null) return orElse();
    throw FormatException('Unknown screen type: $runtimeType');
  }
}
