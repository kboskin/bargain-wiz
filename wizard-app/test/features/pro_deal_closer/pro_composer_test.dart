import 'package:appwizard/core/config/attachment_limits.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/pro_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A turn is whatever the composer holds when Send is tapped: screenshots picked with "+" wait
/// in the strip and go out together with the typed text.
void main() {
  late List<(String, List<String>)> sent;
  late List<String> picks;

  setUp(() {
    sent = [];
    picks = ['/tmp/a.jpg', '/tmp/b.jpg'];
  });

  Future<void> pumpComposer(final WidgetTester tester, {final bool enabled = true}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ProComposer(
                enabled: enabled,
                showMic: false,
                onAttach: () async => picks,
                onSend: (final text, final paths) => sent.add((text, paths)),
              ),
            ),
          ),
        ),
      );

  final attach = find.byIcon(Icons.add_rounded);
  final send = find.byIcon(Icons.arrow_upward_rounded);
  final remove = find.byIcon(Icons.close_rounded);

  testWidgets('picking stages screenshots and sends nothing until Send', (final tester) async {
    await pumpComposer(tester);

    await tester.tap(attach);
    await tester.pump();
    expect(remove, findsNWidgets(2));
    expect(sent, isEmpty);

    await tester.enterText(find.byType(TextField), '  My budget is 70  ');
    await tester.tap(send);
    await tester.pump();

    expect(sent.single.$1, 'My budget is 70');
    expect(sent.single.$2, ['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(remove, findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('screenshots alone can be sent, without the one removed', (final tester) async {
    await pumpComposer(tester);
    await tester.tap(attach);
    await tester.pump();

    await tester.tap(remove.first);
    await tester.pump();
    await tester.tap(send);
    await tester.pump();

    expect(sent.single.$1, isEmpty);
    expect(sent.single.$2, ['/tmp/b.jpg']);
  });

  testWidgets('Send waits while the wizard answers and keeps the draft', (final tester) async {
    await pumpComposer(tester, enabled: false);
    await tester.tap(attach);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'hello');

    await tester.tap(send);
    await tester.pump();

    expect(sent, isEmpty);
    expect(remove, findsNWidgets(2));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'hello');
  });

  testWidgets('stages at most one message worth of screenshots', (final tester) async {
    picks = [for (var i = 0; i < AttachmentLimits.maxImages + 2; i++) '/tmp/$i.jpg'];
    await pumpComposer(tester);

    await tester.tap(attach);
    await tester.pump();
    await tester.tap(send);
    await tester.pump();

    expect(sent.single.$2, [for (var i = 0; i < AttachmentLimits.maxImages; i++) '/tmp/$i.jpg']);
    expect(find.text('Up to ${AttachmentLimits.maxImages} screenshots per message'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // let the toast go
  });
}
