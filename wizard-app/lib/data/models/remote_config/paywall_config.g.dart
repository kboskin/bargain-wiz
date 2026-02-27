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
    };

PaywallOption _$PaywallOptionFromJson(Map<String, dynamic> json) =>
    PaywallOption(
      id: json['id'] as String,
      tier: json['tier'] as String,
      title: PaywallOption._multilocaleFromJson(json['title']),
      description: PaywallOption._multilocaleFromJson(json['description']),
      badge: PaywallOption._multilocaleFromJson(json['badge']),
    );

Map<String, dynamic> _$PaywallOptionToJson(PaywallOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tier': instance.tier,
      'title': instance.title,
      'description': instance.description,
      'badge': instance.badge,
    };

PaywallMetadata _$PaywallMetadataFromJson(Map<String, dynamic> json) =>
    PaywallMetadata(
      defaultSelectedOptionId: json['default_selected_option_id'] as String,
      layout: PaywallMetadata._layoutFromJson(json['layout'] as String?),
      cardStyle: json['card_style'] as String?,
      visualWidth: (json['visual_width'] as num?)?.toDouble(),
      visualHeight: (json['visual_height'] as num?)?.toDouble(),
      visualOpacity: (json['visual_opacity'] as num?)?.toDouble(),
      optionVisuals: Map<String, String>.from(json['option_visuals'] as Map),
    );

Map<String, dynamic> _$PaywallMetadataToJson(PaywallMetadata instance) =>
    <String, dynamic>{
      'default_selected_option_id': instance.defaultSelectedOptionId,
      'layout': PaywallMetadata._layoutToJson(instance.layout),
      'card_style': instance.cardStyle,
      'visual_width': instance.visualWidth,
      'visual_height': instance.visualHeight,
      'visual_opacity': instance.visualOpacity,
      'option_visuals': instance.optionVisuals,
    };
