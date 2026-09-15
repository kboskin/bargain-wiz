import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/domain/paywall_args.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
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

/// Price lookup: store product (matching tier) → `price_label` from config → null (hidden).
class PaywallPricing {
  PaywallPricing._();

  static SubscriptionProduct? productFor(
    PaywallOption option,
    List<SubscriptionProduct> products,
  ) {
    final tier = option.tierEnum;
    for (final p in products) {
      if (p.tier == tier) return p;
    }
    return null;
  }

  /// Store product id for [option], else the tier's fallback constant.
  static String? productIdFor(PaywallOption option, List<SubscriptionProduct> products) =>
      productFor(option, products)?.productId ?? option.tierEnum.getProductId();

  static String? priceFor(
    PaywallOption option,
    List<SubscriptionProduct> products, {
    PaywallTextResolver resolve = PaywallText.plain,
  }) {
    final store = productFor(option, products)?.price;
    if (store != null && store.trim().isNotEmpty) return store.trim();
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

/// "Sep 11"-style dates; falls back to English when the locale's data is not loaded.
class PaywallDates {
  PaywallDates._();

  static String monthDay(DateTime date, {String? locale}) {
    try {
      return DateFormat.MMMd(locale).format(date);
    } catch (_) {
      return DateFormat.MMMd('en_US').format(date);
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

/// Builds timeline rows from `trial_timeline` (preferred), the legacy `timeline_*`
/// fields, or three hardcoded rows. Placeholders: `{date}`, `{plan}`, `{price}`, `{day}`.
class PaywallTimelineBuilder {
  PaywallTimelineBuilder._();

  /// Dot colours per row: ink / purple / amber (cycled for extra rows).
  static const List<Color> dotColors = [WizColors.ink, WizColors.purple, WizColors.amber];

  static const String _defaultTodayTitle = 'Today · {date}';
  static const String _defaultTodaySubtitle = 'Unlock every feature of {plan}';
  static const String _defaultReminderTitle = 'Day {day} · {date}';
  static const String _defaultReminderSubtitle = 'We remind you before the trial ends';
  static const String _defaultBillingTitle = 'Day {day} · {date}';
  static const String _defaultBillingSubtitle = 'Billing starts at {price} unless cancelled';

  static List<PaywallTimelineRow> build({
    required PaywallConfig config,
    required DateTime now,
    required String plan,
    required String? price,
    PaywallTextResolver resolve = PaywallText.plain,
    String Function(DateTime date)? formatDate,
    String? locale,
  }) {
    final fmt = formatDate ?? ((d) => PaywallDates.monthDay(d, locale: locale));
    final today = DateTime(now.year, now.month, now.day);

    final specs = config.trialTimeline.isNotEmpty
        ? config.trialTimeline
            .map((r) => _RowSpec(r.day, resolve(r.title), resolve(r.subtitle)))
            .toList()
        : _legacyRows(config, resolve);

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

  static List<_RowSpec> _legacyRows(PaywallConfig config, PaywallTextResolver resolve) {
    final days = config.trialDays.clamp(1, 365);
    final reminderDay = (days - 1).clamp(1, 365);
    String pick(dynamic remote, String fallback) {
      final s = resolve(remote).trim();
      return s.isEmpty ? fallback : s;
    }
    return [
      _RowSpec(
        0,
        pick(config.timelineTodayText, _defaultTodayTitle),
        pick(config.timelineTodaySubtitle, _defaultTodaySubtitle),
      ),
      _RowSpec(
        reminderDay,
        pick(config.timelineReminderText, _defaultReminderTitle),
        pick(config.timelineReminderSubtitle, _defaultReminderSubtitle),
      ),
      _RowSpec(
        days,
        pick(config.timelineBillingText, _defaultBillingTitle),
        pick(config.timelineBillingSubtitle, _defaultBillingSubtitle),
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
