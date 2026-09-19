import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/select_group_screen_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Scaffold(body: child),
      );

  SelectGroupScreenModel model({Map<String, dynamic>? olxIcon}) => SelectGroupScreenModel.fromJson({
        'type': 'select_group',
        'title': 'Where do you deal?',
        'next_button_text': 'Continue',
        'groups': [
          {
            'label': 'Primary platform',
            'answer_key_name': 'favorite_marketplace',
            'options': [
              {'label': 'eBay', 'value': 'ebay', 'icon': {'code': '0xf4f4', 'font': 'brands'}},
              {'label': 'Amazon', 'value': 'amazon', 'icon': {'code': '0xf270', 'font': 'brands'}},
              {
                'label': 'Facebook Marketplace',
                'value': 'facebook',
                'icon': {'code': '0xf09a', 'font': 'brands'},
              },
              {
                'label': 'OLX',
                'value': 'olx',
                'icon': olxIcon ?? {'code': '0xf54e', 'font': 'solid'},
              },
              {'label': 'Craigslist', 'value': 'craigslist'}, // no icon configured
              {
                'label': {'en': 'Other', 'es': 'Otro'},
                'value': 'other',
              },
            ],
          },
          {
            'label': 'Deals per month',
            'answer_key_name': 'deals_per_month',
            'options': [
              {'label': '0–2', 'value': '0_2'},
              {'label': '3–5', 'value': '3_5'},
            ],
          },
        ],
      });

  Iterable<Icon> icons(WidgetTester tester) => tester.widgetList<Icon>(find.byType(Icon));

  group('SelectGroupScreenWidget option icons', () {
    testWidgets('chips draw the glyph each option configures, and nothing else', (tester) async {
      await tester.pumpWidget(host(SelectGroupScreenWidget(model: model(), onChanged: (_) {})));

      final all = icons(tester).toList();
      // 4 of the 6 marketplace options configure an icon; the deals_per_month group has none.
      expect(all.length, 4);
      final brands = all.where((i) => i.icon?.fontFamily == 'FontAwesomeBrands').map((i) => i.icon!.codePoint);
      expect(brands, unorderedEquals([0xf4f4, 0xf270, 0xf09a])); // ebay, amazon, facebook
      expect(all.where((i) => i.icon?.fontFamily == 'FontAwesomeSolid').length, 1); // olx
    });

    testWidgets('a remote icon config overrides the built-in glyph', (tester) async {
      await tester.pumpWidget(host(SelectGroupScreenWidget(
        model: model(olxIcon: {'code': '0xf54f', 'font': 'solid'}),
        onChanged: (_) {},
      )));

      expect(icons(tester).where((i) => i.icon?.codePoint == 0xf54f).length, 1);
      expect(icons(tester).where((i) => i.icon?.codePoint == 0xf54e).length, 0);
    });
  });
}
