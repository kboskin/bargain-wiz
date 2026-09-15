import 'dart:convert';

import 'package:appwizard/core/config/wiz_catalog.dart';

/// A selectable value for the Profile settings sheets (marketplace / deals per month).
class ProfileOption {
  const ProfileOption(this.value, this.label, {this.iconRaw});

  final String value;
  /// String or multilocale map; resolve with `TemplateText.textOf`.
  final dynamic label;
  /// Raw remote `icon` config (`{code, font}` map) when the option defines one.
  final dynamic iconRaw;
}

/// Option lists for the Profile settings rows. Read from the raw `onboarding_screens`
/// remote value (`options` on a select screen or `groups[].options` on a select_group
/// screen), falling back to the built-in marketplaces / deal buckets.
class ProfileOptions {
  ProfileOptions._();

  /// Onboarding answer keys (see `UserProfileService.keyMarketplace` / `keyDealsPerMonth`).
  static const String marketplaceKey = 'favorite_marketplace';
  static const String dealsPerMonthKey = 'deals_per_month';

  static const List<ProfileOption> marketplaceFallback = [
    ProfileOption('facebook', 'Facebook Marketplace'),
    ProfileOption('ebay', 'eBay'),
    ProfileOption('amazon', 'Amazon'),
    ProfileOption('olx', 'OLX'),
    ProfileOption('craigslist', 'Craigslist'),
    ProfileOption('other', {'en': 'Other', 'es': 'Otro'}),
  ];

  static const List<ProfileOption> dealsPerMonthFallback = [
    ProfileOption('0_2', '0–2'),
    ProfileOption('3_5', '3–5'),
    ProfileOption('6_plus', '6+'),
  ];

  /// [rawOnboardingScreens] is the JSON string of the `onboarding_screens` remote key.
  static List<ProfileOption> marketplaces(String rawOnboardingScreens) =>
      _fromRaw(rawOnboardingScreens, marketplaceKey) ?? marketplaceFallback;

  static List<ProfileOption> dealsPerMonth(String rawOnboardingScreens) =>
      _fromRaw(rawOnboardingScreens, dealsPerMonthKey) ?? dealsPerMonthFallback;

  /// Human label for a stored value: option list first, raw value otherwise.
  static String labelFor(
    List<ProfileOption> options,
    String? value,
    String Function(dynamic) resolve, {
    required String fallback,
  }) {
    if (value == null || value.isEmpty) return fallback;
    final match = options.where((o) => o.value == value).firstOrNull;
    if (match != null) {
      final s = resolve(match.label);
      if (s.isNotEmpty) return s;
    }
    return value;
  }

  static List<ProfileOption>? _fromRaw(String raw, String answerKey) {
    if (raw.isEmpty) return null;
    try {
      return parse(jsonDecode(raw), answerKey);
    } catch (_) {
      return null;
    }
  }

  /// Extracts options for [answerKey] from a decoded `onboarding_screens` list.
  /// Returns null when the key is not present.
  static List<ProfileOption>? parse(dynamic screens, String answerKey) {
    if (screens is! List) return null;
    for (final screen in screens.whereType<Map>()) {
      final key = (screen['answer_structure'] as Map?)?['answer_key_name']?.toString();
      if (key == answerKey) {
        final opts = _options(screen['options'] ?? (screen['metadata'] as Map?)?['options']);
        if (opts != null) return opts;
      }
      final groups = screen['groups'];
      if (groups is List) {
        for (final g in groups.whereType<Map>()) {
          if (g['answer_key_name']?.toString() == answerKey) {
            final opts = _options(g['options']);
            if (opts != null) return opts;
          }
        }
      }
    }
    return null;
  }

  static List<ProfileOption>? _options(dynamic raw) {
    if (raw is! List) return null;
    final out = <ProfileOption>[];
    for (final o in raw.whereType<Map>()) {
      final value = o['value']?.toString();
      if (value == null || value.isEmpty) continue;
      out.add(ProfileOption(value, o['label'] ?? WizCatalog.marketplaceLabel(value), iconRaw: o['icon']));
    }
    return out.isEmpty ? null : out;
  }
}
