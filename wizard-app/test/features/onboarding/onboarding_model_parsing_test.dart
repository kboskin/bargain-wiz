import 'dart:convert';
import 'dart:io';

import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _loadDefaultScreens() {
  final file = File('assets/config/remote_config_defaults.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final raw = root['onboarding_screens'];
  final list = raw is String ? jsonDecode(raw) : raw;
  return (list as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

void main() {
  late List<Map<String, dynamic>> raw;
  late List<OnboardingModel> screens;

  setUpAll(() {
    raw = _loadDefaultScreens();
    screens = raw.map(OnboardingModel.fromJson).toList();
  });

  test('parses the 10-screen default order with the new types', () {
    expect(screens.map((s) => s.type), [
      OnboardingScreenType.multiSelect,
      OnboardingScreenType.select,
      OnboardingScreenType.sliderLottie,
      OnboardingScreenType.selectGroup,
      OnboardingScreenType.slider,
      OnboardingScreenType.warmup,
      OnboardingScreenType.permission,
      OnboardingScreenType.referralCode,
      OnboardingScreenType.createAccount,
      OnboardingScreenType.dataUpload,
    ]);
    for (final s in screens) {
      s.validate();
    }
  });

  test('OnboardingScreenType.fromString knows the new snake_case ids', () {
    expect(OnboardingScreenType.fromString('multi_select'), OnboardingScreenType.multiSelect);
    expect(OnboardingScreenType.fromString('select_group'), OnboardingScreenType.selectGroup);
  });

  test('multi_select: options, min_selected, reassurance and multi answer key', () {
    final m = screens[0] as MultiSelectScreenModel;
    expect(m.options.length, 5);
    expect(m.options.first.storedValue, 'starting');
    expect(m.options.first.colorHex, '#C47A00');
    expect(m.minSelected, 1);
    expect(m.reassuranceByCount.length, 3);
    expect(m.reassuranceFor(1)!.toJson()['en'], startsWith('One leak'));
    expect(m.reassuranceFor(7)!.toJson()['en'], startsWith("You've been the easiest"));
    expect(m.answerStructure!.answerKeyName, 'hurdles');
    expect(m.answerStructure!.multi, isTrue);
    expect(m.answerKeys, ['hurdles']);
    expect((m.titleHighlights as Map)['slipped away'], '#C47A00');
    expect(m.effectiveHighlightColor, '#C47A00');
  });

  test('select: require_explicit_tap and option subtext/short metadata', () {
    final m = screens[1] as SelectScreenModel;
    expect(m.requireExplicitTap, isTrue);
    expect(m.options.map((o) => o.storedValue), ['friendly', 'no_nonsense', 'tactical', 'quiet_closer']);
    expect(m.options[2].colorHex, '#FFD166');
    expect(m.options[0].subtext, isNotNull);
    expect(m.options[0].metadata!.short, isNotNull);
  });

  test('slider_lottie: five stops sorted with default 60', () {
    final m = screens[2] as SliderLottieScreenModel;
    expect(m.stops.map((s) => s.value), [20, 40, 60, 80, 100]);
    expect(m.stops[2].emoji, '⚖️');
    expect(m.stops[2].colorHex, '#0EA5E9');
    expect(m.defaultValue, 60);
    expect(m.stopIndexFor(null), 2);
    expect(m.stopIndexFor(80), 3);
    expect((m.descriptionHighlights as Map)['magic tube'], '#FF6B35');
  });

  test('select (vibe): every option carries a Font Awesome icon', () {
    final m = screens[1] as SelectScreenModel;
    for (final o in m.options) {
      expect(o.hasIcon, isTrue, reason: o.storedValue);
      expect((o.iconRaw as Map)['font'], isIn(['solid', 'regular']));
    }
  });

  test('select_group: two groups writing one answer each', () {
    final m = screens[3] as SelectGroupScreenModel;
    expect(m.groups.length, 2);
    expect(m.answerKeys, ['marketplace', 'deals_per_month']);
    expect(m.groups[0].options.map((o) => o.storedValue), ['ebay', 'amazon', 'facebook', 'olx', 'craigslist', 'other']);
    expect(m.groups[1].options.map((o) => o.storedValue), ['0_2', '3_5', '6_plus']);
    expect(m.answerStructure, isNull);
  });

  test('slider: metadata options with savings, scale, pill and default index', () {
    final m = screens[4] as SliderScreenModel;
    expect(m.options.length, 3);
    expect(m.sortedOptions.map((o) => o.intValue), [50, 550, 5000]);
    expect(m.sortedOptions[1].savingsRange, r'$45–110');
    expect(m.sortedOptions[1].scale, 0.9);
    expect(m.defaultIndex, 1);
    expect(m.savingsPill, isNotNull);
    expect(m.savingsPill.toJson()['en'], contains('{savings}'));
  });

  test('warmup: placeholders in title, summary chips per locale, deals multiplier', () {
    final m = screens[5] as WarmupScreenModel;
    expect(m.title.toJson()['en'], contains('{monthly_leak}'));
    expect((m.titleHighlights as Map).keys, contains('{monthly_leak}'));
    expect((m.descriptionHighlights as Map)['Studies reveal:'], 'bold');
    expect(m.summaryChipsFor('en'), [
      '{vibe} wizard',
      '{push_emoji} {push}',
      '{marketplace}',
      '{leak_count} money leaks → plugged',
    ]);
    expect(m.summaryChipsFor('es').first, 'Mago {vibe}');
    expect(m.summaryChipsFor('fr'), m.summaryChipsFor('en'));
    expect(m.dealsMultiplier, {'0_2': 2, '3_5': 5, '6_plus': 8});
    expect(m.metadata!.sideTextAlignment, SideTextAlignment.top);
    expect(m.visual, 'assets/lottie/falling_money.json');
  });

  test('permission (rate_us): star visual, wand button visual and two buttons', () {
    final m = screens[6] as PermissionScreenModel;
    expect(m.subtype, 'rate_us');
    expect(m.visual, 'assets/lottie/star_anim.json');
    expect(m.metadata!.buttonVisual, 'assets/lottie/magic_stick_pointer.json');
    final buttons = m.metadata!.buttons!;
    expect(buttons.length, 2);
    expect((buttons[1] as Map)['action'], 'rate');
    expect((m.titleHighlights as Map)['Bargain Wiz'], '#4ECDC4');
  });

  test('referral_code: screen-level highlights win over metadata highlights', () {
    final m = screens[7] as ReferralCodeScreenModel;
    expect((m.titleHighlights as Map)['(Optional)'], '#8A909C');
    expect((m.descriptionHighlights as Map)['benefits'], '#117E76');
    expect(m.placeholder, isNotNull);
  });

  test('create_account: visual + labels + top bar', () {
    final m = screens[8] as CreateAccountScreenModel;
    expect(m.visual, 'assets/images/wizard_cutout.png');
    expect(m.showTopBar, isTrue);
    expect(m.googleButtonLabel, isNotNull);
    expect(m.appleButtonLabel, isNotNull);
  });

  test('data_upload: upload config with done text, hold and gradient', () {
    final m = screens[9] as DataUploadScreenModel;
    expect(m.showTopBar, isFalse);
    expect(m.showNextButton, isFalse);
    final cfg = m.toUploadProgressConfig()!;
    expect(cfg.lottieAsset, 'assets/lottie/pot.json');
    expect(cfg.texts.length, 3);
    expect(cfg.textIntervalSeconds, 2.5);
    expect(cfg.progressRampSeconds, 5);
    expect(cfg.doneHoldSeconds, 1.4);
    expect(cfg.progressGradient, ['#7B5EA7', '#4ECDC4']);
    expect(cfg.doneText, isNotNull);
  });

  test('toJson keeps the snake_case contract for the new types', () {
    for (final s in screens) {
      expect(s.toJson()['type'], s.type.name);
    }
    final multi = screens[0].toJson();
    expect((multi['answer_structure'] as Map)['multi'], isTrue);
    expect((multi['highlight_words'] as Map)['title'], isA<Map>());
    expect(multi['options'], isA<List>());
    final group = screens[3].toJson();
    expect((group['groups'] as List).length, 2);
    expect(((group['groups'] as List).first as Map)['answer_key_name'], 'marketplace');
    final upload = screens[9].toJson();
    expect(upload['show_top_bar'], isFalse);
    expect(upload['show_next_button'], isFalse);
  });
}
