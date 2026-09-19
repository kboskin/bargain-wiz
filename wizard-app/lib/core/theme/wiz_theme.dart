import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens from the Bargain Wiz redesign handoff (design_handoff_bargain_wiz).
/// Colors, shadows, radii, spacing, type scale and motion durations.
/// Fonts: Outfit (display / CTA) and Figtree (body), bundled in assets/fonts.
class WizColors {
  WizColors._();

  // Ink & text
  static const Color ink = Color(0xFF14121B);
  static const Color textSecondary = Color(0xFF5B6270);
  static const Color textTertiary = Color(0xFF8A909C);
  static const Color border = Color(0xFFE6E2EC);
  static const Color borderStrong = Color(0xFFC9C2D6);
  static const Color divider = Color(0xFFEEEAF3);
  static const Color surfaceMuted = Color(0xFFF8F6FB);
  static const Color segmentTrack = Color(0xFFF3F0F7);

  // Brand accents
  static const Color teal = Color(0xFF4ECDC4);
  static const Color tealText = Color(0xFF117E76);
  static const Color tealInk = Color(0xFF0B3D39);
  static const Color amber = Color(0xFFC47A00);
  static const Color amberSoft = Color(0xFFFFF1E2);
  static const Color amberInk = Color(0xFF8A4B00);
  static const Color orange = Color(0xFFFF6B35);
  static const Color orangeText = Color(0xFFB14A16);
  static const Color yellow = Color(0xFFFFD166);
  static const Color yellowText = Color(0xFFB8860B);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color purpleSoft = Color(0x147B5EA7);
  static const Color purpleInk = Color(0xFF4B3F66);
  static const Color greyGlow = Color(0xFF9E9E9E);
  static const Color mintSoft = Color(0xFFEEF7F6);

  // Semantic
  static const Color error = Color(0xFFEF4444);
  static const Color errorText = Color(0xFFB42323);
  static const Color success = Color(0xFF10B981);
  static const Color successText = Color(0xFF067A55);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF59E0B);

  /// Push level stops: 20 / 40 / 60 / 80 / 100.
  static const List<Color> push = [
    Color(0xFFC026D3),
    Color(0xFF7E57C2),
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
    Color(0xFFEF4444),
  ];

  /// Intent tag colors for deal lines (text color, soft background).
  static const Color intentOpener = tealText;
  static const Color intentOpenerBg = Color(0x2E4ECDC4);
  static const Color intentCounter = orangeText;
  static const Color intentCounterBg = Color(0x29FF6B35);
  static const Color intentClose = purple;
  static const Color intentCloseBg = Color(0x247B5EA7);

  /// App gradient at 165°, stops 0 / .48 / 1.
  static const List<Color> appGradientColors = [
    Color(0xFFFFF3E6),
    Color(0xFFF4ECFF),
    Color(0xFFE7F6F8),
  ];
  static const List<double> appGradientStops = [0.0, 0.48, 1.0];
  static const double appGradientAngleDeg = 165;
  static LinearGradient get appBackground => angledGradient(
        appGradientColors,
        appGradientStops,
        appGradientAngleDeg,
      );

  /// Builds a [LinearGradient] matching CSS `linear-gradient(<angle>deg, ...)`.
  static LinearGradient angledGradient(
    List<Color> colors,
    List<double>? stops,
    double angleDeg,
  ) {
    final a = angleDeg * 3.141592653589793 / 180.0;
    // CSS: 0deg points up, 90deg points right. Direction vector:
    final dx = math.sin(a);
    final dy = -math.cos(a);
    return LinearGradient(
      begin: Alignment(-dx, -dy),
      end: Alignment(dx, dy),
      colors: colors,
      stops: stops != null && stops.length == colors.length ? stops : null,
    );
  }

  // Frosted surface recipe: white 72%, blur σ≈10, 1px border white 95%.
  static const Color frosted = Color(0xB8FFFFFF); // 72%
  static const Color frostedBorder = Color(0xF2FFFFFF); // 95%
  static const Color frostedStrong = Color(0xDBFFFFFF); // 86% sheets
  static const Color frostedDialog = Color(0xE6FFFFFF); // 90% dialogs
  static const Color frostedBar = Color(0xCCFFFFFF); // 80% tab bar
  static const Color frostedDrawer = Color(0xD1FFFFFF); // 82% drawer
  static const Color frostedLight = Color(0x8CFFFFFF); // 55% welcome hero
  static const Color scrim = Color(0x5914121B); // 35% ink
  static const Color inkSoft = Color(0x0F14121B); // 6%
  static const Color inkFaint = Color(0x0D14121B); // 5%
  static const Color inkTrack = Color(0x1A14121B); // 10%
  static const Color inkMeter = Color(0x1414121B); // 8%
  static const Color inkOverlay = Color(0xB314121B); // 70%
  static const Color tabActivePill = Color(0x297B5EA7); // 16% purple
  static const Color tealCopied = Color(0x474ECDC4); // 28%
  static const Color tealSoft = Color(0x334ECDC4); // 20%
  static const Color tealHint = Color(0x2E4ECDC4); // 18%
  static const Color likedBg = Color(0x4010B981); // 25%
  static const Color dislikedBg = Color(0x33EF4444); // 20%
  static const Color statusWonBg = Color(0x2910B981);
  static const Color statusLostBg = Color(0x1FEF4444);
  static const Color statusOpenBg = inkMeter;
}

