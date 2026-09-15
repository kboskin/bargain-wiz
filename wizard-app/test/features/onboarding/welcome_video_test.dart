import 'package:appwizard/features/onboarding/data/models/remote_config/welcome_screen_config.dart';
import 'package:appwizard/features/onboarding/presentation/pages/welcome_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/welcome_hero_video.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> welcomeJson({Map<String, dynamic>? video}) => {
        'title': 'Get the Best Deals',
        'description': 'Outsmart every price.',
        'visual': 'assets/images/wizard_cutout.png',
        'primary_button_text': 'Get Started',
        if (video != null) 'video': video,
      };

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: child,
      );

  group('WelcomeVideoConfig', () {
    test('parses with defaults and reports enabled/network state', () {
      final cfg = WelcomeScreenConfig.fromJson(welcomeJson(video: {'url': 'https://cdn.example.com/how-it-works.mp4'}));
      expect(cfg.video, isNotNull);
      expect(cfg.video!.isEnabled, isTrue);
      expect(cfg.video!.isNetwork, isTrue);
      expect(cfg.video!.loop, isTrue);
      expect(cfg.video!.muted, isTrue);
      cfg.validate();
    });

    test('empty url disables the video; asset paths are not network', () {
      expect(WelcomeScreenConfig.fromJson(welcomeJson()).video, isNull);
      final empty = WelcomeScreenConfig.fromJson(welcomeJson(video: {'url': ''})).video!;
      expect(empty.isEnabled, isFalse);
      final asset = WelcomeVideoConfig(url: 'assets/video/intro.mp4', loop: false, muted: false);
      expect(asset.isNetwork, isFalse);
      expect(asset.loop, isFalse);
      expect(asset.toJson(), {'url': 'assets/video/intro.mp4', 'loop': false, 'muted': false});
    });
  });

  group('WelcomeScreenWidget hero', () {
    testWidgets('without a video the mascot poster is shown', (tester) async {
      await tester.pumpWidget(host(WelcomeScreenWidget(config: WelcomeScreenConfig.fromJson(welcomeJson()))));
      expect(find.byType(WelcomeHeroVideo), findsNothing);
      expect(find.byType(WizMascot), findsOneWidget);
    });

    testWidgets('with a video the hero mounts the player and keeps the poster until it can play',
        (tester) async {
      final cfg = WelcomeScreenConfig.fromJson(
        welcomeJson(video: {'url': 'https://cdn.example.com/how-it-works.mp4'}),
      );
      await tester.pumpWidget(host(WelcomeScreenWidget(config: cfg)));
      await tester.pump();
      // No video platform in tests → initialize() fails → poster fallback, no crash.
      expect(find.byType(WelcomeHeroVideo), findsOneWidget);
      expect(find.byType(WizMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
