import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/paywall/presentation/widgets/paywall_plan_layouts.dart';

/// A plan card carries one badge. It says "{n} days free" while that period has a trial,
/// and falls back to the plain badge ("Best value") when it does not.
PaywallConfig _config({
  int? monthlyTrial = 3,
  bool trialBadge = true,
  List<String> monthlyBadges = const ['Save 25%'],
  Map<String, dynamic> metadata = const {},
  Map<String, dynamic> monthlyExtra = const {},
  Map<String, dynamic> weeklyExtra = const {},
  Map<String, String> visuals = const {},
}) =>
    PaywallConfig.fromJson({
      'type': 'test',
      'title': {'en': 'Unlock Bargain Wiz'},
      'description': {'en': 'One plan. Pick how you pay.'},
      'options': [
        {
          'id': 'monthly',
          'tier': 'premium',
          'title': {'en': 'Monthly'},
          'description': {'en': 'One saved deal covers the month. You save 34% with this plan.'},
          'description_highlight_words': {'You save 34% with this plan': 'bold #117E76'},
          'badges': [for (final b in monthlyBadges) {'en': b}],
          'price_label': {'en': r'$19.99/mo'},
          if (monthlyTrial != null) 'trial_days': monthlyTrial,
          if (trialBadge)
            'trial_badge': {
              'one': {'en': '{n} day free'},
              'other': {'en': '{n} days free'},
            },
          ...monthlyExtra,
        },
        {
          'id': 'weekly',
          'tier': 'premium',
          'title': {'en': 'Weekly'},
          'description': {
            'en': 'Just this week? One deal covers it. You still get exclusive app features.',
          },
          'price_label': {'en': r'$6.99/wk'},
          'trial_days': 0,
          ...weeklyExtra,
        },
      ],
      'metadata': {
        'default_selected_option_id': 'monthly',
        'layout': 'cards',
        'option_visuals': visuals,
        ...metadata,
      },
      'next_button_text': {'en': 'Continue'},
      'note_text': {'en': '{price}. Cancel anytime.'},
      'trial_days': 3,
    });

TextStyle _priceStyle(WidgetTester tester, String price) =>
    tester.widget<Text>(find.text(price)).style!;

/// The decoration of the card that holds [text].
BoxDecoration _cardDecoration(WidgetTester tester, String text) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(of: find.text(text), matching: find.byType(AnimatedContainer))
        .last,
  );
  return container.decoration! as BoxDecoration;
}

