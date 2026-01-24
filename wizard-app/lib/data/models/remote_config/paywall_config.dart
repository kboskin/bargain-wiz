import 'package:json_annotation/json_annotation.dart';
import 'package:appwizard/data/models/remote_config/json_helpers.dart';
import 'package:appwizard/data/models/remote_config/paywall_layout.dart';
import 'package:appwizard/domain/entities/subscription_tier.dart';

part 'paywall_config.g.dart';

/// Paywall configuration from Remote Config
/// This is the full paywall definition that lives in a separate RC key
@JsonSerializable()
class PaywallConfig {
  final String type; // e.g., "onboarding_default"
  final dynamic title; // Map<String, String> (multilocale) or String
  final dynamic description; // Map<String, String> (multilocale) or String
  final List<PaywallOption> options; // Two subscription options
  final PaywallMetadata metadata; // Visual config, default selection, etc.
  @JsonKey(name: 'next_button_text')
  final dynamic nextButtonText; // Map<String, String> (multilocale) or String
  @JsonKey(name: 'note_text')
  final dynamic noteText; // Map<String, String> (multilocale) or String
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

  factory PaywallConfig.fromJson(Map<String, dynamic> json) {
    return PaywallConfig(
      type: JsonHelpers.requireString(json, 'type'),
      title: JsonHelpers.requireMultilocaleText(json, 'title'),
      description: JsonHelpers.requireMultilocaleText(json, 'description'),
      options: JsonHelpers.requireList<PaywallOption>(
        json,
        'options',
        (item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException(
              'Expected Map<String, dynamic> for paywall option, got ${item.runtimeType}',
            );
          }
          return PaywallOption.fromJson(item);
        },
      ),
      metadata: PaywallMetadata.fromJson(
        JsonHelpers.requireMap(json, 'metadata'),
      ),
      nextButtonText: JsonHelpers.requireMultilocaleText(json, 'next_button_text'),
      noteText: JsonHelpers.requireMultilocaleText(json, 'note_text'),
      showRestore: json['show_restore'] as bool? ?? true,
      showClose: json['show_close'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => _$PaywallConfigToJson(this);
}

/// Paywall option (subscription tier)
@JsonSerializable()
class PaywallOption {
  final String id; // e.g., "text", "vision"
  final String tier; // "basic" or "premium"
  final dynamic title; // Map<String, String> (multilocale) or String
  final dynamic description; // Map<String, String> (multilocale) or String
  final dynamic badge; // Map<String, String> (multilocale) or String or null

  PaywallOption({
    required this.id,
    required this.tier,
    required this.title,
    required this.description,
    this.badge,
  });

  factory PaywallOption.fromJson(Map<String, dynamic> json) {
    return PaywallOption(
      id: JsonHelpers.requireString(json, 'id'),
      tier: JsonHelpers.requireString(json, 'tier'),
      title: JsonHelpers.requireMultilocaleText(json, 'title'),
      description: JsonHelpers.requireMultilocaleText(json, 'description'),
      badge: JsonHelpers.optionalMultilocaleText(json, 'badge'),
    );
  }

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

  factory PaywallMetadata.fromJson(Map<String, dynamic> json) {
    final optionVisualsJson = json['option_visuals'];
    Map<String, String> optionVisuals = {};
    if (optionVisualsJson is Map) {
      optionVisuals = optionVisualsJson.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return PaywallMetadata(
      defaultSelectedOptionId: JsonHelpers.requireString(
        json,
        'default_selected_option_id',
      ),
      layout: PaywallLayout.fromString(JsonHelpers.optionalString(json, 'layout')),
      cardStyle: JsonHelpers.optionalString(json, 'card_style'),
      visualWidth: json['visual_width'] is num
          ? (json['visual_width'] as num).toDouble()
          : null,
      visualHeight: json['visual_height'] is num
          ? (json['visual_height'] as num).toDouble()
          : null,
      visualOpacity: json['visual_opacity'] is num
          ? (json['visual_opacity'] as num).toDouble()
          : null,
      optionVisuals: optionVisuals,
    );
  }

  static PaywallLayout _layoutFromJson(String? value) =>
      PaywallLayout.fromString(value);

  static String? _layoutToJson(PaywallLayout layout) => layout.name;

  Map<String, dynamic> toJson() => _$PaywallMetadataToJson(this);
}
