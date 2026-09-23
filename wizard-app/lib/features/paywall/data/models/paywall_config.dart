import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/highlight_words_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/plural_text.dart';

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
  final List<PaywallOption> options; // Billing periods of the plan, each with its own offer
  final PaywallMetadata metadata; // Visual config, default selection, etc.
  @JsonKey(name: 'next_button_text', fromJson: _multilocaleFromJson)
  final dynamic nextButtonText;
  @JsonKey(name: 'note_text', fromJson: _multilocaleFromJson)
  final dynamic noteText;
  @JsonKey(name: 'show_restore')
  final bool showRestore;
  @JsonKey(name: 'show_close')
  final bool showClose;

  /// The amber hint above the plans, shown when the paywall was opened from a locked
  /// feature. Its wording stays in `context_hints` while this is false.
  @JsonKey(name: 'show_context_hint')
  final bool showContextHint;

  /// The line between the plans and the CTA (`note_text`). Its wording stays configured
  /// while this is false — but it is where the trial-to-billing terms are spelled out, so
  /// leave the trial timeline on when it is hidden.
  @JsonKey(name: 'show_note')
  final bool showNote;
  /// Seconds after which the close (X) button appears. 0 = immediately. Remotely configurable; default 5.
  @JsonKey(name: 'close_button_delay_seconds')
  final double closeButtonDelaySeconds;
  /// Payment provider to use for this paywall: "iap" or "stripe".
  @JsonKey(name: 'payment_provider')
  final String? paymentProvider;
  /// Default trial length in days for options that do not set their own `trial_days`;
  /// 0 = no trial, which also hides the timeline unless `trial_timeline` rows are configured.
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
  /// Timeline row titles. Plural texts, because they count days ("In {day} Days"): a plain
  /// string or multilocale map still works and simply has no singular form.
  @JsonKey(name: 'timeline_today_text', fromJson: PluralText.fromJson, toJson: _pluralToJson)
  final PluralText? timelineTodayText;
  @JsonKey(name: 'timeline_reminder_text', fromJson: PluralText.fromJson, toJson: _pluralToJson)
  final PluralText? timelineReminderText;
  @JsonKey(name: 'timeline_billing_text', fromJson: PluralText.fromJson, toJson: _pluralToJson)
  final PluralText? timelineBillingText;
  @JsonKey(name: 'timeline_today_subtitle', fromJson: _multilocaleFromJson)
  final dynamic timelineTodaySubtitle;
  @JsonKey(name: 'timeline_reminder_subtitle', fromJson: _multilocaleFromJson)
  final dynamic timelineReminderSubtitle;
  @JsonKey(name: 'timeline_billing_subtitle', fromJson: _multilocaleFromJson)
  final dynamic timelineBillingSubtitle;

  // ── Redesign (design_handoff_bargain_wiz) ──

  /// Context hints shown above the plans when the paywall is opened from a locked feature.
  /// Keys: "free". Values: multilocale text.
  @JsonKey(name: 'context_hints', fromJson: _hintsFromJson)
  final Map<String, MultilocaleText> contextHints;

  /// Remote-configurable trial timeline rows. Placeholders: {date}, {plan}, {price}.
  @JsonKey(name: 'trial_timeline')
  final List<PaywallTimelineRowConfig> trialTimeline;

  /// Documented entry points (informational; gating lives in FeatureGatePolicy).
  @JsonKey(name: 'entry_points')
  final List<String> entryPoints;

  /// Wording of the Profile plan card and the drawer's plan name. Lives here because it
  /// describes the same offer as the plans step, so one edit changes both.
  @JsonKey(name: 'plan_card')
  final PaywallPlanCardConfig? planCard;

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
    this.showContextHint = true,
    this.showNote = true,
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
    this.planCard,
  });

  factory PaywallConfig.fromJson(Map<String, dynamic> json) => _$PaywallConfigFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  static dynamic _pluralToJson(PluralText? value) => value?.toJson();

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

