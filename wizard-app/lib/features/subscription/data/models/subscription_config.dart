import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:json_annotation/json_annotation.dart';

part 'subscription_config.g.dart';

/// Configuration for subscription products from Remote Config
@JsonSerializable()
class SubscriptionConfig {
  final List<SubscriptionProductConfig> products;

  SubscriptionConfig({
    required this.products,
  });

  factory SubscriptionConfig.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionConfigToJson(this);
}

/// Configuration for a single subscription product (one billing period of a tier).
@JsonSerializable()
class SubscriptionProductConfig {
  /// Key a paywall option points at (`options[].id`), e.g. "monthly" / "weekly". Optional for
  /// configs written before several products shared a tier; those still match by tier.
  final String? id;
  final String tier; // 'free', 'premium'
  @JsonKey(name: 'product_id')
  final ProductIdConfig productId; // Platform-specific product IDs
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  final List<String> features; // List of feature descriptions
  @JsonKey(name: 'display_order')
  final int displayOrder;

  SubscriptionProductConfig({
    this.id,
    required this.tier,
    required this.productId,
    required this.title,
    required this.description,
    required this.features,
    required this.displayOrder,
  });

  factory SubscriptionProductConfig.fromJson(Map<String, dynamic> json) => _$SubscriptionProductConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$SubscriptionProductConfigToJson(this);

  /// Get subscription tier enum
  SubscriptionTier get tierEnum => SubscriptionTier.fromName(tier.toLowerCase());

  /// Get product ID for current platform
  String getPlatformProductId() {
    // This will be determined at runtime based on Platform.isIOS
    // For now, return iOS as default, will be handled in repository
    return productId.ios;
  }
}

/// Platform-specific product IDs
@JsonSerializable()
class ProductIdConfig {
  final String ios;
  final String android;

  ProductIdConfig({
    required this.ios,
    required this.android,
  });

  factory ProductIdConfig.fromJson(Map<String, dynamic> json) =>
      _$ProductIdConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ProductIdConfigToJson(this);
}
