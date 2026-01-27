import 'package:json_annotation/json_annotation.dart';
import 'package:appwizard/data/models/remote_config/paywall_layout.dart';
import 'package:appwizard/domain/entities/subscription_tier.dart';
import 'package:appwizard/data/models/multilocale_text.dart';

part 'paywall_config.g.dart';

/// Paywall configuration from Remote Config
/// This is the full paywall definition that lives in a separate RC key
@JsonSerializable()
class PaywallConfig {
  final String type; // e.g., "onboarding_default"
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  final List<PaywallOption> options; // Two subscription options
  final PaywallMetadata metadata; // Visual config, default selection, etc.
  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  final dynamic nextButtonText;
  @JsonKey(name: 'note_text', fromJson: _multilocaleFromJson)
  final dynamic noteText;
  @JsonKey(name: 'show_restore')
  final bool showRestore;
  @JsonKey(name: 'show_close')
  final bool showClose;

  PaywallConfig({
    required this.type,
    required this.title,
    required this.description,
    required this.options,
    required this.metadata,
    required this.nextButtonText,
    required this.noteText,
    this.showRestore = true,
    this.showClose = false,
  });

  factory PaywallConfig.fromJson(Map<String, dynamic> json) => _$PaywallConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$PaywallConfigToJson(this);
}

/// Paywall option (subscription tier)
@JsonSerializable()
class PaywallOption {
  final String id; // e.g., "text", "vision"
  final String tier; // "basic" or "premium"
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic badge;

  PaywallOption({
    required this.id,
    required this.tier,
    required this.title,
    required this.description,
    this.badge,
  });

  factory PaywallOption.fromJson(Map<String, dynamic> json) => _$PaywallOptionFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$PaywallOptionToJson(this);

  /// Get subscription tier enum
  SubscriptionTier get tierEnum {
    switch (tier.toLowerCase()) {
      case 'basic':
        return SubscriptionTier.basic;
      case 'premium':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }
}

/// Paywall metadata (visual config, default selection, etc.)
@JsonSerializable()
class PaywallMetadata {
  @JsonKey(name: 'default_selected_option_id')
  final String defaultSelectedOptionId;
  @JsonKey(fromJson: _layoutFromJson, toJson: _layoutToJson)
  final PaywallLayout layout;
  @JsonKey(name: 'card_style')
  final String? cardStyle; // e.g., "glow"
  @JsonKey(name: 'visual_width')
  final double? visualWidth;
  @JsonKey(name: 'visual_height')
  final double? visualHeight;
  @JsonKey(name: 'visual_opacity')
  final double? visualOpacity;
  @JsonKey(name: 'option_visuals')
  final Map<String, String> optionVisuals; // Map of option_id -> lottie path

  PaywallMetadata({
    required this.defaultSelectedOptionId,
    required this.layout,
    this.cardStyle,
    this.visualWidth,
    this.visualHeight,
    this.visualOpacity,
    required this.optionVisuals,
  });

  factory PaywallMetadata.fromJson(Map<String, dynamic> json) => _$PaywallMetadataFromJson(json);

  static PaywallLayout _layoutFromJson(String? value) =>
      PaywallLayout.fromString(value);

  static String? _layoutToJson(PaywallLayout layout) => layout.name;

  Map<String, dynamic> toJson() => _$PaywallMetadataToJson(this);
}
