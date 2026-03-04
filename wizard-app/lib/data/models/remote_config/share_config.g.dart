// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShareConfig _$ShareConfigFromJson(Map<String, dynamic> json) => ShareConfig(
  title: ShareConfig._multilocaleFromJson(json['title']),
  description: ShareConfig._multilocaleFromJson(json['description']),
  imageUrl: json['image_url'] as String?,
  linkUrl: json['link_url'] as String?,
);

Map<String, dynamic> _$ShareConfigToJson(ShareConfig instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'link_url': instance.linkUrl,
    };