Future<void> _pump(WidgetTester tester, PaywallConfig config) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaywallPlanPicker(
              config: config,
              selectedId: 'monthly',
              priceFor: (o) => o.id == 'monthly' ? r'$19.99/mo' : r'$6.99/wk',
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  // VisualAssetWidget reaches into GetIt for AssetPathHelper, so a card that renders its own
  // art cannot be pumped without it.
  setUpAll(() => di.sl.registerLazySingleton<AssetPathHelper>(AssetPathHelper.new));
  tearDownAll(() => di.sl.reset());

  group('badgesFor', () {
    PaywallOption optionOf(PaywallConfig c, String id) =>
        c.options.firstWhere((o) => o.id == id);

    test('the trial leads the row, the configured badges follow', () {
      final monthly = optionOf(_config(), 'monthly');
      expect(badgesFor(monthly, 3, PaywallText.plain), ['3 days free', 'Save 25%']);
      expect(badgesFor(monthly, 1, PaywallText.plain), ['1 day free', 'Save 25%']);
    });

    test('without a trial only the configured badges remain', () {
      final monthly = optionOf(_config(), 'monthly');
      expect(badgesFor(monthly, 0, PaywallText.plain), ['Save 25%']);
    });

    test('a trial with nothing naming it is simply absent', () {
      final monthly = optionOf(_config(trialBadge: false), 'monthly');
      expect(badgesFor(monthly, 3, PaywallText.plain), ['Save 25%']);
    });

    test('the row is the template\'s to set, in its own order', () {
      final monthly = optionOf(_config(monthlyBadges: ['Most popular', 'Save 25%']), 'monthly');
      expect(
        badgesFor(monthly, 3, PaywallText.plain),
        ['3 days free', 'Most popular', 'Save 25%'],
      );
    });

    test('an option with nothing to say shows nothing', () {
      expect(badgesFor(optionOf(_config(), 'weekly'), 0, PaywallText.plain), isEmpty);
      final bare = optionOf(_config(monthlyBadges: [], trialBadge: false), 'monthly');
      expect(badgesFor(bare, 3, PaywallText.plain), isEmpty);
    });

    test('a config from before the row shows its single badge', () {
      final legacy = optionOf(
        _config(monthlyBadges: [], trialBadge: false, monthlyExtra: {
          'badge': {'en': 'Best value'},
        }),
        'monthly',
      );
      expect(badgesFor(legacy, 0, PaywallText.plain), ['Best value']);
    });

    test('the row wins over the legacy single badge', () {
      final both = optionOf(
        _config(trialBadge: false, monthlyExtra: {
          'badge': {'en': 'Best value'},
        }),
        'monthly',
      );
      expect(badgesFor(both, 0, PaywallText.plain), ['Save 25%']);
    });
  });

  group('the card renders the row', () {
    testWidgets('both badges appear on the plan that has them', (tester) async {
      await _pump(tester, _config());
      expect(find.text('3 days free'), findsOneWidget);
      expect(find.text('Save 25%'), findsOneWidget);
      expect(find.byType(PaywallBadgePill), findsNWidgets(2));
    });

    testWidgets('the plan without badges shows none', (tester) async {
      await _pump(tester, _config(monthlyBadges: [], trialBadge: false));
      expect(find.byType(PaywallBadgePill), findsNothing);
    });

    testWidgets('it counts the period it belongs to', (tester) async {
      await _pump(tester, _config(monthlyTrial: 7));
      expect(find.text('7 days free'), findsOneWidget);
    });

    testWidgets('dropping the trial leaves the rest of the row', (tester) async {
      await _pump(tester, _config(monthlyTrial: 0));
      expect(find.text('3 days free'), findsNothing);
      expect(find.text('Save 25%'), findsOneWidget);
    });

    testWidgets('an option without its own trial_days inherits the paywall default',
        (tester) async {
      await _pump(tester, _config(monthlyTrial: null));
      expect(find.text('3 days free'), findsOneWidget);
    });

    testWidgets('a long row wraps instead of overflowing', (tester) async {
      await _pump(tester, _config(monthlyBadges: ['Save 25%', 'Most popular', 'Best value']));
      expect(find.byType(PaywallBadgePill), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });

  group('the price reads as a light detail', () {
    testWidgets('it uses the body font at the configured light weight', (tester) async {
      await _pump(tester, _config(metadata: {
        'price_font_family': 'body',
        'price_font_weight': 300,
      }));
      final style = _priceStyle(tester, r'$19.99/mo');
      expect(style.fontFamily, 'Figtree');
      expect(style.fontWeight, FontWeight.w300);
    });

    testWidgets('light is the default, without the display font to hold it back',
        (tester) async {
      await _pump(tester, _config());
      final style = _priceStyle(tester, r'$19.99/mo');
      expect(style.fontFamily, 'Figtree');
      expect(style.fontWeight, FontWeight.w400);
    });

    testWidgets('the display font can be asked for, where 500 is the floor', (tester) async {
      await _pump(tester, _config(metadata: {'price_font_family': 'display'}));
      expect(_priceStyle(tester, r'$19.99/mo').fontFamily, 'Outfit');
    });

    testWidgets('no halo unless the template asks for one', (tester) async {
      await _pump(tester, _config());
      expect(_priceStyle(tester, r'$19.99/mo').shadows, isNull);
      expect(_priceStyle(tester, r'$6.99/wk').shadows, isNull);
    });

    testWidgets('and when it does, only the selected card is haloed', (tester) async {
      await _pump(tester, _config(metadata: {'price_glow': true}));
      expect(_priceStyle(tester, r'$19.99/mo').shadows, isNotEmpty); // monthly is selected
      expect(_priceStyle(tester, r'$6.99/wk').shadows, isNull);
    });
  });

  group('the description can emphasise part of itself', () {
    /// The spans of the card description containing [needle].
    List<InlineSpan> _descriptionSpans(WidgetTester tester, String needle) {
      final text = tester.widget<Text>(find.textContaining(needle));
      return (text.textSpan! as TextSpan).children!;
    }

    testWidgets('the configured phrase is bold and tinted, the rest is not', (tester) async {
      await _pump(tester, _config());
      final spans = _descriptionSpans(tester, 'One saved deal').cast<TextSpan>();
      final bold = spans.where((s) => s.style?.fontWeight == FontWeight.w700);
      expect(bold.map((s) => s.text), ['You save 34% with this plan']);
      expect(bold.single.style?.color, const Color(0xFF117E76));
      expect(
        spans.where((s) => s.style?.fontWeight != FontWeight.w700).map((s) => s.text),
        contains('One saved deal covers the month. '),
      );
    });

    testWidgets('a description with nothing configured stays one plain span', (tester) async {
      await _pump(tester, _config());
      final spans = _descriptionSpans(tester, 'Just this week').cast<TextSpan>();
      expect(spans, hasLength(1));
      expect(spans.single.style?.fontWeight, isNot(FontWeight.w700));
    });
  });

  group('each plan can own its art', () {
    /// Every plan's art, in card order. Both cards go through the one shared widget, the
    /// fallback included, so this is the whole picture.
    List<String> artPaths(WidgetTester tester) => tester
        .widgetList<VisualAssetWidget>(find.byType(VisualAssetWidget))
        .map((w) => w.visualPath)
        .toList();

    VisualAssetWidget artAt(WidgetTester tester, String path) =>
        tester.widget<VisualAssetWidget>(find.byWidgetPredicate(
          (w) => w is VisualAssetWidget && w.visualPath == path,
        ));

    const weekly = 'assets/images/plan_weekly_cutout.png';

    testWidgets('art_color tints the block, whichever card is preselected', (tester) async {
      await _pump(tester, _config(
        monthlyExtra: {'art_color': '#FFF1E2'},
        weeklyExtra: {'art_color': '#EEF7F6'},
      ));
      for (final colour in [const Color(0xFFFFF1E2), const Color(0xFFEEF7F6)]) {
        expect(
          tester.widgetList<Container>(find.byType(Container)).where(
                (c) => (c.decoration as BoxDecoration?)?.color == colour,
              ),
          hasLength(1),
        );
      }
    });

    testWidgets('without art_color the preselected card keeps the warm tint', (tester) async {
      await _pump(tester, _config());
      expect(
        tester.widgetList<Container>(find.byType(Container)).where(
              (c) => (c.decoration as BoxDecoration?)?.color == WizColors.amberSoft,
            ),
        hasLength(1),
      );
    });

    testWidgets('each plan draws the art it names', (tester) async {
      await _pump(tester, _config(visuals: {
        'monthly': 'assets/lottie/plan_monthly.json',
        'weekly': weekly,
      }));
      expect(artPaths(tester), ['assets/lottie/plan_monthly.json', weekly]);
    });

    testWidgets('a plan that names nothing falls back to the shared mascot', (tester) async {
      await _pump(tester, _config(visuals: {'weekly': weekly}));
      expect(artPaths(tester), [WizMascot.asset, weekly]);
    });

    testWidgets('art can come from a URL, so it can change without a release',
        (tester) async {
      const url = 'https://cdn.example.com/plan_weekly.png';
      await _pump(tester, _config(visuals: {'weekly': url}));

      final providers = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<NetworkImage>();
      expect(providers.map((n) => n.url), [url]);
      // The fetch itself fails under flutter_test (every request returns 400); the point is
      // that the network branch is taken, not that the bytes arrive.
      tester.takeException();
    });

    testWidgets('visual_width / visual_height size the art, and looping is config',
        (tester) async {
      await _pump(tester, _config(
        visuals: {'weekly': weekly},
        metadata: {'visual_width': 100, 'visual_height': 100, 'animation_looped': true},
      ));
      final art = artAt(tester, weekly);
      expect(art.width, 100);
      expect(art.height, 100);
      expect(art.repeat, isTrue);
    });

    testWidgets('the art never outgrows the block it is clipped by', (tester) async {
      await _pump(tester, _config(
        visuals: {'weekly': weekly},
        metadata: {'visual_width': 400, 'visual_height': 400},
      ));
      final art = artAt(tester, weekly);
      expect(art.height, PaywallMetadata.defaultArtBlockHeight);
      expect(art.width, 400); // width is the card's to clip; an uncapped height would just cut
    });

    testWidgets('raising art_block_height is what lets the art grow', (tester) async {
      await _pump(tester, _config(
        visuals: {'weekly': weekly},
        metadata: {'visual_width': 120, 'visual_height': 120, 'art_block_height': 132},
      ));
      expect(artAt(tester, weekly).height, 120);
      // Both cards' blocks grew with it, so nothing is clipped and they stay level.
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.constraints?.maxHeight == 132),
        hasLength(2),
      );
    });

    testWidgets('unset sizes keep the handoff default', (tester) async {
      await _pump(tester, _config(visuals: {'weekly': weekly}));
      final art = artAt(tester, weekly);
      expect(art.width, PaywallMetadata.defaultArtSize);
      expect(art.height, PaywallMetadata.defaultArtSize);
    });

    testWidgets('a Lottie plays once when the template says so', (tester) async {
      await _pump(tester, _config(
        visuals: {'weekly': weekly},
        metadata: {'animation_looped': false},
      ));
      expect(artAt(tester, weekly).repeat, isFalse);
    });
  });

  group('card_style decides how the selected card is emphasised', () {
    test('it parses, and anything unknown keeps the handoff default', () {
      expect(PaywallCardStyle.fromString('glow'), PaywallCardStyle.glow);
      expect(PaywallCardStyle.fromString('shadow'), PaywallCardStyle.shadow);
      expect(PaywallCardStyle.fromString('flat'), PaywallCardStyle.flat);
      expect(PaywallCardStyle.fromString('none'), PaywallCardStyle.flat);
      expect(PaywallCardStyle.fromString('sparkle'), PaywallCardStyle.glow);
      expect(PaywallCardStyle.fromString(null), PaywallCardStyle.glow);
      expect(_config().metadata.cardStyle, PaywallCardStyle.glow);
    });

    testWidgets('glow puts the amber halo on the selected card only', (tester) async {
      await _pump(tester, _config(metadata: {'card_style': 'glow'}));
      expect(_cardDecoration(tester, 'Monthly').boxShadow, WizShadows.selectedPlan);
      expect(_cardDecoration(tester, 'Weekly').boxShadow, isEmpty);
    });

    testWidgets('shadow drops the colour but keeps the lift', (tester) async {
      await _pump(tester, _config(metadata: {'card_style': 'shadow'}));
      expect(_cardDecoration(tester, 'Monthly').boxShadow, WizShadows.card);
    });

    testWidgets('flat leaves the border to do the work', (tester) async {
      await _pump(tester, _config(metadata: {'card_style': 'flat'}));
      expect(_cardDecoration(tester, 'Monthly').boxShadow, isEmpty);
      // The selected card is still distinguishable: ink border rather than grey.
      expect(
        (_cardDecoration(tester, 'Monthly').border! as Border).top.color,
        WizColors.ink,
      );
      expect(
        (_cardDecoration(tester, 'Weekly').border! as Border).top.color,
        WizColors.border,
      );
    });
  });
}
