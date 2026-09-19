import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/highlight_words_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

part 'paywall_config.g.dart';

/// Paywall configuration from Remote Config
/// This is the full paywall definition that lives in a separate RC key
@JsonSerializable()
class PaywallConfig {
  final String type; // e.g., "onboarding_default"
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  final List<PaywallOption> options; // Two subscription options
  final PaywallMetadata metadata; // Visual config, default selection, etc.
  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  final dynamic nextButtonText;
  @JsonKey(name: 'note_text', fromJson: _multilocaleFromJson)
  final dynamic noteText;
  @JsonKey(name: 'show_restore')
  final bool showRestore;
  @JsonKey(name: 'show_close')
  final bool showClose;
  /// Seconds after which the close (X) button appears. 0 = immediately. Remotely configurable; default 5.
  @JsonKey(name: 'close_button_delay_seconds')
  final double closeButtonDelaySeconds;
  /// Payment provider to use for this paywall: "iap" or "stripe".
  @JsonKey(name: 'payment_provider')
  final String? paymentProvider;
  /// Trial length in days (e.g. 3). Used for timeline and billing date copy.
  @JsonKey(name: 'trial_days')
  final int trialDays;
  /// Optional multi-step flow configuration. When non-empty, steps are shown
  /// before the main pricing screen, similar to a 2–3 screen trial explainer.
  @JsonKey(name: 'steps')
  final List<PaywallStepConfig> steps;
  /// Optional background (`{"colors": ["#FFFFFF"], "stops": [1.0]}`). A single colour is used as a
  /// solid fill, two or more as a gradient; the redesign ships white.
  @JsonKey(name: 'background')
  final PaywallBackgroundConfig? background;
  /// Optional highlight words for various texts
  @JsonKey(name: 'title_highlight_words')
  final HighlightWordsConfig? titleHighlightWords;
  @JsonKey(name: 'description_highlight_words')
  final HighlightWordsConfig? descriptionHighlightWords;
  @JsonKey(name: 'no_payment_highlight_words')
  final HighlightWordsConfig? noPaymentHighlightWords;
  /// Optional override for the "No payment due now" text.
  @JsonKey(name: 'no_payment_due_text', fromJson: _multilocaleFromJson)
  final dynamic noPaymentDueText;
  /// Optional override for timeline "Today" label.
  @JsonKey(name: 'timeline_today_text', fromJson: _multilocaleFromJson)
  final dynamic timelineTodayText;
  /// Optional override for timeline "Reminder" label.
  @JsonKey(name: 'timeline_reminder_text', fromJson: _multilocaleFromJson)
  final dynamic timelineReminderText;
  /// Optional override for timeline "Billing starts" label.
  @JsonKey(name: 'timeline_billing_text', fromJson: _multilocaleFromJson)
  final dynamic timelineBillingText;
  @JsonKey(name: 'timeline_today_subtitle', fromJson: _multilocaleFromJson)
  final dynamic timelineTodaySubtitle;
  @JsonKey(name: 'timeline_reminder_subtitle', fromJson: _multilocaleFromJson)
  final dynamic timelineReminderSubtitle;
  @JsonKey(name: 'timeline_billing_subtitle', fromJson: _multilocaleFromJson)
  final dynamic timelineBillingSubtitle;

  // ── Redesign (design_handoff_bargain_wiz) ──

  /// Context hints shown above the plans when the paywall is opened from a locked feature.
  /// Keys: "free", "basic_express". Values: multilocale text.
  @JsonKey(name: 'context_hints', fromJson: _hintsFromJson)
  final Map<String, MultilocaleText> contextHints;

  /// Remote-configurable trial timeline rows. Placeholders: {date}, {plan}, {price}.
  @JsonKey(name: 'trial_timeline')
  final List<PaywallTimelineRowConfig> trialTimeline;

  /// Documented entry points (informational; gating lives in FeatureGatePolicy).
  @JsonKey(name: 'entry_points')
  final List<String> entryPoints;

