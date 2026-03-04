/// Paywall layout types for different UI templates
enum PaywallLayout {
  cards,
  list,
  compact;

  /// Parse layout from string, default to cards
  static PaywallLayout fromString(String? value) {
    if (value == null || value.isEmpty) {
      return PaywallLayout.cards;
    }
    switch (value.toLowerCase()) {
      case 'cards':
        return PaywallLayout.cards;
      case 'list':
        return PaywallLayout.list;
      case 'compact':
        return PaywallLayout.compact;
      default:
        return PaywallLayout.cards;
    }
  }

  String get name {
    switch (this) {
      case PaywallLayout.cards:
        return 'cards';
      case PaywallLayout.list:
        return 'list';
      case PaywallLayout.compact:
        return 'compact';
    }
  }
}