class WizShadows {
  WizShadows._();
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14463270), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> cardSoft = [
    BoxShadow(color: Color(0x0F463270), blurRadius: 14, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> cardStrong = [
    BoxShadow(color: Color(0x1A463270), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> pill = [
    BoxShadow(color: Color(0x2E14121B), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> roundButton = [
    BoxShadow(color: Color(0x1A463270), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x2E463270), blurRadius: 40, offset: Offset(0, -12)),
  ];
  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x40463270), blurRadius: 50, offset: Offset(0, 20)),
  ];
  static const List<BoxShadow> screenshot = [
    BoxShadow(color: Color(0x1F463270), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> selectedPlan = [
    BoxShadow(color: Color(0x73FFD166), spreadRadius: 4),
    BoxShadow(color: Color(0x1F14121B), blurRadius: 26, offset: Offset(0, 10)),
  ];
}

class WizRadii {
  WizRadii._();
  static const double pill = 28;
  static const double pillSm = 26;
  static const double pillXs = 18;
  static const double card = 18;
  static const double cardLg = 20;
  static const double cardXl = 22;
  static const double cardHero = 28;
  static const double sheet = 32;
  static const double field = 16;
  static const double thumb = 10;
  static const double thumbLg = 14;
  static const double thumbXl = 16;
  static const double checkbox = 8;
  static const double chip = 999;
}

class WizSpacing {
  WizSpacing._();
  static const double gutter = 20;
  static const double stack = 10;
  static const double stackLg = 14;
  static const double section = 18;
  static const double tabBarHeight = 84;
  static const double tabBarContentPadding = 100;
  static const double composerHeight = 108;
  static const double homeIndicator = 34;
}

class WizType {
  WizType._();
  static const String display = 'Outfit';
  static const String bodyFont = 'Figtree';

  static const TextStyle welcomeTitle = TextStyle(
    fontFamily: display, fontSize: 40, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: WizColors.ink);
  static const TextStyle headline = TextStyle(
    fontFamily: display, fontSize: 34, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.68, color: WizColors.ink);
  static const TextStyle titleXl = TextStyle(
    fontFamily: display, fontSize: 30, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: WizColors.ink);
  static const TextStyle title = TextStyle(
    fontFamily: display, fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.28, color: WizColors.ink);
  static const TextStyle titleMd = TextStyle(
    fontFamily: display, fontSize: 26, height: 1.15, fontWeight: FontWeight.w700, color: WizColors.ink);
  static const TextStyle titleSm = TextStyle(
    fontFamily: display, fontSize: 24, height: 1.15, fontWeight: FontWeight.w700, color: WizColors.ink);
  static const TextStyle titleXs = TextStyle(
    fontFamily: display, fontSize: 22, height: 1.2, fontWeight: FontWeight.w700, color: WizColors.ink);
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: display, fontSize: 18, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: display, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.17, color: WizColors.ink);
  static const TextStyle cta = TextStyle(
    fontFamily: display, fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white);
  static const TextStyle ctaSm = TextStyle(
    fontFamily: display, fontSize: 15, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle optionLabel = TextStyle(
    fontFamily: display, fontSize: 16, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle optionInitial = TextStyle(
    fontFamily: display, fontSize: 16, fontWeight: FontWeight.w700);
  static const TextStyle cardTitle = TextStyle(
    fontFamily: display, fontSize: 15, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle status = TextStyle(
    fontFamily: display, fontSize: 20, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle statusSm = TextStyle(
    fontFamily: display, fontSize: 16, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle bigValue = TextStyle(
    fontFamily: display, fontSize: 44, fontWeight: FontWeight.w700, color: WizColors.ink, height: 1.05);
  static const TextStyle intentTag = TextStyle(
    fontFamily: display, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.66);

  static const TextStyle body = TextStyle(
    fontFamily: bodyFont, fontSize: 16, height: 1.45, fontWeight: FontWeight.w400, color: WizColors.ink);
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: bodyFont, fontSize: 16, height: 1.45, fontWeight: FontWeight.w400, color: WizColors.textSecondary);
  static const TextStyle bodyLg = TextStyle(
    fontFamily: bodyFont, fontSize: 17, height: 1.4, fontWeight: FontWeight.w400, color: WizColors.textSecondary);
  static const TextStyle bodyMd = TextStyle(
    fontFamily: bodyFont, fontSize: 15, height: 1.4, fontWeight: FontWeight.w400, color: WizColors.textSecondary);
  static const TextStyle bodyMdInk = TextStyle(
    fontFamily: bodyFont, fontSize: 15, height: 1.4, fontWeight: FontWeight.w400, color: WizColors.ink);
  static const TextStyle bodyMdStrong = TextStyle(
    fontFamily: bodyFont, fontSize: 15, height: 1.4, fontWeight: FontWeight.w500, color: WizColors.ink);
  static const TextStyle bodySm = TextStyle(
    fontFamily: bodyFont, fontSize: 14, height: 1.4, fontWeight: FontWeight.w400, color: WizColors.textSecondary);
  static const TextStyle bodySmStrong = TextStyle(
    fontFamily: bodyFont, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500, color: WizColors.ink);
  static const TextStyle bodySmBold = TextStyle(
    fontFamily: bodyFont, fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle replyLine = TextStyle(
    fontFamily: bodyFont, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500, color: WizColors.ink);
  static const TextStyle chat = TextStyle(
    fontFamily: bodyFont, fontSize: 15, height: 1.45, fontWeight: FontWeight.w400, color: WizColors.ink);
  static const TextStyle caption = TextStyle(
    fontFamily: bodyFont, fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, color: WizColors.textSecondary);
  static const TextStyle captionStrong = TextStyle(
    fontFamily: bodyFont, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle captionMedium = TextStyle(
    fontFamily: bodyFont, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500, color: WizColors.ink);
  static const TextStyle chip = TextStyle(
    fontFamily: bodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle chipSm = TextStyle(
    fontFamily: bodyFont, fontSize: 11, fontWeight: FontWeight.w600, color: WizColors.ink);
  static const TextStyle label = TextStyle(
    fontFamily: bodyFont, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.96, color: WizColors.textTertiary);
  static const TextStyle badge = TextStyle(
    fontFamily: bodyFont, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.44, color: WizColors.ink);
  static const TextStyle tabLabel = TextStyle(
    fontFamily: bodyFont, fontSize: 11, fontWeight: FontWeight.w600);
  static const TextStyle stepCounter = TextStyle(
    fontFamily: bodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: WizColors.textTertiary);
  static const TextStyle toast = TextStyle(
    fontFamily: bodyFont, fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white);
  static const TextStyle footnote = TextStyle(
    fontFamily: bodyFont, fontSize: 12, height: 1.4, fontWeight: FontWeight.w400, color: WizColors.textTertiary);
  static const TextStyle fieldText = TextStyle(
    fontFamily: bodyFont, fontSize: 15, fontWeight: FontWeight.w400, color: WizColors.ink);
  static const TextStyle code = TextStyle(
    fontFamily: bodyFont, fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 1.44, color: WizColors.ink);
}

class WizMotion {
  WizMotion._();
  static const Duration fadeUp = Duration(milliseconds: 350);
  static const Duration replyEnter = Duration(milliseconds: 400);
  static const Duration listStagger = Duration(milliseconds: 50);
  static const Duration historyStagger = Duration(milliseconds: 60);
  static const Duration chipStagger = Duration(milliseconds: 100);
  static const Duration replyStagger = Duration(milliseconds: 120);
  static const Duration scan = Duration(milliseconds: 1600);
  static const Duration pulse = Duration(milliseconds: 1800);
  static const Duration bob = Duration(milliseconds: 1600);
  static const Duration typingBlink = Duration(milliseconds: 1200);
  static const Duration eq = Duration(milliseconds: 600);
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration scrim = Duration(milliseconds: 200);
  static const Duration copiedHold = Duration(milliseconds: 1200);
  static const Duration toast = Duration(milliseconds: 1500);
  static const Duration progress = Duration(milliseconds: 350);
  static const Duration fill = Duration(milliseconds: 400);
  static const Duration uploadMock = Duration(milliseconds: 2200);
  static const Duration typingMock = Duration(milliseconds: 1300);
  static const Duration paywallClose = Duration(seconds: 5);
  static const Curve spring = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve easeOut = Curves.easeOutCubic;
}
