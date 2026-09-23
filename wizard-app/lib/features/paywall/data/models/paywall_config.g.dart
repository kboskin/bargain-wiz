// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paywall_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaywallConfig _$PaywallConfigFromJson(
  Map<String, dynamic> json,
) => PaywallConfig(
  type: json['type'] as String,
  title: PaywallConfig._multilocaleFromJson(json['title']),
  description: PaywallConfig._multilocaleFromJson(json['description']),
  options: (json['options'] as List<dynamic>)
      .map((e) => PaywallOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: PaywallMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  nextButtonText: PaywallConfig._multilocaleFromJson(json['next_button_text']),
  noteText: PaywallConfig._multilocaleFromJson(json['note_text']),
  showRestore: json['show_restore'] as bool? ?? true,
  showClose: json['show_close'] as bool? ?? false,
  showContextHint: json['show_context_hint'] as bool? ?? true,
  showNote: json['show_note'] as bool? ?? true,
  closeButtonDelaySeconds:
      (json['close_button_delay_seconds'] as num?)?.toDouble() ?? 5.0,
  paymentProvider: json['payment_provider'] as String?,
  trialDays: (json['trial_days'] as num?)?.toInt() ?? 3,
  steps:
      (json['steps'] as List<dynamic>?)
          ?.map((e) => PaywallStepConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  background: json['background'] == null
      ? null
      : PaywallBackgroundConfig.fromJson(
          json['background'] as Map<String, dynamic>,
        ),
  noPaymentDueText: PaywallConfig._multilocaleFromJson(
    json['no_payment_due_text'],
  ),
  timelineTodayText: PluralText.fromJson(json['timeline_today_text']),
  timelineReminderText: PluralText.fromJson(json['timeline_reminder_text']),
  timelineBillingText: PluralText.fromJson(json['timeline_billing_text']),
  timelineTodaySubtitle: PaywallConfig._multilocaleFromJson(
    json['timeline_today_subtitle'],
  ),
  timelineReminderSubtitle: PaywallConfig._multilocaleFromJson(
    json['timeline_reminder_subtitle'],
  ),
  timelineBillingSubtitle: PaywallConfig._multilocaleFromJson(
    json['timeline_billing_subtitle'],
  ),
  titleHighlightWords: json['title_highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['title_highlight_words'] as Map<String, dynamic>,
        ),
  descriptionHighlightWords: json['description_highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['description_highlight_words'] as Map<String, dynamic>,
        ),
  noPaymentHighlightWords: json['no_payment_highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['no_payment_highlight_words'] as Map<String, dynamic>,
        ),
  contextHints: json['context_hints'] == null
      ? const {}
      : PaywallConfig._hintsFromJson(json['context_hints']),
  trialTimeline:
      (json['trial_timeline'] as List<dynamic>?)
          ?.map(
            (e) => PaywallTimelineRowConfig.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  entryPoints:
      (json['entry_points'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  planCard: json['plan_card'] == null
      ? null
      : PaywallPlanCardConfig.fromJson(
          json['plan_card'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$PaywallConfigToJson(PaywallConfig instance) =>
    <String, dynamic>{
      'type': instance.type,
      'title': instance.title,
      'description': instance.description,
      'options': instance.options,
      'metadata': instance.metadata,
      'next_button_text': instance.nextButtonText,
      'note_text': instance.noteText,
      'show_restore': instance.showRestore,
      'show_close': instance.showClose,
      'show_context_hint': instance.showContextHint,
      'show_note': instance.showNote,
      'close_button_delay_seconds': instance.closeButtonDelaySeconds,
      'payment_provider': instance.paymentProvider,
      'trial_days': instance.trialDays,
      'steps': instance.steps,
      'background': instance.background,
      'title_highlight_words': instance.titleHighlightWords,
      'description_highlight_words': instance.descriptionHighlightWords,
      'no_payment_highlight_words': instance.noPaymentHighlightWords,
      'no_payment_due_text': instance.noPaymentDueText,
      'timeline_today_text': PaywallConfig._pluralToJson(
        instance.timelineTodayText,
      ),
      'timeline_reminder_text': PaywallConfig._pluralToJson(
        instance.timelineReminderText,
      ),
      'timeline_billing_text': PaywallConfig._pluralToJson(
        instance.timelineBillingText,
      ),
      'timeline_today_subtitle': instance.timelineTodaySubtitle,
      'timeline_reminder_subtitle': instance.timelineReminderSubtitle,
      'timeline_billing_subtitle': instance.timelineBillingSubtitle,
      'context_hints': instance.contextHints,
      'trial_timeline': instance.trialTimeline,
      'entry_points': instance.entryPoints,
      'plan_card': instance.planCard,
    };

PaywallTimelineRowConfig _$PaywallTimelineRowConfigFromJson(
  Map<String, dynamic> json,
) => PaywallTimelineRowConfig(
  day: (json['day'] as num).toInt(),
  title: PaywallTimelineRowConfig._multilocaleFromJson(json['title']),
  subtitle: PaywallTimelineRowConfig._multilocaleFromJson(json['subtitle']),
);

Map<String, dynamic> _$PaywallTimelineRowConfigToJson(
  PaywallTimelineRowConfig instance,
) => <String, dynamic>{
  'day': instance.day,
  'title': instance.title,
  'subtitle': instance.subtitle,
};

PaywallStepConfig _$PaywallStepConfigFromJson(Map<String, dynamic> json) =>
    PaywallStepConfig(
      id: json['id'] as String?,
      title: PaywallStepConfig._multilocaleFromJson(json['title']),
      description: PaywallStepConfig._multilocaleFromJson(json['description']),
      visual: json['visual'] as String?,
      visualSize: (json['visual_size'] as num?)?.toDouble(),
      noteText: PaywallStepConfig._multilocaleFromJson(json['note_text']),
      buttonText: PaywallStepConfig._multilocaleFromJson(json['button_text']),
      titleHighlightWords: json['title_highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['title_highlight_words'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
      buttonAction: json['button_action'] as String?,
    );

Map<String, dynamic> _$PaywallStepConfigToJson(PaywallStepConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'visual': instance.visual,
      'visual_size': instance.visualSize,
      'note_text': instance.noteText,
      'button_text': instance.buttonText,
      'title_highlight_words': instance.titleHighlightWords,
      'highlight_color': instance.highlightColor,
      'button_action': instance.buttonAction,
    };

PaywallOption _$PaywallOptionFromJson(Map<String, dynamic> json) =>
    PaywallOption(
      id: json['id'] as String,
      tier: json['tier'] as String,
      title: PaywallOption._multilocaleFromJson(json['title']),
      description: PaywallOption._multilocaleFromJson(json['description']),
      badge: PaywallOption._multilocaleFromJson(json['badge']),
      badges: json['badges'] == null
          ? const []
          : PaywallOption._featuresFromJson(json['badges']),
      descriptionHighlightWords:
          json['description_highlight_words'] as Map<String, dynamic>?,
      artColor: json['art_color'] as String?,
      features: json['features'] == null
          ? const []
          : PaywallOption._featuresFromJson(json['features']),
      priceLabel: PaywallOption._multilocaleFromJson(json['price_label']),
      priceSuffix: PaywallOption._multilocaleFromJson(json['price_suffix']),
      trialDays: (json['trial_days'] as num?)?.toInt(),
      trialBadge: PluralText.fromJson(json['trial_badge']),
      noteText: PaywallOption._multilocaleFromJson(json['note_text']),
      buttonText: PaywallOption._multilocaleFromJson(json['button_text']),
    );

Map<String, dynamic> _$PaywallOptionToJson(PaywallOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tier': instance.tier,
      'title': instance.title,
      'description': instance.description,
      'badge': instance.badge,
      'badges': instance.badges,
      'features': instance.features,
      'art_color': instance.artColor,
      'description_highlight_words': instance.descriptionHighlightWords,
      'price_label': instance.priceLabel,
      'price_suffix': instance.priceSuffix,
      'trial_days': instance.trialDays,
      'trial_badge': PaywallOption._pluralToJson(instance.trialBadge),
      'note_text': instance.noteText,
      'button_text': instance.buttonText,
    };

PaywallMetadata _$PaywallMetadataFromJson(Map<String, dynamic> json) =>
    PaywallMetadata(
      defaultSelectedOptionId: json['default_selected_option_id'] as String,
      layout: PaywallMetadata._layoutFromJson(json['layout'] as String?),
      cardStyle: json['card_style'] == null
          ? PaywallCardStyle.glow
          : PaywallMetadata._cardStyleFromJson(json['card_style'] as String?),
      visualWidth: (json['visual_width'] as num?)?.toDouble(),
      visualHeight: (json['visual_height'] as num?)?.toDouble(),
      visualOpacity: (json['visual_opacity'] as num?)?.toDouble(),
      animationLooped: json['animation_looped'] as bool?,
      optionVisuals: Map<String, String>.from(json['option_visuals'] as Map),
      highlightColor: json['highlight_color'] as String?,
      titleFontSize: (json['title_font_size'] as num?)?.toDouble(),
      descriptionFontSize: (json['description_font_size'] as num?)?.toDouble(),
      priceFontSize: (json['price_font_size'] as num?)?.toDouble(),
      priceFontWeight: (json['price_font_weight'] as num?)?.toInt(),
      priceFontFamily: json['price_font_family'] as String?,
      priceGlow: json['price_glow'] as bool?,
      artBlockHeightConfig: (json['art_block_height'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$PaywallMetadataToJson(PaywallMetadata instance) =>
    <String, dynamic>{
      'default_selected_option_id': instance.defaultSelectedOptionId,
      'layout': PaywallMetadata._layoutToJson(instance.layout),
      'card_style': PaywallMetadata._cardStyleToJson(instance.cardStyle),
      'visual_width': instance.visualWidth,
      'visual_height': instance.visualHeight,
      'visual_opacity': instance.visualOpacity,
      'animation_looped': instance.animationLooped,
      'option_visuals': instance.optionVisuals,
      'highlight_color': instance.highlightColor,
      'title_font_size': instance.titleFontSize,
      'description_font_size': instance.descriptionFontSize,
      'price_font_size': instance.priceFontSize,
      'price_font_weight': instance.priceFontWeight,
      'price_font_family': instance.priceFontFamily,
      'price_glow': instance.priceGlow,
      'art_block_height': instance.artBlockHeightConfig,
    };