/// Wording of the "current plan" card (Profile) and the plan name in the drawer footer.
///
/// Every string is remote-configured: the app decides *which* line applies (free, inside the
/// trial, renewing, active) and this decides *what it says*. Placeholders: `{price}`, `{date}`,
/// and `{n}` for the days left in the trial. A string left out renders as nothing rather than
/// as English, so an offer this build has never heard of cannot be described wrongly.
class PaywallPlanCardConfig {
  const PaywallPlanCardConfig({
    this.label,
    this.freeName,
    this.paidName,
    this.freeSubtitle,
    this.trialSubtitle,
    this.trialEndsTodaySubtitle,
    this.renewsSubtitle,
    this.activeSubtitle,
    this.upgradeCta,
    this.manageCta,
  });

  /// Small caps line above the plan name ("CURRENT PLAN").
  final dynamic label;
  final dynamic freeName;
  final dynamic paidName;
  final dynamic freeSubtitle;

  /// Inside the trial, with `{n}` days left: `{"one": …, "other": …}` or a plain text.
  final PluralText? trialSubtitle;

  /// The last day of the trial, when `{n}` would be 0.
  final dynamic trialEndsTodaySubtitle;

  /// Paid and the store reported a renewal date.
  final dynamic renewsSubtitle;

  /// Paid with no renewal date (a restore that reports only the entitlement, or a QA override).
  final dynamic activeSubtitle;

  final dynamic upgradeCta;
  final dynamic manageCta;

  factory PaywallPlanCardConfig.fromJson(Map<String, dynamic> json) => PaywallPlanCardConfig(
        label: _text(json['label']),
        freeName: _text(json['free_name']),
        paidName: _text(json['paid_name']),
        freeSubtitle: _text(json['free_subtitle']),
        trialSubtitle: PluralText.fromJson(json['trial_subtitle']),
        trialEndsTodaySubtitle: _text(json['trial_ends_today_subtitle']),
        renewsSubtitle: _text(json['renews_subtitle']),
        activeSubtitle: _text(json['active_subtitle']),
        upgradeCta: _text(json['upgrade_cta']),
        manageCta: _text(json['manage_cta']),
      );

  Map<String, dynamic> toJson() => {
        if (label != null) 'label': _json(label),
        if (freeName != null) 'free_name': _json(freeName),
        if (paidName != null) 'paid_name': _json(paidName),
        if (freeSubtitle != null) 'free_subtitle': _json(freeSubtitle),
        if (trialSubtitle != null) 'trial_subtitle': trialSubtitle!.toJson(),
        if (trialEndsTodaySubtitle != null) 'trial_ends_today_subtitle': _json(trialEndsTodaySubtitle),
        if (renewsSubtitle != null) 'renews_subtitle': _json(renewsSubtitle),
        if (activeSubtitle != null) 'active_subtitle': _json(activeSubtitle),
        if (upgradeCta != null) 'upgrade_cta': _json(upgradeCta),
        if (manageCta != null) 'manage_cta': _json(manageCta),
      };

  static dynamic _text(dynamic json) => json == null ? null : MultilocaleText.fromJson(json);

  static dynamic _json(dynamic value) =>
      value is MultilocaleText ? value.toJson() : value;
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

  /// How big to draw [visual], defaulting to [PaywallStepConfig.defaultVisualSize]. The step
  /// scrolls, so a large one costs nothing but the room it takes above the copy.
  @JsonKey(name: 'visual_size')
  final double? visualSize;

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

  static const double defaultVisualSize = 180;

  double get artSize => visualSize ?? defaultVisualSize;

