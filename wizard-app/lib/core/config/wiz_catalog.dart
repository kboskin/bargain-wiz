import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/icon_resolver.dart';
import 'package:appwizard/core/utils/template_text.dart';

/// Negotiation vibe (tone) preset. Ids match onboarding `negotiation_vibe` values.
class VibeDef {
  const VibeDef({
    required this.id,
    required this.label,
    required this.short,
    required this.color,
    required this.textOnColor,
    required this.chipTextColor,
    required this.subtext,
    this.icon,
  });

  final String id;
  /// Full label, e.g. "Friendly Collaborator" (String or multilocale map).
  final dynamic label;
  /// Short label for chips, e.g. "Friendly".
  final dynamic short;
  final Color color;
  /// Text color when [color] is used as a fill.
  final Color textOnColor;
  /// AA-safe color when the vibe is shown as text / header chip.
  final Color chipTextColor;
  final dynamic subtext;

  /// Glyph shown on option cards and chips (Font Awesome by default; remote `icon` overrides).
  final IconData? icon;

  String labelOf(BuildContext c) => TemplateText.textOf(c, label);
  String shortOf(BuildContext c) => TemplateText.textOf(c, short);
  String subtextOf(BuildContext c) => TemplateText.textOf(c, subtext);
}

/// Push level (risk_tolerance) stop. Values 20/40/60/80/100.
class PushDef {
  const PushDef({
    required this.value,
    required this.label,
    required this.subtext,
    required this.emoji,
    required this.color,
  });

  final int value;
  final dynamic label;
  final dynamic subtext;
  final String emoji;
  final Color color;

  String labelOf(BuildContext c) => TemplateText.textOf(c, label);
  String subtextOf(BuildContext c) => TemplateText.textOf(c, subtext);
}

/// Typical deal size stop with savings range.
class DealSizeDef {
  const DealSizeDef({
    required this.value,
    required this.label,
    required this.subtext,
    required this.savingsLow,
    required this.savingsHigh,
  });

  final int value;
  final dynamic label;
  final dynamic subtext;
  final int savingsLow;
  final int savingsHigh;

  String labelOf(BuildContext c) => TemplateText.textOf(c, label);
  String subtextOf(BuildContext c) => TemplateText.textOf(c, subtext);
  String get savingsRange => '\$$savingsLow–$savingsHigh';
}

/// Static catalog of vibes / push levels / deal sizes used across onboarding,
/// Express (tone chips), Pro (tone button), Profile and the warmup formula.
/// Onboarding remote options can override these via [WizCatalog.fromOnboardingOptions].
class WizCatalog {
  const WizCatalog({
    this.vibes = defaultVibes,
    this.pushLevels = defaultPushLevels,
    this.dealSizes = defaultDealSizes,
    this.dealsMultiplier = defaultDealsMultiplier,
  });

  final List<VibeDef> vibes;
  final List<PushDef> pushLevels;
  final List<DealSizeDef> dealSizes;
  /// deals_per_month value → multiplier for the monthly leak formula.
  final Map<String, int> dealsMultiplier;

  static const List<VibeDef> defaultVibes = [
    VibeDef(
      id: 'friendly',
      label: 'Friendly Collaborator',
      short: {'en': 'Friendly', 'es': 'Amable'},
      color: WizColors.teal,
      textOnColor: WizColors.tealInk,
      chipTextColor: WizColors.tealText,
      subtext: {'en': 'Polite, builds rapport, asks nicely.', 'es': 'Educado, crea confianza, pide con amabilidad.'},
      icon: IconData(0xf2b5, fontFamily: 'FontAwesomeRegular', fontPackage: 'font_awesome_flutter'), // handshake
    ),
    VibeDef(
      id: 'no_nonsense',
      label: 'No-Nonsense Buyer',
      short: {'en': 'No-Nonsense', 'es': 'Directo'},
      color: WizColors.orange,
      textOnColor: Colors.white,
      chipTextColor: WizColors.orange,
      subtext: {'en': 'Direct, brief, and values time over small talk.', 'es': 'Directo, breve y valora el tiempo más que la charla.'},
      icon: IconData(0xf0e7, fontFamily: 'FontAwesomeSolid', fontPackage: 'font_awesome_flutter'), // bolt
    ),
    VibeDef(
      id: 'tactical',
      label: 'Tactical Strategist',
      short: {'en': 'Tactical', 'es': 'Táctico'},
      color: WizColors.yellow,
      textOnColor: WizColors.ink,
      chipTextColor: WizColors.yellowText,
      subtext: {'en': 'Uses logic, data, and persistence to win.', 'es': 'Usa lógica, datos y persistencia para ganar.'},
      icon: IconData(0xf441, fontFamily: 'FontAwesomeRegular', fontPackage: 'font_awesome_flutter'), // chess knight
    ),
    VibeDef(
      id: 'quiet_closer',
      label: 'Quiet Closer',
      short: {'en': 'Quiet', 'es': 'Discreto'},
      color: WizColors.textTertiary,
      textOnColor: Colors.white,
      chipTextColor: WizColors.textTertiary,
      subtext: {'en': 'Subtle and non-confrontational but gets the deal.', 'es': 'Sutil y sin confrontación, pero cierra el trato.'},
      icon: IconData(0xf52d, fontFamily: 'FontAwesomeSolid', fontPackage: 'font_awesome_flutter'), // feather
    ),
  ];

