import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_profile_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingProfileSnapshot.formatMoney', () {
    test('adds a dollar sign and thousands separators', () {
      expect(OnboardingProfileSnapshot.formatMoney(0), r'$0');
      expect(OnboardingProfileSnapshot.formatMoney(550), r'$550');
      expect(OnboardingProfileSnapshot.formatMoney(7200), r'$7,200');
      expect(OnboardingProfileSnapshot.formatMoney(1234567), r'$1,234,567');
    });
  });

  group('monthly leak', () {
    test('uses savings_high(deal_size) × multiplier(deals_per_month)', () {
      final s = OnboardingProfileSnapshot(
        answers: const {'average_deal_size': 550, 'deals_per_month': '3_5'},
      );
      expect(s.monthlyLeak, 110 * 5);
      expect(s.monthlyLeakText, r'$550');
    });

    test('formats large leaks with a separator and honours the metadata multiplier override', () {
      final s = OnboardingProfileSnapshot(
        answers: const {'average_deal_size': 5000, 'deals_per_month': '6_plus'},
        dealsMultiplierOverride: const {'0_2': 2, '3_5': 5, '6_plus': 8},
      );
      expect(s.monthlyLeak, 900 * 8);
      expect(s.monthlyLeakText, r'$7,200');
    });

    test('falls back to catalog defaults when answers are missing', () {
      final s = OnboardingProfileSnapshot(answers: const {});
      expect(s.dealSize.value, WizCatalog.defaultDealSizeValue);
      expect(s.push.value, WizCatalog.defaultPushValue);
      expect(s.vibe.id, WizCatalog.defaultVibeId);
      expect(s.monthlyLeak, 110 * 3);
    });
  });

  group('placeholders and chips', () {
    final answers = <String, dynamic>{
      'main_hurdle': ['starting', 'fair_price'],
      'negotiation_vibe': 'friendly',
      'risk_tolerance': 60,
      'favorite_marketplace': 'facebook',
      'deals_per_month': '3_5',
      'average_deal_size': 550,
    };

    test('body placeholders lower-case vibe and push and fill savings/deal/platform', () {
      final s = OnboardingProfileSnapshot(answers: answers);
      final body = s.fillBody(
        'A {vibe} wizard with a {push} push saves {savings} on a typical {deal_size} deal on {platform}.',
      );
      expect(
        body,
        r'A friendly wizard with a balanced push saves $45–110 on a typical $100–1000 deal on Facebook Marketplace.',
      );
      expect(s.bodyPlaceholders['monthly_leak'], r'$550');
    });

    test('summary chips keep casing, fill emoji/count and pick colours by placeholder', () {
      final s = OnboardingProfileSnapshot(answers: answers);
      final chips = s.chips(const [
        '{vibe} wizard',
        '{push_emoji} {push}',
        '{platform}',
        '{leak_count} money leaks → plugged',
      ]);
      expect(chips.map((c) => c.label), [
        'Friendly wizard',
        '⚖️ Balanced',
        'Facebook Marketplace',
        '2 money leaks → plugged',
      ]);
      expect(chips[0].background, WizColors.teal);
      expect(chips[0].foreground, WizColors.tealInk);
      expect(chips[1].background, WizColors.push[2]);
      expect(chips[2].background, WizColors.ink);
      expect(chips[3].foreground, WizColors.ink);
    });

    test('empty leak count is tidied and capitalised', () {
      final s = OnboardingProfileSnapshot(answers: const {});
      expect(s.fillChip('{leak_count} money leaks → plugged'), 'Money leaks → plugged');
      expect(s.fillChip('{platform}'), 'Any marketplace');
    });

    test('localises catalog labels for Spanish', () {
      final s = OnboardingProfileSnapshot(answers: answers, languageCode: 'es');
      expect(s.vibeShort, 'Amable');
      expect(s.pushLabel, 'Equilibrado');
      expect(s.fillChip('Mago {vibe}'), 'Mago Amable');
    });
  });
}
