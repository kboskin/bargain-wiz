import 'package:json_annotation/json_annotation.dart';

import 'package:appwizard/domain/entities/subscription_status.dart';
import 'package:appwizard/domain/entities/subscription_tier.dart';

part 'subscription_model.g.dart';

/// Data Transfer Object for subscription status
/// Used for API responses and in-memory cache
@JsonSerializable()
class SubscriptionModel {
  SubscriptionModel({
    required this.tier,
    required this.isActive,
    this.expiryDate,
    this.productId,
    this.transactionId,
    this.originalTransactionId,
    this.platform,
  });

  @JsonKey(fromJson: _tierFromJson, toJson: _tierToJson)
  final SubscriptionTier tier;

  @JsonKey(name: 'is_active', defaultValue: false)
  final bool isActive;

  @JsonKey(name: 'expiry_date', fromJson: _expiryDateFromJson, toJson: _expiryDateToJson)
  final DateTime? expiryDate;

  @JsonKey(name: 'product_id')
  final String? productId;

  @JsonKey(name: 'transaction_id')
  final String? transactionId;

  @JsonKey(name: 'original_transaction_id')
  final String? originalTransactionId;

  final String? platform;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionModelFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionModelToJson(this);

  static SubscriptionTier _tierFromJson(dynamic value) {
    if (value == null) return SubscriptionTier.free;
    final name = value as String;
    return SubscriptionTier.values.firstWhere(
      (t) => t.name == name,
      orElse: () => SubscriptionTier.free,
    );
  }

  static String _tierToJson(SubscriptionTier tier) => tier.name;

  static DateTime? _expiryDateFromJson(dynamic json) =>
      json != null ? DateTime.parse(json as String) : null;

  static String? _expiryDateToJson(DateTime? date) => date?.toIso8601String();

  /// Convert from domain entity
  factory SubscriptionModel.fromEntity(SubscriptionStatus entity) {
    return SubscriptionModel(
      tier: entity.tier,
      isActive: entity.isActive,
      expiryDate: entity.expiryDate,
      productId: entity.productId,
      transactionId: entity.transactionId,
      originalTransactionId: entity.originalTransactionId,
      platform: entity.platform,
    );
  }

  /// Convert to domain entity
  SubscriptionStatus toEntity() {
    return SubscriptionStatus(
      tier: tier,
      isActive: isActive,
      expiryDate: expiryDate,
      productId: productId,
      transactionId: transactionId,
      originalTransactionId: originalTransactionId,
      platform: platform,
    );
  }

  SubscriptionModel copyWith({
    SubscriptionTier? tier,
    bool? isActive,
    DateTime? expiryDate,
    String? productId,
    String? transactionId,
    String? originalTransactionId,
    String? platform,
  }) {
    return SubscriptionModel(
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      expiryDate: expiryDate ?? this.expiryDate,
      productId: productId ?? this.productId,
      transactionId: transactionId ?? this.transactionId,
      originalTransactionId: originalTransactionId ?? this.originalTransactionId,
      platform: platform ?? this.platform,
    );
  }
}
