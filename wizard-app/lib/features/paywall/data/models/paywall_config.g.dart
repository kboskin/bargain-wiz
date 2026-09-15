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
  timelineTodayText: PaywallConfig._multilocaleFromJson(
    json['timeline_today_text'],
  ),
  timelineReminderText: PaywallConfig._multilocaleFromJson(
    json['timeline_reminder_text'],
  ),
  timelineBillingText: PaywallConfig._multilocaleFromJson(
    json['timeline_billing_text'],
  ),
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
      'close_button_delay_seconds': instance.closeButtonDelaySeconds,
      'payment_provider': instance.paymentProvider,
      'trial_days': instance.trialDays,
      'steps': instance.steps,
      'background': instance.background,
      'title_highlight_words': instance.titleHighlightWords,
      'description_highlight_words': instance.descriptionHighlightWords,
      'no_payment_highlight_words': instance.noPaymentHighlightWords,
      'no_payment_due_text': instance.noPaymentDueText,
      'timeline_today_text': instance.timelineTodayText,
      'timeline_reminder_text': instance.timelineReminderText,
      'timeline_billing_text': instance.timelineBillingText,
      'timeline_today_subtitle': instance.timelineTodaySubtitle,
      'timeline_reminder_subtitle': instance.timelineReminderSubtitle,
      'timeline_billing_subtitle': instance.timelineBillingSubtitle,
      'context_hints': instance.contextHints,
      'trial_timeline': instance.trialTimeline,
      'entry_points': instance.entryPoints,
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
      noteText: PaywallStepConfig._multilocaleFromJson(json['note_text']),
      buttonText: PaywallStepConfig._multilocaleFromJson(json['button_text']),
      titleHighlightWords: json['title_highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['title_highlight_words'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
    );

Map<String, dynamic> _$PaywallStepConfigToJson(PaywallStepConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'visual': instance.visual,
      'note_text': instance.noteText,
      'button_text': instance.buttonText,
      'title_highlight_words': instance.titleHighlightWords,
      'highlight_color': instance.highlightColor,
    };

PaywallOption _$PaywallOptionFromJson(Map<String, dynamic> json) =>
    PaywallOption(
      id: json['id'] as String,
      tier: json['tier'] as String,
      title: PaywallOption._multilocaleFromJson(json['title']),
      description: PaywallOption._multilocaleFromJson(json['description']),
      badge: PaywallOption._multilocaleFromJson(json['badge']),
      features: json['features'] == null
          ? const []
          : PaywallOption._featuresFromJson(json['features']),
      priceLabel: PaywallOption._multilocaleFromJson(json['price_label']),
    );

Map<String, dynamic> _$PaywallOptionToJson(PaywallOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tier': instance.tier,
      'title': instance.title,
      'description': instance.description,
      'badge': instance.badge,
      'features': instance.features,
      'price_label': instance.priceLabel,
    };

PaywallMetadata _$PaywallMetadataFromJson(Map<String, dynamic> json) =>
    PaywallMetadata(
      defaultSelectedOptionId: json['default_selected_option_id'] as String,
      layout: PaywallMetadata._layoutFromJson(json['layout'] as String?),
      cardStyle: json['card_style'] as String?,
      visualWidth: (json['visual_width'] as num?)?.toDouble(),
      visualHeight: (json['visual_height'] as num?)?.toDouble(),
      visualOpacity: (json['visual_opacity'] as num?)?.toDouble(),
      animationLooped: json['animation_looped'] as bool?,
      optionVisuals: Map<String, String>.from(json['option_visuals'] as Map),
      highlightColor: json['highlight_color'] as String?,
    );

Map<String, dynamic> _$PaywallMetadataToJson(PaywallMetadata instance) =>
    <String, dynamic>{
      'default_selected_option_id': instance.defaultSelectedOptionId,
      'layout': PaywallMetadata._layoutToJson(instance.layout),
      'card_style': instance.cardStyle,
      'visual_width': instance.visualWidth,
      'visual_height': instance.visualHeight,
      'visual_opacity': instance.visualOpacity,
      'animation_looped': instance.animationLooped,
      'option_visuals': instance.optionVisuals,
      'highlight_color': instance.highlightColor,
    };