  PaywallConfig({
    required this.type,
    required this.title,
    required this.description,
    required this.options,
    required this.metadata,
    required this.nextButtonText,
    required this.noteText,
    this.showRestore = true,
    this.showClose = false,
    this.closeButtonDelaySeconds = 5.0,
    this.paymentProvider,
    this.trialDays = 3,
    this.steps = const [],
    this.background,
    this.noPaymentDueText,
    this.timelineTodayText,
    this.timelineReminderText,
    this.timelineBillingText,
    this.timelineTodaySubtitle,
    this.timelineReminderSubtitle,
    this.timelineBillingSubtitle,
    this.titleHighlightWords,
    this.descriptionHighlightWords,
    this.noPaymentHighlightWords,
    this.contextHints = const {},
    this.trialTimeline = const [],
    this.entryPoints = const [],
  });

  factory PaywallConfig.fromJson(Map<String, dynamic> json) => _$PaywallConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  static Map<String, MultilocaleText> _hintsFromJson(dynamic json) {
    if (json is! Map) return const {};
    return json.map((k, v) => MapEntry(k.toString(), MultilocaleText.fromJson(v)));
  }

  Map<String, dynamic> toJson() => _$PaywallConfigToJson(this);
}

/// Paywall background: hex colours + stops (+ optional CSS-style angle). Mirrors the onboarding
/// gradient config but stays dependency-free so the paywall model can be unit-tested.
class PaywallBackgroundConfig {
  const PaywallBackgroundConfig({required this.colors, this.stops = const [], this.angleDeg});

  final List<String> colors;
  final List<double> stops;
  final double? angleDeg;