  static const List<PushDef> defaultPushLevels = [
    PushDef(value: 20, label: {'en': 'Easygoing', 'es': 'Relajado'}, subtext: {'en': 'Small ask, happy to meet halfway', 'es': 'Pide poco, feliz de ceder a mitad'}, emoji: '🌊', color: Color(0xFFC026D3)),
    PushDef(value: 40, label: {'en': 'Gentle', 'es': 'Suave'}, subtext: {'en': 'Polite nudge, one counter', 'es': 'Empujón educado, una contraoferta'}, emoji: '🔮', color: Color(0xFF7E57C2)),
    PushDef(value: 60, label: {'en': 'Balanced', 'es': 'Equilibrado'}, subtext: {'en': 'Fair anchor, ready to walk', 'es': 'Ancla justa, listo para irse'}, emoji: '⚖️', color: Color(0xFF0EA5E9)),
    PushDef(value: 80, label: {'en': 'Bold', 'es': 'Audaz'}, subtext: {'en': 'Low anchor, holds firm', 'es': 'Ancla baja, se mantiene firme'}, emoji: '🔥', color: Color(0xFFF97316)),
    PushDef(value: 100, label: {'en': 'Hard bargainer', 'es': 'Negociador duro'}, subtext: {'en': 'Lowest price or no deal', 'es': 'El precio más bajo o no hay trato'}, emoji: '💥', color: Color(0xFFEF4444)),
  ];

  static const List<DealSizeDef> defaultDealSizes = [
    DealSizeDef(value: 50, label: '\$0–100', subtext: {'en': 'Small finds and everyday buys', 'es': 'Hallazgos pequeños y compras diarias'}, savingsLow: 8, savingsHigh: 20),
    DealSizeDef(value: 550, label: '\$100–1000', subtext: {'en': 'Furniture, phones, bikes', 'es': 'Muebles, teléfonos, bicis'}, savingsLow: 45, savingsHigh: 110),
    DealSizeDef(value: 5000, label: '\$1000+', subtext: {'en': 'Cars, high-end gear, big tickets', 'es': 'Coches, equipo de gama alta, grandes compras'}, savingsLow: 300, savingsHigh: 900),
  ];

  static const Map<String, int> defaultDealsMultiplier = {'0_2': 2, '3_5': 5, '6_plus': 8};

  static const String defaultVibeId = 'friendly';
  static const int defaultPushValue = 60;
  static const int defaultDealSizeValue = 550;

  VibeDef vibeById(String? id) =>
      vibes.where((v) => v.id == id).firstOrNull ?? vibes.first;

  /// Nearest push level for a stored risk_tolerance value (20..100).
  PushDef pushForValue(num? value) {
    if (value == null) return pushLevels.firstWhere((p) => p.value == defaultPushValue, orElse: () => pushLevels[pushLevels.length ~/ 2]);
    for (final p in pushLevels) {
      if (value <= p.value) return p;
    }
    return pushLevels.last;
  }

  int pushIndexForValue(num? value) => pushLevels.indexOf(pushForValue(value));

  DealSizeDef dealSizeForValue(num? value) {
    if (value == null) return dealSizes.firstWhere((d) => d.value == defaultDealSizeValue, orElse: () => dealSizes[dealSizes.length ~/ 2]);
    DealSizeDef? best;
    for (final d in dealSizes) {
      if (best == null || (d.value - value).abs() < (best.value - value).abs()) best = d;
    }
    return best!;
  }

  int multiplierFor(String? dealsPerMonth) => dealsMultiplier[dealsPerMonth] ?? 3;

  /// Monthly leak = savings_high(deal_size) × multiplier(deals_per_month).
  int monthlyLeak({num? dealSize, String? dealsPerMonth}) =>
      dealSizeForValue(dealSize).savingsHigh * multiplierFor(dealsPerMonth);

