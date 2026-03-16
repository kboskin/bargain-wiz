// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refer_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReferConfig _$ReferConfigFromJson(Map<String, dynamic> json) => ReferConfig(
  title: ReferConfig._multilocaleFromJson(json['title']),
  benefits: json['benefits'] == null
      ? const []
      : ReferConfig._benefitsFromJson(json['benefits']),
  ctaButtonText: ReferConfig._multilocaleFromJson(json['cta_button_text']),
  shareTitle: ReferConfig._multilocaleFromJson(json['share_title']),
  shareDescription: ReferConfig._multilocaleFromJson(json['share_description']),
  shareLinkUrl: json['share_link_url'] as String?,
  highlightWords: json['highlight_words'],
  highlightColor: json['highlight_color'] as String?,
  textColor: json['text_color'] as String?,
);

Map<String, dynamic> _$ReferConfigToJson(ReferConfig instance) =>
    <String, dynamic>{
      'title': instance.title,
      'benefits': instance.benefits,
      'cta_button_text': instance.ctaButtonText,
      'share_title': instance.shareTitle,
      'share_description': instance.shareDescription,
      'share_link_url': instance.shareLinkUrl,
      'highlight_words': instance.highlightWords,
      'highlight_color': instance.highlightColor,
      'text_color': instance.textColor,
    };
