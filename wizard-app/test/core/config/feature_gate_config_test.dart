import 'package:flutter_test/flutter_test.dart';
import 'package:appwizard/core/config/feature_gate_config.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

void main() {
  group('FeatureGateConfig.defaults', () {
    const c = FeatureGateConfig.defaults;

    test('free: Lines that land only', () {
      expect(c.decide(SubscriptionTier.free, GatedFeature.linesThatLand).allowed, isTrue);
      final express = c.decide(SubscriptionTier.free, GatedFeature.expressDealmaker);
      expect(express.allowed, isFalse);
      expect(express.hintKey, 'free');
      final pro = c.decide(SubscriptionTier.free, GatedFeature.proDealCloser);
      expect(pro.allowed, isFalse);
      expect(pro.hintKey, 'free');
      expect(c.decide(SubscriptionTier.free, GatedFeature.history).allowed, isTrue);
      expect(c.decide(SubscriptionTier.free, GatedFeature.profile).allowed, isTrue);
    });

    test('basic: Pro works, Express opens paywall with the Vision hint', () {
      expect(c.decide(SubscriptionTier.basic, GatedFeature.proDealCloser).allowed, isTrue);
      final express = c.decide(SubscriptionTier.basic, GatedFeature.expressDealmaker);
      expect(express.allowed, isFalse);
      expect(express.hintKey, 'basic_express');
    });

    test('premium: everything', () {
      for (final f in GatedFeature.values) {
        expect(c.decide(SubscriptionTier.premium, f).allowed, isTrue, reason: f.name);
      }
    });
  });

  group('FeatureGateConfig.fromJson', () {
    test('parses remote rules and falls back per tier', () {
      final c = FeatureGateConfig.fromJson({
        'free': {'express_dealmaker': true},
        'premium': {'all': true},
      });
      // Remote says free may use Express.
      expect(c.decide(SubscriptionTier.free, GatedFeature.expressDealmaker).allowed, isTrue);
      // Unknown feature for free tier is blocked with the free hint.
      final pro = c.decide(SubscriptionTier.free, GatedFeature.proDealCloser);
      expect(pro.allowed, isFalse);
      expect(pro.hintKey, 'free');
      // Missing tier falls back to defaults.
      expect(c.decide(SubscriptionTier.basic, GatedFeature.expressDealmaker).hintKey, 'basic_express');
    });

    test('paywall(hint=...) syntax is parsed', () {
      final c = FeatureGateConfig.fromJson({
        'basic': {'pro_deal_closer': 'paywall(hint=custom_hint)'},
      });
      final d = c.decide(SubscriptionTier.basic, GatedFeature.proDealCloser);
      expect(d.allowed, isFalse);
      expect(d.hintKey, 'custom_hint');
    });
  });
}
