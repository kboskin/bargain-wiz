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
              {'label': 'eBay', 'value': 'ebay'},
              {'label': 'Amazon', 'value': 'amazon'},
              {'label': 'Facebook Marketplace', 'value': 'facebook'},
              {'label': 'OLX', 'value': 'olx', if (olxIcon != null) 'icon': olxIcon},
              {'label': 'Craigslist', 'value': 'craigslist'},
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

  group('SelectGroupScreenWidget marketplace icons', () {
    testWidgets('marketplace chips get built-in glyphs; brands use the Font Awesome brands font', (tester) async {
      await tester.pumpWidget(host(SelectGroupScreenWidget(model: model(), onChanged: (_) {})));

      final all = icons(tester).toList();
      // 6 marketplace options → 6 icons; the deals_per_month group has none.
      expect(all.length, 6);
      final brands = all.where((i) => i.icon?.fontFamily == 'FontAwesomeBrands').map((i) => i.icon!.codePoint);
      expect(brands, unorderedEquals([0xf4f4, 0xf270, 0xf09a])); // ebay, amazon, facebook
      expect(all.where((i) => i.icon?.fontFamily == 'FontAwesomeSolid').length, 2); // olx, craigslist
      expect(all.where((i) => i.icon == Icons.auto_awesome).length, 1); // other
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
