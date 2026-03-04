import 'package:equatable/equatable.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Subscription product entity - represents a purchasable subscription
class SubscriptionProduct extends Equatable {
  final String productId;
  final SubscriptionTier tier;
  final String title; // Multilocale string or simple string
  final String description; // Multilocale string or simple string
  final String? price; // Formatted price from store (e.g., "$9.99")
  final String? currency; // Currency code (e.g., "USD")
  final List<String> features; // List of feature descriptions
  final int displayOrder; // Order in which to display products

  const SubscriptionProduct({
    required this.productId,
    required this.tier,
    required this.title,
    required this.description,
    this.price,
    this.currency,
    required this.features,
    required this.displayOrder,
  });

  @override
  List<Object?> get props => [
        productId,
        tier,
        title,
        description,
        price,
        currency,
        features,
        displayOrder,
      ];
}
