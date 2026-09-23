import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/presentation/widgets/paywall_step_view.dart';

/// The explainer screens before the plans: their art is sized by the template, and it has to
/// survive a phone that has no room for it.
void main() {
  setUpAll(() {
    if (!di.sl.isRegistered<AssetPathHelper>()) {
      di.sl.registerLazySingleton<AssetPathHelper>(AssetPathHelper.new);
    }
  });

  PaywallStepConfig step({double? size}) => PaywallStepConfig.fromJson({
        'id': 'intro',
        'title': {'en': 'We want you to try Bargain Wiz for free.'},
        'description': {'en': 'Scan screenshots and chats to unlock smarter deals.'},
        'visual': 'assets/lottie/wizard_hearts.json',
        'note_text': {'en': 'No payment due now.'},
        'button_text': {'en': r'Try for $0.00'},
        if (size != null) 'visual_size': size,
      });

  Future<void> pump(WidgetTester tester, PaywallStepConfig config, {Size? surface}) async {
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaywallStepView(
            step: config,
            buttonLabel: r'Try for $0.00',
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the animation is drawn at the size the template asks for', (tester) async {
    await pump(tester, step(size: 270));
    final art = tester.widget<VisualAssetWidget>(find.byType(VisualAssetWidget));
    expect(art.visualPath, 'assets/lottie/wizard_hearts.json');
    expect(art.width, 270);
    expect(art.height, 270);
  });

  testWidgets('a step that names no size keeps the handoff default', (tester) async {
    await pump(tester, step());
    final art = tester.widget<VisualAssetWidget>(find.byType(VisualAssetWidget));
    expect(art.width, PaywallStepConfig.defaultVisualSize);
  });

  testWidgets('the copy and the CTA are still reachable at 270 on a small phone',
      (tester) async {
    await pump(tester, step(size: 270), surface: const Size(320, 568));
    expect(tester.takeException(), isNull);
    // The art scrolls; the note and the button stay pinned at the bottom.
    expect(find.text(r'Try for $0.00'), findsOneWidget);
    expect(find.text('No payment due now.'), findsOneWidget);
  });

  testWidgets('and on a normal phone', (tester) async {
    await pump(tester, step(size: 270), surface: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('try Bargain Wiz for free'), findsOneWidget);
  });
}
