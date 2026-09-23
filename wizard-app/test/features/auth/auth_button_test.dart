import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/auth/presentation/widgets/auth_button.dart';
import 'package:appwizard/l10n/app_localizations.dart';

void main() {
  Widget host(Widget button) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: button)),
      );

  testWidgets('Google button shows the Google logo and the localized label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(GoogleSignInButton(onTap: () => taps++)));

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.tap(find.byType(GoogleSignInButton));
    expect(taps, 1);
  });

  testWidgets('a template label replaces the default', (tester) async {
    await tester.pumpWidget(host(GoogleSignInButton(label: 'Continue with Google', onTap: () {})));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
  });

  testWidgets('loading shows a spinner and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(GoogleSignInButton(loading: true, onTap: () => taps++)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);

    await tester.tap(find.byType(GoogleSignInButton));
    expect(taps, 0);
  });

  testWidgets('Apple button shows the Apple glyph and the localized label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppleSignInButton(onTap: () => taps++)));

    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);

    await tester.tap(find.byType(AppleSignInButton));
    expect(taps, 1);
  });
}
