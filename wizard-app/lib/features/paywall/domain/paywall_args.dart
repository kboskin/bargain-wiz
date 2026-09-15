/// Why the paywall was opened. Drives the context hint and the preselected plan.
enum PaywallEntry {
  /// Free user tapped Express Dealmaker → hint "free", Vision preselected.
  expressFree,
  /// Basic (Text Wizard) user tapped Express → hint "basic_express", Vision preselected.
  expressBasic,
  /// Free user tapped Pro Deal Closer → hint "free".
  proFree,
  /// Profile → Manage / Upgrade. No hint.
  profile,
  /// Optional onboarding entry (off by default). No hint, close hidden until delay.
  onboarding,
  /// Any other entry (drawer, deep link).
  other;

  /// Key into `paywall_config.context_hints`; null when no hint should be shown.
  String? get hintKey {
    switch (this) {
      case PaywallEntry.expressFree:
      case PaywallEntry.proFree:
        return 'free';
      case PaywallEntry.expressBasic:
        return 'basic_express';
      case PaywallEntry.profile:
      case PaywallEntry.onboarding:
      case PaywallEntry.other:
        return null;
    }
  }
}

/// Route `extra` for [AppRoutes.paywall]. The paywall pops with `true` when a
/// purchase (or restore) grants access, `false`/null otherwise.
class PaywallArgs {
  const PaywallArgs({this.entry = PaywallEntry.other, this.preselectOptionId});

  final PaywallEntry entry;
  /// Option id to preselect ("vision" / "text"); falls back to config default.
  final String? preselectOptionId;
}
