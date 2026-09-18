import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Features whose access depends on the subscription tier.
enum GatedFeature { linesThatLand, expressDealmaker, proDealCloser, history, profile }

/// Result of a gate check.
class GateDecision {
  const GateDecision.allowed()
      : allowed = true,
        hintKey = null;

  const GateDecision.paywall({this.hintKey}) : allowed = false;

  final bool allowed;

  /// Context hint for the paywall ("free", "basic_express"), when blocked.
  final String? hintKey;
}

/// The tier rules, fixed in code (they are part of the offer, not remote configuration):
///
/// | feature          | free    | basic (Text Wizard)       | premium (Vision Wizard) |
/// |------------------|---------|---------------------------|-------------------------|
/// | Lines that land  | yes     | yes                       | yes                     |
/// | Express Dealmaker| paywall | paywall (`basic_express`) | yes                     |
/// | Pro Deal Closer  | paywall | yes                       | yes                     |
/// | History, Profile | yes     | yes                       | yes                     |
class FeatureGatePolicy {
  FeatureGatePolicy._();

  static GateDecision decide(SubscriptionTier tier, GatedFeature feature) {
    switch (tier) {
      case SubscriptionTier.premium:
        return const GateDecision.allowed();
      case SubscriptionTier.basic:
        return feature == GatedFeature.expressDealmaker
            ? const GateDecision.paywall(hintKey: 'basic_express')
            : const GateDecision.allowed();
      case SubscriptionTier.free:
        switch (feature) {
          case GatedFeature.expressDealmaker:
          case GatedFeature.proDealCloser:
            return const GateDecision.paywall(hintKey: 'free');
          case GatedFeature.linesThatLand:
          case GatedFeature.history:
          case GatedFeature.profile:
            return const GateDecision.allowed();
        }
    }
  }
}
