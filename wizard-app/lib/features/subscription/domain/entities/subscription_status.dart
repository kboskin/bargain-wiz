import 'package:equatable/equatable.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Subscription status entity - provider-agnostic
/// Represents the current subscription state of a user
class SubscriptionStatus extends Equatable {
  final SubscriptionTier tier;
  final bool isActive;
  final DateTime? expiryDate;
  final String? productId;
  final String? transactionId;
  final String? originalTransactionId;
  final String? platform; // 'ios' or 'android'

  const SubscriptionStatus({
    required this.tier,
    required this.isActive,
    this.expiryDate,
    this.productId,
    this.transactionId,
    this.originalTransactionId,
    this.platform,
  });

  /// Check if subscription has expired
  bool isExpired() {
    if (!isActive) return true;
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Check if user can access a specific feature
  bool canAccessFeature(SubscriptionTier requiredTier) {
    if (!isActive || isExpired()) return false;
    
    switch (requiredTier) {
      case SubscriptionTier.free:
        return true;
      case SubscriptionTier.premium:
        return tier == SubscriptionTier.premium;
    }
  }

  /// Check if current tier matches the given tier
  bool hasTier(SubscriptionTier tier) {
    return this.tier == tier && isActive && !isExpired();
  }

  SubscriptionStatus copyWith({
    SubscriptionTier? tier,
    bool? isActive,
    DateTime? expiryDate,
    String? productId,
    String? transactionId,
    String? originalTransactionId,
    String? platform,
  }) {
    return SubscriptionStatus(
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      expiryDate: expiryDate ?? this.expiryDate,
      productId: productId ?? this.productId,
      transactionId: transactionId ?? this.transactionId,
      originalTransactionId: originalTransactionId ?? this.originalTransactionId,
      platform: platform ?? this.platform,
    );
  }

  @override
  List<Object?> get props => [
        tier,
        isActive,
        expiryDate,
        productId,
        transactionId,
        originalTransactionId,
        platform,
      ];
}
