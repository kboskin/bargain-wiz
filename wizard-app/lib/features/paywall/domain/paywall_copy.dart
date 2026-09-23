import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/domain/paywall_args.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/plural_text.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';

/// Resolves a remote-config text value (String / [MultilocaleText] / Map) to a plain string.
/// Widgets pass `(v) => TemplateText.textOf(context, v)`; pure code and tests can use
/// [PaywallText.plain], which falls back to English without a BuildContext.
typedef PaywallTextResolver = String Function(dynamic source);

/// Context-free text resolution (English first) for remote-config values.
class PaywallText {
  PaywallText._();

  static String plain(dynamic source) {
    if (source == null) return '';
    if (source is String) return source;
    if (source is MultilocaleText) return plain(source.toJson());
    if (source is Map) {
      final en = source['en'] ?? source['en-US'];
      if (en is String) return en;
      if (source.isNotEmpty) return source.values.first.toString();
      return '';
    }
    return source.toString();
  }
}

/// Price lookup: store product for the option → `price_label` from config → null (hidden).
class PaywallPricing {
  PaywallPricing._();

  /// The `subscription_config` product an option buys: the one whose key is the option id
  /// (billing periods of one tier), else the tier's product when the tier has exactly one.
  static SubscriptionProduct? productFor(
    PaywallOption option,
    List<SubscriptionProduct> products,
  ) {
    final byKey = products.where((p) => p.key == option.id).firstOrNull;
    if (byKey != null) return byKey;
    final byTier = products.where((p) => p.tier == option.tierEnum).toList();
    return byTier.length == 1 ? byTier.first : null;
  }

  /// Store product id for [option]; null until the products are loaded.
  static String? productIdFor(PaywallOption option, List<SubscriptionProduct> products) =>
      productFor(option, products)?.productId;

  /// Store price with the option's `price_suffix` ("$19.99" + "/mo"), else the static label.
  static String? priceFor(
    PaywallOption option,
    List<SubscriptionProduct> products, {
    PaywallTextResolver resolve = PaywallText.plain,
  }) {
    final store = productFor(option, products)?.price?.trim();
    if (store != null && store.isNotEmpty) return '$store${resolve(option.priceSuffix).trim()}';
    final label = resolve(option.priceLabel).trim();
    return label.isEmpty ? null : label;
  }
}

/// Context hint selection from `paywall_config.context_hints` by [PaywallEntry.hintKey].
class PaywallHints {
  PaywallHints._();

  static MultilocaleText? hintFor(Map<String, MultilocaleText> hints, PaywallEntry entry) {
    final key = entry.hintKey;
    if (key == null) return null;
    return hints[key];
  }
}

/// Dates for paywall copy; both fall back to English when the locale's data is not loaded.
class PaywallDates {
  PaywallDates._();

  /// "Sep 11" — enough for a renewal a few weeks out (the Profile plan card).
  static String monthDay(DateTime date, {String? locale}) {
    try {
      return DateFormat.MMMd(locale).format(date);
    } catch (_) {
      return DateFormat.MMMd('en_US').format(date);
    }
  }

  /// "Sep 11, 2026" — the timeline names the day money moves, so it spells the year out.
  static String monthDayYear(DateTime date, {String? locale}) {
    try {
      return DateFormat.yMMMd(locale).format(date);
    } catch (_) {
      return DateFormat.yMMMd('en_US').format(date);
    }
  }
}

/// A resolved trial-timeline row (placeholders filled, dot colour assigned).
class PaywallTimelineRow {
  const PaywallTimelineRow({
    required this.day,
    required this.title,
    required this.subtitle,
    required this.dotColor,
  });

  final int day;
  final String title;
  final String subtitle;
  final Color dotColor;

  @override
  String toString() => 'PaywallTimelineRow(day: $day, "$title" / "$subtitle")';
}

/// Builds timeline rows from `trial_timeline` (explicit rows) or from the selected option's
/// trial length plus the `timeline_*` wording. Placeholders: `{date}`, `{plan}`, `{price}`, `{day}`.
///
/// Every string comes from the template: the day numbers are computed, the words are not. A
/// row whose title and subtitle are both unconfigured is dropped, and an offer with no trial
/// (`trial_days` 0, no rows) has no timeline at all — the alternative, English defaults
/// compiled into the app, would describe an offer this build cannot know.
class PaywallTimelineBuilder {
  PaywallTimelineBuilder._();

  /// Dot colours per row: ink / purple / amber (cycled for extra rows).
  static const List<Color> dotColors = [WizColors.ink, WizColors.purple, WizColors.amber];

  static List<PaywallTimelineRow> build({
    required PaywallConfig config,
    required DateTime now,
    required String plan,
    required String? price,
    /// The selected option's trial length; defaults to the paywall-wide `trial_days`.
    int? trialDays,
    PaywallTextResolver resolve = PaywallText.plain,
    String Function(DateTime date)? formatDate,
    String? locale,
  }) {
    final days = trialDays ?? config.trialDays;
    if (config.trialTimeline.isEmpty && days <= 0) return const [];
    final fmt = formatDate ?? ((d) => PaywallDates.monthDayYear(d, locale: locale));
    final today = DateTime(now.year, now.month, now.day);

    final specs = (config.trialTimeline.isNotEmpty
            ? config.trialTimeline
                .map((r) => _RowSpec(r.day, resolve(r.title), resolve(r.subtitle)))
                .toList()
            : _derivedRows(config, days, resolve))
        .where((spec) => spec.title.trim().isNotEmpty || spec.subtitle.trim().isNotEmpty)
        .toList();

    final out = <PaywallTimelineRow>[];
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final values = <String, String?>{
        'date': fmt(today.add(Duration(days: spec.day))),
        'plan': plan,
        'price': price ?? '',
        'day': '${spec.day}',
      };
      out.add(PaywallTimelineRow(
        day: spec.day,
        title: _tidy(TemplateText.fill(spec.title, values)),
        subtitle: _tidy(TemplateText.fill(spec.subtitle, values)),
        dotColor: dotColors[i % dotColors.length],
      ));
    }
    return out;
  }

  /// Today, the reminder the day before the end, and the billing day — all three derived
  /// from `trial_days`, worded by the `timeline_*` fields.
  static List<_RowSpec> _derivedRows(
    PaywallConfig config,
    int trialDays,
    PaywallTextResolver resolve,
  ) {
    final days = trialDays.clamp(1, 365);
    final reminderDay = (days - 1).clamp(1, 365);
    // The title is resolved for the day it names, so "In 1 Day" and "In 2 Days" both read.
    String title(PluralText? source, int day) =>
        source == null ? '' : resolve(source.sourceFor(day));

    return [
      _RowSpec(
        0,
        title(config.timelineTodayText, 0),
        resolve(config.timelineTodaySubtitle),
      ),
      _RowSpec(
        reminderDay,
        title(config.timelineReminderText, reminderDay),
        resolve(config.timelineReminderSubtitle),
      ),
      _RowSpec(
        days,
        title(config.timelineBillingText, days),
        resolve(config.timelineBillingSubtitle),
      ),
    ];
  }

  /// Collapses double spaces left by an empty `{price}`.
  static String _tidy(String s) => s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

class _RowSpec {
  const _RowSpec(this.day, this.title, this.subtitle);
  final int day;
  final String title;
  final String subtitle;
}
