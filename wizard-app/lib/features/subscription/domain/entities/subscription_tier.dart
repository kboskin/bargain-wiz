/// Subscription tier enum - provider-agnostic
enum SubscriptionTier {
  free,
  basic,
  premium;

  /// Check if this tier has access to image recognition
  bool hasImageRecognition() {
    return this == SubscriptionTier.premium;
  }

  /// Check if this tier has access to text model
  bool hasTextAccess() {
    return this == SubscriptionTier.basic || this == SubscriptionTier.premium;
  }

  /// Map product ID to subscription tier
  static SubscriptionTier? fromProductId(String productId) {
    if (productId.contains('basic')) {
      return SubscriptionTier.basic;
    } else if (productId.contains('premium')) {
      return SubscriptionTier.premium;
    }
    return null;
  }

  /// Get product ID for this tier (fallback constants)
  String? getProductId() {
    switch (this) {
      case SubscriptionTier.basic:
        return 'com.bargain.wiz.basic';
      case SubscriptionTier.premium:
        return 'com.bargain.wiz.premium';
      case SubscriptionTier.free:
        return null;
    }
  }
}
