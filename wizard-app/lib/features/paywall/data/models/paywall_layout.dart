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

/// How a plan card shows that it is the selected one, on top of the ink border it always
/// gets. `glow` is the handoff's design and the default for any config that omits it.
enum PaywallCardStyle {
  /// Amber halo plus a soft drop shadow ([WizShadows.selectedPlan]).
  glow,

  /// A plain drop shadow, no colour.
  shadow,

  /// Border only.
  flat;

  static PaywallCardStyle fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'shadow':
        return PaywallCardStyle.shadow;
      case 'flat':
      case 'none':
        return PaywallCardStyle.flat;
      case 'glow':
      default:
        return PaywallCardStyle.glow;
    }
  }

  String get name {
    switch (this) {
      case PaywallCardStyle.glow:
        return 'glow';
      case PaywallCardStyle.shadow:
        return 'shadow';
      case PaywallCardStyle.flat:
        return 'flat';
    }
  }
}