  factory PaywallBackgroundConfig.fromJson(Map<String, dynamic> json) => PaywallBackgroundConfig(
        colors: (json['colors'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        stops: (json['stops'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        angleDeg: (json['angle_deg'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'colors': colors,
        'stops': stops,
        if (angleDeg != null) 'angle_deg': angleDeg,
      };

  /// Parsed colours (`#RRGGBB` / `#AARRGGBB`); invalid entries are skipped.
  List<Color> get colorObjects => colors.map(parseHex).whereType<Color>().toList();

  LinearGradient toLinearGradient() {
    final parsed = colorObjects;
    return WizColors.angledGradient(
      parsed,
      stops.length == parsed.length ? stops : null,
      angleDeg ?? 135,
    );
  }

  static Color? parseHex(String value) {
    var h = value.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final n = int.tryParse(h, radix: 16);
    return n == null ? null : Color(n);
  }
}

/// One row of the trial timeline (Today / Day 2 / Day 3).
@JsonSerializable()
class PaywallTimelineRowConfig {
  PaywallTimelineRowConfig({required this.day, this.title, this.subtitle});

  /// Offset in days from today (0 = today).
  final int day;

  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic subtitle;

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  factory PaywallTimelineRowConfig.fromJson(Map<String, dynamic> json) =>
      _$PaywallTimelineRowConfigFromJson(json);

  Map<String, dynamic> toJson() => _$PaywallTimelineRowConfigToJson(this);
}

/// Optional configuration for an additional paywall step shown *before* the
/// main pricing/options screen. Inspired by multi-step trial flows:
/// e.g. "We want you to try X for free", "We'll remind you before trial ends".
@JsonSerializable()
class PaywallStepConfig {
  /// Step whose CTA asks for the notification permission when no `button_action` is set.
  static const String reminderStepId = 'reminder';

  /// Optional identifier (e.g. "intro", "reminder", "timeline").
  final String? id;

  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;

  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;

  /// Optional visual (Lottie or image asset path).
  final String? visual;

  /// Small line of text under the primary CTA (e.g. "No payment due now").
  @JsonKey(name: 'note_text', fromJson: _multilocaleFromJson)
  final dynamic noteText;

  /// Primary CTA label for this step (e.g. "Try for $0.00", "Continue for FREE").
  @JsonKey(name: 'button_text', fromJson: _multilocaleFromJson)
  final dynamic buttonText;

  @JsonKey(name: 'title_highlight_words')
  final HighlightWordsConfig? titleHighlightWords;

  @JsonKey(name: 'highlight_color')
  final String? highlightColor;

  /// What the CTA does on top of advancing to the next step. Only `request_permission`
  /// (the notification opt-in) changes anything today; see [ButtonAction].
  @JsonKey(name: 'button_action')
  final String? buttonAction;

  PaywallStepConfig({
    this.id,
    this.title,
    this.description,
    this.visual,
    this.noteText,
    this.buttonText,
    this.titleHighlightWords,
    this.highlightColor,
    this.buttonAction,
  });

  /// Whether tapping this step's CTA should show the notification prompt. Driven by
  /// `button_action: request_permission`; falls back to the [reminderStepId] id so configs
  /// written before `button_action` existed keep working.
  bool get asksNotificationPermission => buttonAction == null
      ? id == reminderStepId
      : ButtonAction.fromString(buttonAction!) == ButtonAction.requestPermission;

  factory PaywallStepConfig.fromJson(Map<String, dynamic> json) =>
      _$PaywallStepConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$PaywallStepConfigToJson(this);
}

/// Paywall option (subscription tier)
@JsonSerializable()
class PaywallOption {
  final String id; // e.g., "text", "vision"
  final String tier; // "basic" or "premium"
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic badge;

  /// Feature bullets (multilocale). Shown in list / compact layouts and the feature summary.
  @JsonKey(fromJson: _featuresFromJson)
  final List<MultilocaleText> features;

  /// Optional static price label override (store price is preferred when available).
  @JsonKey(name: 'price_label', fromJson: _multilocaleFromJson)
  final dynamic priceLabel;

  PaywallOption({
    required this.id,
    required this.tier,
    required this.title,
    required this.description,
    this.badge,
    this.features = const [],
    this.priceLabel,
  });

  static List<MultilocaleText> _featuresFromJson(dynamic json) {
    if (json is! List) return const [];
    return json.map((e) => MultilocaleText.fromJson(e)).toList();
  }

  factory PaywallOption.fromJson(Map<String, dynamic> json) => _$PaywallOptionFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$PaywallOptionToJson(this);

  /// Get subscription tier enum
  SubscriptionTier get tierEnum {
    switch (tier.toLowerCase()) {
      case 'basic':
        return SubscriptionTier.basic;
      case 'premium':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }
}

/// Paywall metadata (visual config, default selection, etc.)
@JsonSerializable()
class PaywallMetadata {
  @JsonKey(name: 'default_selected_option_id')
  final String defaultSelectedOptionId;
  @JsonKey(fromJson: _layoutFromJson, toJson: _layoutToJson)
  final PaywallLayout layout;
  @JsonKey(name: 'card_style')
  final String? cardStyle; // e.g., "glow"
  @JsonKey(name: 'visual_width')
  final double? visualWidth;
  @JsonKey(name: 'visual_height')
  final double? visualHeight;
  @JsonKey(name: 'visual_opacity')
  final double? visualOpacity;
  /// When true (default), Lottie animations loop. Set to false in remote config for one-shot animations.
  @JsonKey(name: 'animation_looped')
  final bool? animationLooped;
  @JsonKey(name: 'option_visuals')
  final Map<String, String> optionVisuals; // Map of option_id -> lottie path
  @JsonKey(name: 'highlight_color')
  final String? highlightColor;

  PaywallMetadata({
    required this.defaultSelectedOptionId,
    required this.layout,
    this.cardStyle,
    this.visualWidth,
    this.visualHeight,
    this.visualOpacity,
    this.animationLooped,
    required this.optionVisuals,
    this.highlightColor,
  });

  /// Whether the option visuals should loop. Defaults to true when not set in remote config.
  bool get isAnimationLooped => animationLooped ?? true;

  factory PaywallMetadata.fromJson(Map<String, dynamic> json) => _$PaywallMetadataFromJson(json);

  static PaywallLayout _layoutFromJson(String? value) =>
      PaywallLayout.fromString(value);

  static String? _layoutToJson(PaywallLayout layout) => layout.name;

  Map<String, dynamic> toJson() => _$PaywallMetadataToJson(this);
}
