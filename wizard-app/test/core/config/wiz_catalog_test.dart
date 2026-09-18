import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appwizard/core/config/wiz_catalog.dart';

void main() {
  const catalog = WizCatalog();

  group('WizCatalog lookups', () {
    test('vibeById falls back to the first vibe', () {
      expect(catalog.vibeById('tactical').id, 'tactical');
      expect(catalog.vibeById('nope').id, 'friendly');
      expect(catalog.vibeById(null).id, 'friendly');
    });

    test('pushForValue snaps to the next stop and defaults to Balanced', () {
      expect(catalog.pushForValue(20).emoji, '🌊');
      expect(catalog.pushForValue(55).value, 60);
      expect(catalog.pushForValue(100).value, 100);
      expect(catalog.pushForValue(999).value, 100);
      expect(catalog.pushForValue(null).value, WizCatalog.defaultPushValue);
      expect(catalog.pushIndexForValue(80), 3);
    });

    test('dealSizeForValue picks the nearest stop', () {
      expect(catalog.dealSizeForValue(50).savingsHigh, 20);
      expect(catalog.dealSizeForValue(600).savingsHigh, 110);
      expect(catalog.dealSizeForValue(5000).savingsRange, '\$300–900');
      expect(catalog.dealSizeForValue(null).value, WizCatalog.defaultDealSizeValue);
    });
  });

  group('monthly leak formula (savings_high × deals multiplier)', () {
    test('matches the handoff example: \$550 for a \$100–1000 deal at 3–5 deals/month', () {
      expect(catalog.monthlyLeak(dealSize: 550, dealsPerMonth: '3_5'), 550);
    });
    test('other multipliers', () {
      expect(catalog.monthlyLeak(dealSize: 50, dealsPerMonth: '0_2'), 40);
      expect(catalog.monthlyLeak(dealSize: 5000, dealsPerMonth: '6_plus'), 7200);
      // Unknown deals_per_month → multiplier 3
      expect(catalog.monthlyLeak(dealSize: 550, dealsPerMonth: null), 330);
    });
  });

  group('labels', () {
    test('marketplace and deals per month', () {
      expect(WizCatalog.marketplaceLabel('facebook'), 'Facebook Marketplace');
      expect(WizCatalog.marketplaceLabel(null), 'Any marketplace');
      expect(WizCatalog.marketplaceLabel('Custom'), 'Custom');
      expect(WizCatalog.dealsPerMonthLabel('6_plus'), '6+');
      expect(WizCatalog.dealsPerMonthLabel(null), '—');
    });
  });

  group('marketplaceIcon', () {
    test('known marketplaces get built-in glyphs, brands from the Font Awesome brands font', () {
      for (final v in ['ebay', 'amazon', 'facebook']) {
        final icon = WizCatalog.marketplaceIcon(v)!;
        expect(icon.fontFamily, 'FontAwesomeBrands', reason: v);
        expect(icon.fontPackage, 'font_awesome_flutter', reason: v);
      }
      expect(WizCatalog.marketplaceIcon('olx')!.fontFamily, 'FontAwesomeSolid');
      expect(WizCatalog.marketplaceIcon('craigslist')!.fontFamily, 'FontAwesomeSolid');
      expect(WizCatalog.marketplaceIcon('other'), Icons.auto_awesome);
    });

    test('unknown or missing values have no icon', () {
      expect(WizCatalog.marketplaceIcon('zzz'), isNull);
      expect(WizCatalog.marketplaceIcon(null), isNull);
      expect(WizCatalog.marketplaceIcon(''), isNull);
    });

    test('a remote icon config overrides the built-in glyph', () {
      final icon = WizCatalog.marketplaceIcon('ebay', iconRaw: {'code': '0xf54e', 'font': 'solid'})!;
      expect(icon.codePoint, 0xf54e);
      expect(icon.fontFamily, 'FontAwesomeSolid');
      expect(WizCatalog.marketplaceIcon('ebay', iconRaw: '')!.fontFamily, 'FontAwesomeBrands');
    });
  });

  group('vibe icons', () {
    test('every default vibe has a Font Awesome glyph', () {
      for (final v in WizCatalog.defaultVibes) {
        expect(v.icon, isNotNull, reason: v.id);
        expect(v.icon!.fontPackage, 'font_awesome_flutter', reason: v.id);
      }
    });

    test('a remote option icon overrides the default glyph', () {
      final c = catalog.withRemoteOptions({
        'negotiation_vibe': [
          {'label': 'Friendly', 'value': 'friendly', 'icon': {'code': '0xf0e7', 'font': 'solid'}},
        ],
      });
      expect(c.vibes.single.icon!.codePoint, 0xf0e7);
      expect(c.vibes.single.icon!.fontFamily, 'FontAwesomeSolid');
    });
  });

  group('withRemoteOptions', () {
    test('overrides colors/labels from onboarding options and keeps defaults otherwise', () {
      final c = catalog.withRemoteOptions({
        'negotiation_vibe': [
          {'label': 'Chill', 'value': 'friendly', 'metadata': {'color': '#123456', 'short': 'Chill'}},
        ],
        'risk_tolerance': [
          {'value': 20, 'label': 'Soft', 'emoji': '🍃', 'color': '#00FF00'},
        ],
      });
      expect(c.vibes.length, 1);
      expect(c.vibes.first.color, const Color(0xFF123456));
      expect(c.vibes.first.short, 'Chill');
      expect(c.vibes.first.icon, WizCatalog.defaultVibes.first.icon); // kept from the base vibe
      expect(c.pushLevels.length, 1);
      expect(c.pushLevels.first.emoji, '🍃');
      expect(c.dealSizes.length, 3);
    });
  });
}
