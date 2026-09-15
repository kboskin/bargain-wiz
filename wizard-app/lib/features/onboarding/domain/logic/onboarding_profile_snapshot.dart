import 'dart:ui' show Color;

import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// One summary chip for the warmup screen.
class SummaryChipSpec {
  const SummaryChipSpec({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;
}

/// Read-only view of the answers collected *so far* in the onboarding flow
/// (nothing is persisted until the end), resolved against the [WizCatalog].
///
/// Used by the warmup and data-upload templates to fill placeholders such as
/// `{monthly_leak}`, `{vibe}`, `{push}`, `{push_emoji}`, `{savings}`,
/// `{deal_size}`, `{platform}` and `{leak_count}`.
class OnboardingProfileSnapshot {
  OnboardingProfileSnapshot({
    required Map<String, dynamic> answers,
    WizCatalog catalog = const WizCatalog(),
    this.languageCode = 'en',
    Map<String, int>? dealsMultiplierOverride,
  })  : _answers = answers,
        catalog = dealsMultiplierOverride == null || dealsMultiplierOverride.isEmpty
            ? catalog
            : WizCatalog(
                vibes: catalog.vibes,
                pushLevels: catalog.pushLevels,
                dealSizes: catalog.dealSizes,
                dealsMultiplier: dealsMultiplierOverride,
              );

  static const String keyVibe = 'negotiation_vibe';
  static const String keyPush = 'risk_tolerance';
  static const String keyMarketplace = 'favorite_marketplace';
  static const String keyDealsPerMonth = 'deals_per_month';
  static const String keyDealSize = 'average_deal_size';
  static const String keyHurdles = 'main_hurdle';

  final Map<String, dynamic> _answers;
  final WizCatalog catalog;
  final String languageCode;

  dynamic answer(String key) => _answers[key];

  String get vibeId => answer(keyVibe)?.toString() ?? WizCatalog.defaultVibeId;
  VibeDef get vibe => catalog.vibeById(vibeId);

  int get pushValue => _asInt(answer(keyPush)) ?? WizCatalog.defaultPushValue;
  PushDef get push => catalog.pushForValue(pushValue);

  int get dealSizeValue => _asInt(answer(keyDealSize)) ?? WizCatalog.defaultDealSizeValue;
  DealSizeDef get dealSize => catalog.dealSizeForValue(dealSizeValue);

  String? get marketplace => answer(keyMarketplace)?.toString();
  String? get dealsPerMonth => answer(keyDealsPerMonth)?.toString();

  List<String> get hurdles {
    final v = answer(keyHurdles);
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  /// `savings_high(deal_size) × multiplier(deals_per_month)`.
  int get monthlyLeak => catalog.monthlyLeak(dealSize: dealSizeValue, dealsPerMonth: dealsPerMonth);

  /// "$550" / "$7,200".
  String get monthlyLeakText => formatMoney(monthlyLeak);

  /// "Facebook Marketplace" (or [fallback]).
  String platformLabel({String fallback = 'Any marketplace'}) =>
      WizCatalog.marketplaceLabel(marketplace, fallback: fallback);

  String get vibeShort => localize(vibe.short, languageCode);
  String get pushLabel => localize(push.label, languageCode);
  String get pushSubtext => localize(push.subtext, languageCode);
  String get dealSizeLabel => localize(dealSize.label, languageCode);

  /// Placeholders for body copy: vibe / push lowercased so they read inline
  /// ("A friendly wizard with a balanced push …").
  Map<String, String?> get bodyPlaceholders => {
        ..._basePlaceholders,
        'vibe': vibeShort.toLowerCase(),
        'push': pushLabel.toLowerCase(),
      };

  /// Placeholders for chips / status lines: labels keep their casing
  /// ("Friendly wizard", "⚖️ Balanced", "Studying Facebook Marketplace sellers…").
  Map<String, String?> get chipPlaceholders => _basePlaceholders;

  Map<String, String?> get _basePlaceholders => {
        'vibe': vibeShort,
        'push': pushLabel,
        'push_emoji': push.emoji,
        'savings': dealSize.savingsRange,
        'deal_size': dealSizeLabel,
        'platform': platformLabel(),
        'leak_count': hurdles.isEmpty ? '' : '${hurdles.length}',
        'monthly_leak': monthlyLeakText,
      };

  /// Fills [template] with the body placeholders.
  String fillBody(String template) => TemplateText.fill(template, bodyPlaceholders);

  /// Fills [template] with the chip placeholders and tidies empty counts
  /// ("{leak_count} money leaks → plugged" with no picks → "Money leaks → plugged").
  String fillChip(String template) {
    var s = TemplateText.fill(template, chipPlaceholders).replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (s.isNotEmpty && hurdles.isEmpty && template.contains('{leak_count}')) {
      s = s[0].toUpperCase() + s.substring(1);
    }
    return s;
  }

  /// Chips styled by what they describe: vibe → vibe color, push → stop color,
  /// platform → ink, anything else → white 85%.
  List<SummaryChipSpec> chips(List<String> templates) => [
        for (final t in templates)
          if (fillChip(t).isNotEmpty)
            SummaryChipSpec(
              label: fillChip(t),
              background: _chipBackground(t),
              foreground: _chipForeground(t),
            ),
      ];

  Color _chipBackground(String template) {
    if (template.contains('{vibe}')) return vibe.color;
    if (template.contains('{push}')) return push.color;
    if (template.contains('{platform}')) return WizColors.ink;
    return const Color(0xD9FFFFFF); // white 85%
  }

  Color _chipForeground(String template) {
    if (template.contains('{vibe}')) return vibe.textOnColor;
    if (template.contains('{push}')) return const Color(0xFFFFFFFF);
    if (template.contains('{platform}')) return const Color(0xFFFFFFFF);
    return WizColors.ink;
  }

  /// "$" + thousands-separated integer: 550 → "$550", 7200 → "$7,200".
  static String formatMoney(int amount) => '\$${formatThousands(amount)}';

  static String formatThousands(int n) {
    final negative = n < 0;
    final digits = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return '${negative ? '-' : ''}$buf';
  }

  /// Locale-resolves a remote value (String, `{en:..}` map or [MultilocaleText]) without a BuildContext.
  static String localize(dynamic source, String languageCode) {
    if (source == null) return '';
    if (source is MultilocaleText) return localize(source.toJson(), languageCode);
    if (source is String) return source;
    if (source is Map) {
      final v = source[languageCode] ?? source['en'] ?? (source.values.isEmpty ? null : source.values.first);
      return v?.toString() ?? '';
    }
    return source.toString();
  }

  static int? _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