  /// Human label for a marketplace value ("facebook" → "Facebook Marketplace").
  static String marketplaceLabel(String? value, {String fallback = 'Any marketplace'}) {
    switch (value) {
      case 'ebay':
        return 'eBay';
      case 'amazon':
        return 'Amazon';
      case 'facebook':
        return 'Facebook Marketplace';
      case 'olx':
        return 'OLX';
      case 'craigslist':
        return 'Craigslist';
      case 'other':
        return 'Other';
      case null:
      case '':
        return fallback;
      default:
        return value;
    }
  }

  /// Chip icon for a marketplace option. A remote `icon` config (`{code, font}` map)
  /// wins; otherwise the built-in glyph for known values (Font Awesome brand marks where
  /// one exists). Null for unknown values. Keeps icons even if remote config omits them.
  static IconData? marketplaceIcon(String? value, {dynamic iconRaw}) {
    if (iconRaw != null && iconRaw.toString().isNotEmpty) {
      return IconResolver.resolve(iconRaw).icon;
    }
    switch (value) {
      case 'ebay':
        return FontAwesomeIcons.ebay.data;
      case 'amazon':
        return FontAwesomeIcons.amazon.data;
      case 'facebook':
        return FontAwesomeIcons.facebook.data;
      case 'olx':
        return FontAwesomeIcons.store.data;
      case 'craigslist':
        // Craigslist has no brand mark in Font Awesome; its logo is a peace sign.
        return FontAwesomeIcons.peace.data;
      case 'other':
        return Icons.auto_awesome;
      default:
        return null;
    }
  }

  /// Human label for deals_per_month ("3_5" → "3–5").
  static String dealsPerMonthLabel(String? value, {String fallback = '—'}) {
    switch (value) {
      case '0_2':
        return '0–2';
      case '3_5':
        return '3–5';
      case '6_plus':
        return '6+';
      case null:
      case '':
        return fallback;
      default:
        return value;
    }
  }

  /// Overrides vibes / push levels / deal sizes from onboarding option lists when present.
  /// [optionsByKey] maps answer key → raw option maps from remote config.
  WizCatalog withRemoteOptions(Map<String, List<Map<String, dynamic>>> optionsByKey) {
    final vibeOpts = optionsByKey['negotiation_vibe'];
    final pushOpts = optionsByKey['risk_tolerance'];
    final dealOpts = optionsByKey['average_deal_size'];
    return WizCatalog(
      vibes: vibeOpts == null || vibeOpts.isEmpty
          ? vibes
          : vibeOpts.map((o) {
              final id = o['value']?.toString() ?? '';
              final base = vibeById(id);
              final meta = (o['metadata'] as Map?) ?? const {};
              final color = _hex(meta['color']) ?? base.color;
              return VibeDef(
                id: id.isEmpty ? base.id : id,
                label: o['label'] ?? base.label,
                short: meta['short'] ?? base.short,
                color: color,
                textOnColor: color.computeLuminance() > 0.5 ? WizColors.ink : Colors.white,
                chipTextColor: base.id == id ? base.chipTextColor : color,
                subtext: meta['subtext'] ?? base.subtext,
                icon: o['icon'] != null ? IconResolver.resolve(o['icon']).icon : base.icon,
              );
            }).toList(),
      pushLevels: pushOpts == null || pushOpts.isEmpty
          ? pushLevels
          : pushOpts.map((o) {
              final v = (o['value'] as num?)?.toInt() ?? defaultPushValue;
              final base = pushForValue(v);
              return PushDef(
                value: v,
                label: o['label'] ?? base.label,
                subtext: o['subtext'] ?? base.subtext,
                emoji: o['emoji']?.toString() ?? base.emoji,
                color: _hex(o['color']) ?? base.color,
              );
            }).toList(),
      dealSizes: dealOpts == null || dealOpts.isEmpty
          ? dealSizes
          : dealOpts.map((o) {
              final v = (o['value'] as num?)?.toInt() ?? defaultDealSizeValue;
              final base = dealSizeForValue(v);
              return DealSizeDef(
                value: v,
                label: o['label'] ?? base.label,
                subtext: o['subtext'] ?? base.subtext,
                savingsLow: (o['savings_low'] as num?)?.toInt() ?? base.savingsLow,
                savingsHigh: (o['savings_high'] as num?)?.toInt() ?? base.savingsHigh,
              );
            }).toList(),
      dealsMultiplier: dealsMultiplier,
    );
  }

  static Color? _hex(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    var h = v.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final n = int.tryParse(h, radix: 16);
    return n == null ? null : Color(n);
  }
}
