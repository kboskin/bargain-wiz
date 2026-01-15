import 'package:appwizard/domain/entities/subscription_status.dart';
import 'package:appwizard/domain/entities/subscription_tier.dart';

/// Data Transfer Object for subscription status
/// Used for API responses and in-memory cache
class SubscriptionModel {
  final SubscriptionTier tier;
  final bool isActive;
  final DateTime? expiryDate;
  final String? productId;
  final String? transactionId;
  final String? originalTransactionId;
  final String? platform;

  SubscriptionModel({
    required this.tier,
    required this.isActive,
    this.expiryDate,
    this.productId,
    this.transactionId,
    this.originalTransactionId,
    this.platform,
  });

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

  /// Convert from JSON (API response)
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      tier: SubscriptionTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      isActive: json['is_active'] as bool? ?? false,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      productId: json['product_id'] as String?,
      transactionId: json['transaction_id'] as String?,
      originalTransactionId: json['original_transaction_id'] as String?,
      platform: json['platform'] as String?,
    );
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'is_active': isActive,
      'expiry_date': expiryDate?.toIso8601String(),
      'product_id': productId,
      'transaction_id': transactionId,
      'original_transaction_id': originalTransactionId,
      'platform': platform,
    };
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
