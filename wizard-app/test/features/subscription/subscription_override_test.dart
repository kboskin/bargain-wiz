import 'package:appwizard/features/subscription/domain/entities/subscription_override.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionOverride.fromWire', () {
    test('reads a paid tier, whatever its case, with or without an end', () {
      expect(SubscriptionOverride.fromWire(tier: ' Premium '), const SubscriptionOverride(tier: SubscriptionTier.premium));
      expect(
        SubscriptionOverride.fromWire(tier: 'premium', until: '2026-12-31T00:00:00Z'),
        SubscriptionOverride(tier: SubscriptionTier.premium, until: DateTime.utc(2026, 12, 31)),
      );
      expect(SubscriptionOverride.fromWire(tier: 'premium', until: '')?.until, isNull);
    });

    test('grants nothing without a paid tier', () {
      expect(SubscriptionOverride.fromWire(), isNull);
      expect(SubscriptionOverride.fromWire(tier: 'free'), isNull);
      expect(SubscriptionOverride.fromWire(tier: 'gold'), isNull);
    });

    test('an end date that cannot be read grants nothing rather than everything', () {
      expect(SubscriptionOverride.fromWire(tier: 'premium', until: 'next friday'), isNull);
    });
  });

  test('a grant lets the person in until it ends', () {
    final grant = SubscriptionOverride(tier: SubscriptionTier.premium, until: DateTime.utc(2026, 12, 31));
    expect(grant.grantsAt(DateTime.utc(2026, 12, 30, 23, 59)), isTrue);
    expect(grant.grantsAt(DateTime.utc(2026, 12, 31)), isFalse);
    expect(const SubscriptionOverride(tier: SubscriptionTier.premium).grantsAt(DateTime.utc(2100)), isTrue);
  });
}