  PaywallStepConfig({
    this.id,
    this.title,
    this.description,
    this.visual,
    this.visualSize,
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

/// Paywall option: one billing period of the plan. `id` names the `subscription_config`
/// product it buys ("monthly", "weekly"); `tier` is what that purchase unlocks.
@JsonSerializable()
class PaywallOption {
  final String id; // e.g., "monthly", "weekly"
  final String tier; // "premium"
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;
  /// A single badge. Superseded by [badges]; kept so a config written before the row
  /// existed still shows its one pill.
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic badge;

  /// The badge row, in the order it reads ("Save 25%", "Most popular", …). The trial pill is
  /// not in here: [trialBadge] is prepended when the period actually has a trial, so a claim
  /// about the trial cannot be left behind when the offer changes.
  @JsonKey(fromJson: _featuresFromJson)
  final List<MultilocaleText> badges;

  /// Feature bullets (multilocale). Shown in list / compact layouts and the feature summary.
  @JsonKey(fromJson: _featuresFromJson)
  final List<MultilocaleText> features;

  /// Colour of this plan's art block, `#RRGGBB`. Without it the block is tinted by whether
  /// the plan is the preselected one, which is a fact about the layout rather than about the
  /// plan — set it to say something about the offer instead.
  @JsonKey(name: 'art_color')
  final String? artColor;

  /// Phrases to emphasise inside [description]: `{"You save 34%": "bold"}`, or a hex colour
  /// instead of `bold`. Matching is case-insensitive, so the English and Spanish phrases can
  /// both sit in one map. The phrase must appear in the description or nothing happens.
  @JsonKey(name: 'description_highlight_words')
  final Map<String, dynamic>? descriptionHighlightWords;

  /// Optional static price label override (store price is preferred when available).
  @JsonKey(name: 'price_label', fromJson: _multilocaleFromJson)
  final dynamic priceLabel;

  /// Billing-period suffix appended to the store price ("/mo", "/wk"), so the period is
  /// always visible next to the amount as the stores require.
  @JsonKey(name: 'price_suffix', fromJson: _multilocaleFromJson)
  final dynamic priceSuffix;

  /// Free-trial length for *this* billing period, which is how the stores model it: a trial is
  /// an introductory offer on one product, not on the plan. Null falls back to the paywall's
  /// `trial_days`; 0 means this period has no trial. See [trialDaysOr].
  @JsonKey(name: 'trial_days')
  final int? trialDays;

  /// Pill at the top of the card's art block naming the trial ("{n} days free"). Rendered
  /// only when this option actually has a trial, so it cannot outlive the offer it describes.
  @JsonKey(name: 'trial_badge', fromJson: PluralText.fromJson, toJson: _pluralToJson)
  final PluralText? trialBadge;

  /// Overrides for the plans step when this option is selected, because a period with a trial
  /// and one without cannot share a sentence.
  @JsonKey(name: 'note_text', fromJson: _multilocaleFromJson)
  final dynamic noteText;
  @JsonKey(name: 'button_text', fromJson: _multilocaleFromJson)
  final dynamic buttonText;

  PaywallOption({
    required this.id,
    required this.tier,
    required this.title,
    required this.description,
    this.badge,
    this.badges = const [],
    this.descriptionHighlightWords,
    this.artColor,
    this.features = const [],
    this.priceLabel,
    this.priceSuffix,
    this.trialDays,
    this.trialBadge,
    this.noteText,
    this.buttonText,
  });

  /// This period's trial length, falling back to the paywall-wide `trial_days`.
  int trialDaysOr(int fallback) => trialDays ?? fallback;

  static List<MultilocaleText> _featuresFromJson(dynamic json) {
    if (json is! List) return const [];
    return json.map((e) => MultilocaleText.fromJson(e)).toList();
  }

  factory PaywallOption.fromJson(Map<String, dynamic> json) => _$PaywallOptionFromJson(json);

  static dynamic _multilocaleFromJson(dynamic json) => 
      json != null ? MultilocaleText.fromJson(json) : null;

  static dynamic _pluralToJson(PluralText? value) => value?.toJson();

  Map<String, dynamic> toJson() => _$PaywallOptionToJson(this);

  /// Get subscription tier enum
  SubscriptionTier get tierEnum => SubscriptionTier.fromName(tier.toLowerCase());
}

/// Paywall metadata (visual config, default selection, etc.)
@JsonSerializable()
class PaywallMetadata {
  @JsonKey(name: 'default_selected_option_id')
  final String defaultSelectedOptionId;
  @JsonKey(fromJson: _layoutFromJson, toJson: _layoutToJson)
  final PaywallLayout layout;
  /// How the selected card is emphasised: `glow` (default), `shadow` or `flat`.
  @JsonKey(name: 'card_style', fromJson: _cardStyleFromJson, toJson: _cardStyleToJson)
  final PaywallCardStyle cardStyle;
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

  /// Plan-card type sizes. Null keeps the handoff's values (title 17, description 12.5,
  /// price 15); the price is the one worth tuning, since a big number next to a small
  /// description reads as the point of the card.
  @JsonKey(name: 'title_font_size')
  final double? titleFontSize;
  @JsonKey(name: 'description_font_size')
  final double? descriptionFontSize;
  @JsonKey(name: 'price_font_size')
  final double? priceFontSize;

  /// Price weight, 100-900. The display font (Outfit) ships 500/600/700, so anything
  /// lighter than 500 needs `price_font_family: "body"` — Figtree ships 400.
  @JsonKey(name: 'price_font_weight')
  final int? priceFontWeight;

  /// `body` (Figtree, down to 400) or `display` (Outfit, 500 and up). Defaults to body,
  /// because a price is a detail on this card and the display font cannot go light.
  @JsonKey(name: 'price_font_family')
  final String? priceFontFamily;

  /// Amber halo behind the selected card's price ([WizShadows.textGlow]), which is what
  /// carries the price once it is no longer the boldest thing on the card.
  @JsonKey(name: 'price_glow')
  final bool? priceGlow;

  /// Height of the tinted block the art sits in, shared by every card so they stay level.
  @JsonKey(name: 'art_block_height')
  final double? artBlockHeightConfig;

  PaywallMetadata({
    required this.defaultSelectedOptionId,
    required this.layout,
    this.cardStyle = PaywallCardStyle.glow,
    this.visualWidth,
    this.visualHeight,
    this.visualOpacity,
    this.animationLooped,
    required this.optionVisuals,
    this.highlightColor,
    this.titleFontSize,
    this.descriptionFontSize,
    this.priceFontSize,
    this.priceFontWeight,
    this.priceFontFamily,
    this.priceGlow,
    this.artBlockHeightConfig,
  });

  static const double defaultTitleFontSize = 17;
  static const double defaultDescriptionFontSize = 12.5;
  static const double defaultPriceFontSize = 15;

  static const FontWeight defaultPriceWeight = FontWeight.w400;

  double get titleSize => titleFontSize ?? defaultTitleFontSize;
  double get descriptionSize => descriptionFontSize ?? defaultDescriptionFontSize;
  double get priceSize => priceFontSize ?? defaultPriceFontSize;

  /// Nearest real [FontWeight] to the configured value.
  FontWeight get priceWeight {
    final value = priceFontWeight;
    if (value == null) return defaultPriceWeight;
    final index = ((value ~/ 100) - 1).clamp(0, FontWeight.values.length - 1);
    return FontWeight.values[index];
  }

  /// The resolved font family for the price.
  String get priceFamily =>
      (priceFontFamily ?? 'body').toLowerCase() == 'display' ? WizType.display : WizType.bodyFont;

  bool get isPriceGlowing => priceGlow ?? false;

  /// Size of a plan card's art, from `visual_width` / `visual_height`, inside a block
  /// `art_block_height` tall. The block clips, so the art height is capped to it — raise the
  /// block to make the art genuinely bigger. `visual_opacity` is deliberately not applied:
  /// fading art a plan named would be editing it, not laying it out.
  static const double defaultArtSize = 88;
  static const double defaultArtBlockHeight = 110;

  /// The art for [optionId]: whatever `option_visuals` names, else the shared mascot.
  /// [VisualAssetWidget] takes it from here — image, Lottie, SVG, asset or URL alike.
  String artPathFor(String optionId) {
    final path = (optionVisuals[optionId] ?? '').trim();
    return path.isEmpty ? WizMascot.asset : path;
  }

  double get artBlockHeight => artBlockHeightConfig ?? defaultArtBlockHeight;
  double get artWidth => visualWidth ?? defaultArtSize;
  double get artHeight =>
      (visualHeight ?? visualWidth ?? defaultArtSize).clamp(0.0, artBlockHeight);

  /// Whether the option visuals should loop. Defaults to true when not set in remote config.
  bool get isAnimationLooped => animationLooped ?? true;

  factory PaywallMetadata.fromJson(Map<String, dynamic> json) => _$PaywallMetadataFromJson(json);

  static PaywallLayout _layoutFromJson(String? value) =>
      PaywallLayout.fromString(value);

  static String? _layoutToJson(PaywallLayout layout) => layout.name;

  static PaywallCardStyle _cardStyleFromJson(String? value) =>
      PaywallCardStyle.fromString(value);

  static String _cardStyleToJson(PaywallCardStyle style) => style.name;

  Map<String, dynamic> toJson() => _$PaywallMetadataToJson(this);
}
