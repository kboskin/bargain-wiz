// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main_page_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MainPageConfig _$MainPageConfigFromJson(Map<String, dynamic> json) =>
    MainPageConfig(
      headerText: MainPageConfig._multilocaleFromJson(json['header_text']),
      uploadButtonText:
          MainPageConfig._multilocaleFromJson(json['upload_button_text']),
      enterTextButtonText: MainPageConfig._multilocaleFromJson(
          json['enter_text_button_text']),
      getPickupLinesButtonText: MainPageConfig._multilocaleFromJson(
          json['get_pickup_lines_button_text']),
      centerVisual: json['center_visual'] == null
          ? null
          : MainPageCenterVisual.fromJson(
              json['center_visual'] as Map<String, dynamic>),
      stripeOpacity: (json['stripe_opacity'] as num?)?.toDouble(),
      background: json['background'] == null
          ? null
          : GradientBackgroundConfig.fromJson(
              json['background'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MainPageConfigToJson(MainPageConfig instance) =>
    <String, dynamic>{
      'header_text': instance.headerText?.toJson(),
      'upload_button_text': instance.uploadButtonText?.toJson(),
      'enter_text_button_text': instance.enterTextButtonText?.toJson(),
      'get_pickup_lines_button_text':
          instance.getPickupLinesButtonText?.toJson(),
      'center_visual': instance.centerVisual?.toJson(),
      'stripe_opacity': instance.stripeOpacity,
      'background': instance.background?.toJson(),
    };

MainPageCenterVisual _$MainPageCenterVisualFromJson(
        Map<String, dynamic> json) =>
    MainPageCenterVisual(
      visual: json['visual'] as String,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$MainPageCenterVisualToJson(
        MainPageCenterVisual instance) =>
    <String, dynamic>{
      'visual': instance.visual,
      'width': instance.width,
      'height': instance.height,
    };
