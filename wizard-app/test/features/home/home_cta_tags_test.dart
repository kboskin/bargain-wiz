import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/home/presentation/utils/home_cta_tags.dart';
import 'package:appwizard/features/home/presentation/utils/share_message.dart';
import 'package:appwizard/features/home/presentation/widgets/highlighted_text.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

void main() {
  group('HomeCtaTags.forTier', () {
    test('free: lock tags on Express and Pro', () {
      final t = HomeCtaTags.forTier(SubscriptionTier.free);
      expect(t.showExpressLockTag, isTrue);
      expect(t.showProLockTag, isTrue);
    });

    test('premium: no tags', () {
      final t = HomeCtaTags.forTier(SubscriptionTier.premium);
      expect(t.showExpressLockTag, isFalse);
      expect(t.showProLockTag, isFalse);
    });

    test('unresolved tier behaves like free', () {
      expect(HomeCtaTags.forTier(null), HomeCtaTags.forTier(SubscriptionTier.free));
    });
  });

  group('tierLabel', () {
    test('drawer footer labels', () {
      expect(tierLabel(SubscriptionTier.free), 'Free plan');
      expect(tierLabel(SubscriptionTier.premium), 'Premium');
      expect(tierLabel(null), 'Free plan');
    });
  });

  group('showFirstRunNudge', () {
    test('hidden once Express was used', () {
      expect(showFirstRunNudge(expressUsed: true, nudgePending: true, historyEmpty: true), isFalse);
    });

    test('shown while pending or history is empty', () {
      expect(showFirstRunNudge(expressUsed: false, nudgePending: true, historyEmpty: false), isTrue);
      expect(showFirstRunNudge(expressUsed: false, nudgePending: false, historyEmpty: true), isTrue);
      expect(showFirstRunNudge(expressUsed: false, nudgePending: false, historyEmpty: false), isFalse);
    });
  });

  group('composeShareMessage', () {
    test('joins non-empty parts with blank lines', () {
      expect(
        composeShareMessage(title: 'Bargain Wiz', description: ' Never overpay. ', link: 'https://x'),
        'Bargain Wiz\n\nNever overpay.\n\nhttps://x',
      );
      expect(composeShareMessage(title: '', description: null, link: '  '), '');
    });
  });

  group('HighlightedText', () {
    const base = TextStyle(color: Colors.black, fontWeight: FontWeight.w400);

    test('parses hex colours', () {
      expect(HighlightedText.parseHexColor('#7B5EA7'), const Color(0xFF7B5EA7));
      expect(HighlightedText.parseHexColor('4ECDC4'), const Color(0xFF4ECDC4));
      expect(HighlightedText.parseHexColor('#804ECDC4'), const Color(0x804ECDC4));
      expect(HighlightedText.parseHexColor('#FFF'), const Color(0xFFFFFFFF));
      expect(HighlightedText.parseHexColor('bold'), isNull);
      expect(HighlightedText.parseHexColor(null), isNull);
    });

    test('colours the configured phrase and keeps the rest', () {
      final spans = HighlightedText.buildSpans('Your deal, upgraded.', base, {'upgraded.': '#7B5EA7'})
          .cast<TextSpan>();
      expect(spans.map((s) => s.text), ['Your deal, ', 'upgraded.']);
      expect(spans[0].style?.color, Colors.black);
      expect(spans[1].style?.color, const Color(0xFF7B5EA7));
    });

    test('supports the onboarding-style {title: {...}} wrapper and bold values', () {
      final highlights = {
        'title': {'earn': '#4ECDC4'},
        'description': {'rewards': 'bold'},
      };
      final title = HighlightedText.buildSpans('Invite friends & earn', base, highlights, section: 'title')
          .cast<TextSpan>();
      expect(title.last.text, 'earn');
      expect(title.last.style?.color, const Color(0xFF4ECDC4));

      final body = HighlightedText.buildSpans('You earn rewards when friends join', base, highlights,
              section: 'description')
          .cast<TextSpan>();
      final bold = body.firstWhere((s) => s.text == 'rewards');
      expect(bold.style?.fontWeight, FontWeight.w700);
      expect(bold.style?.color, Colors.black);
    });

    test('matching is case-insensitive; no config → single span', () {
      final spans = HighlightedText.buildSpans('Are you SATISFIED?', base, {'satisfied': '#117E76'})
          .cast<TextSpan>();
      expect(spans.map((s) => s.text), ['Are you ', 'SATISFIED', '?']);
      expect(HighlightedText.buildSpans('Plain', base, null).length, 1);
    });
  });
}
