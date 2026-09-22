import 'package:appwizard/core/config/feature_gate_policy.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GateDecision d(SubscriptionTier tier, GatedFeature f) => FeatureGatePolicy.decide(tier, f);

  test('free: Lines that land, history and profile only; Express and Pro open the paywall', () {
    expect(d(SubscriptionTier.free, GatedFeature.linesThatLand).allowed, isTrue);
    expect(d(SubscriptionTier.free, GatedFeature.history).allowed, isTrue);
    expect(d(SubscriptionTier.free, GatedFeature.profile).allowed, isTrue);
    final express = d(SubscriptionTier.free, GatedFeature.expressDealmaker);
    expect(express.allowed, isFalse);
    expect(express.hintKey, 'free');
    expect(d(SubscriptionTier.free, GatedFeature.proDealCloser).allowed, isFalse);
  });

  test('premium: everything', () {
    for (final f in GatedFeature.values) {
      expect(d(SubscriptionTier.premium, f).allowed, isTrue, reason: f.name);
    }
  });
}
