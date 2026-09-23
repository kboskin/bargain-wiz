import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/permission_screen_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reviewChannel = MethodChannel('dev.britannio.in_app_review');
  final reviewCalls = <String>[];

  setUpAll(() {
    if (!di.sl.isRegistered<AssetPathHelper>()) {
      di.sl.registerLazySingleton<AssetPathHelper>(AssetPathHelper.new);
    }
  });

  setUp(() {
    reviewCalls.clear();
    // Real platform responses never arrive inside the test's fake clock, so answer the
    // review plugin here: store unavailable → the screen must still continue.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      reviewChannel,
      (call) async {
        reviewCalls.add(call.method);
        return call.method == 'isAvailable' ? false : null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(reviewChannel, null);
  });

  PermissionScreenModel model({
    List<Map<String, dynamic>>? buttons,
    String visual = 'assets/images/wizard_yes_cutout.png',
    double size = 120,
  }) =>
      PermissionScreenModel.fromJson({
        'type': 'permission',
        'subtype': 'rate_us',
        'title': 'Enjoying Bargain Wiz so far?',
        'description': 'A quick rating helps other buyers find their wizard.',
        'visual': visual,
        'metadata': {
          'width': size,
          'height': size,
          'button_visual': 'assets/lottie/magic_stick_pointer.json',
          if (buttons != null) 'buttons': buttons,
        },
      });

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Scaffold(body: child),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('PermissionScreenWidget rate_us', () {
    testWidgets('the visual is drawn at the size the template asks for', (tester) async {
      await tester.pumpWidget(host(PermissionScreenWidget(model: model(size: 220), onContinue: () {})));
      await settle(tester);

      final art = tester.widget<VisualAssetWidget>(find.byType(VisualAssetWidget).first);
      expect(art.visualPath, 'assets/images/wizard_yes_cutout.png');
      expect(art.width, 220);
      expect(art.height, 220);
    });

    testWidgets('the shipped 330 pt visual still fits a phone without overflowing',
        (tester) async {
      // Mirrors onboarding_screens' rate_us metadata. A visual that large leaves little room
      // for the title, body and two buttons, and a RenderFlex overflow is an exception here.
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(host(PermissionScreenWidget(model: model(size: 330), onContinue: () {})));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Rate us'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('and still fits the shortest phone we support', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568)); // iPhone SE 1st gen
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(host(PermissionScreenWidget(model: model(size: 330), onContinue: () {})));
      await settle(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('default labels; both buttons continue (store review unavailable in tests)', (tester) async {
      var continued = 0;
      await tester.pumpWidget(host(PermissionScreenWidget(model: model(), onContinue: () => continued++)));
      await settle(tester);

      expect(find.text('Rate us'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.text('Rate us'));
      await settle(tester);
      expect(reviewCalls, ['isAvailable']);
      expect(continued, 1);

      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(continued, 2);
      expect(reviewCalls, ['isAvailable']); // secondary never asks the store
      expect(tester.takeException(), isNull);
    });

    testWidgets('labels come from metadata.buttons and a "rate" action marks the primary', (tester) async {
      final m = model(buttons: [
        {'text': 'Later', 'action': 'continue'},
        {'text': {'en': 'Give 5 stars', 'es': 'Danos 5 estrellas'}, 'action': 'rate'},
      ]);
      await tester.pumpWidget(host(PermissionScreenWidget(model: m)));
      await settle(tester);

      expect(find.text('Give 5 stars'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Rate us'), findsNothing);
    });
  });
}
