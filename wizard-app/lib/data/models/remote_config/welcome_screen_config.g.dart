// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'welcome_screen_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WelcomeScreenConfig _$WelcomeScreenConfigFromJson(Map<String, dynamic> json) =>
    WelcomeScreenConfig(
      title: json['title'],
      description: json['description'],
      visual: json['visual'] as String?,
      primaryButtonText: json['primary_button_text'],
      glassContainer: json['glass_container'] == null
          ? null
          : GlassContainerConfig.fromJson(
              json['glass_container'] as Map<String, dynamic>,
            ),
      highlightWords: json['highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['highlight_words'] as Map<String, dynamic>,
            ),
      secondaryAction: json['secondary_action'] == null
          ? null
          : SecondaryActionConfig.fromJson(
              json['secondary_action'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
    );

Map<String, dynamic> _$WelcomeScreenConfigToJson(
  WelcomeScreenConfig instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'visual': instance.visual,
  'primary_button_text': instance.primaryButtonText,
  'glass_container': instance.glassContainer,
  'highlight_words': instance.highlightWords,
  'secondary_action': instance.secondaryAction,
  'highlight_color': instance.highlightColor,
};

GlassContainerConfig _$GlassContainerConfigFromJson(
  Map<String, dynamic> json,
) => GlassContainerConfig(
  blurSigma: (json['blur_sigma'] as num).toDouble(),
  color: json['color'] as String,
  opacity: (json['opacity'] as num).toDouble(),
  borderRadius: (json['border_radius'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
  iconSize: (json['icon_size'] as num).toDouble(),
  iconOpacity: (json['icon_opacity'] as num).toDouble(),
);

Map<String, dynamic> _$GlassContainerConfigToJson(
  GlassContainerConfig instance,
) => <String, dynamic>{
  'blur_sigma': instance.blurSigma,
  'color': instance.color,
  'opacity': instance.opacity,
  'border_radius': instance.borderRadius,
  'height': instance.height,
  'icon_size': instance.iconSize,
  'icon_opacity': instance.iconOpacity,
};

HighlightWordsConfig _$HighlightWordsConfigFromJson(
  Map<String, dynamic> json,
) => HighlightWordsConfig(
  title: json['title'],
  description: json['description'],
);

Map<String, dynamic> _$HighlightWordsConfigToJson(
  HighlightWordsConfig instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
};

SecondaryActionConfig _$SecondaryActionConfigFromJson(
  Map<String, dynamic> json,
) => SecondaryActionConfig(
  type: json['type'] as String,
  text: json['text'],
  prefixText: json['prefix_text'],
);

Map<String, dynamic> _$SecondaryActionConfigToJson(
  SecondaryActionConfig instance,
) => <String, dynamic>{
  'type': instance.type,
  'text': instance.text,
  'prefix_text': instance.prefixText,
};
