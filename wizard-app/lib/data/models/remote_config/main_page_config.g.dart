// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main_page_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MainPageConfig _$MainPageConfigFromJson(Map<String, dynamic> json) =>
    MainPageConfig(
      headerText: MainPageConfig._multilocaleFromJson(json['header_text']),
      primaryCtaButton: MainPageConfig._multilocaleFromJson(
        json['primary_cta_button'],
      ),
      additionCtaButton: MainPageConfig._multilocaleFromJson(
        json['addition_cta_button'],
      ),
      generationCtaButton: MainPageConfig._multilocaleFromJson(
        json['generation_cta_button'],
      ),
      expressDealmakerKeywordHint: MainPageConfig._multilocaleFromJson(
        json['express_dealmaker_keyword_hint'],
      ),
      expressDealmakerHoldReplyHint: MainPageConfig._multilocaleFromJson(
        json['express_dealmaker_hold_reply_hint'],
      ),
      expressDealmakerTapReplyHint: MainPageConfig._multilocaleFromJson(
        json['express_dealmaker_tap_reply_hint'],
      ),
      photoPermissionDeniedTitle: MainPageConfig._multilocaleFromJson(
        json['photo_permission_denied_title'],
      ),
      photoPermissionDeniedMessage: MainPageConfig._multilocaleFromJson(
        json['photo_permission_denied_message'],
      ),
      photoPermissionSnackbar: MainPageConfig._multilocaleFromJson(
        json['photo_permission_snackbar'],
      ),
      openSettingsButtonText: MainPageConfig._multilocaleFromJson(
        json['open_settings_button_text'],
      ),
      cancelButtonText: MainPageConfig._multilocaleFromJson(
        json['cancel_button_text'],
      ),
      galleryUnavailableMessage: MainPageConfig._multilocaleFromJson(
        json['gallery_unavailable_message'],
      ),
      galleryErrorMessage: MainPageConfig._multilocaleFromJson(
        json['gallery_error_message'],
      ),
      galleryErrorTryAgainMessage: MainPageConfig._multilocaleFromJson(
        json['gallery_error_try_again_message'],
      ),
      centerVisual: json['center_visual'] == null
          ? null
          : MainPageCenterVisual.fromJson(
              json['center_visual'] as Map<String, dynamic>,
            ),
      stripeOpacity: (json['stripe_opacity'] as num?)?.toDouble(),
      background: json['background'] == null
          ? null
          : GradientBackgroundConfig.fromJson(
              json['background'] as Map<String, dynamic>,
            ),
      showMic: json['show_mic'] as bool? ?? true,
    );

Map<String, dynamic> _$MainPageConfigToJson(
  MainPageConfig instance,
) => <String, dynamic>{
  'header_text': instance.headerText,
  'primary_cta_button': instance.primaryCtaButton,
  'addition_cta_button': instance.additionCtaButton,
  'generation_cta_button': instance.generationCtaButton,
  'express_dealmaker_keyword_hint': instance.expressDealmakerKeywordHint,
  'express_dealmaker_hold_reply_hint': instance.expressDealmakerHoldReplyHint,
  'express_dealmaker_tap_reply_hint': instance.expressDealmakerTapReplyHint,
  'photo_permission_denied_title': instance.photoPermissionDeniedTitle,
  'photo_permission_denied_message': instance.photoPermissionDeniedMessage,
  'photo_permission_snackbar': instance.photoPermissionSnackbar,
  'open_settings_button_text': instance.openSettingsButtonText,
  'cancel_button_text': instance.cancelButtonText,
  'gallery_unavailable_message': instance.galleryUnavailableMessage,
  'gallery_error_message': instance.galleryErrorMessage,
  'gallery_error_try_again_message': instance.galleryErrorTryAgainMessage,
  'center_visual': instance.centerVisual,
  'stripe_opacity': instance.stripeOpacity,
  'background': instance.background,
  'show_mic': instance.showMic,
};

MainPageCenterVisual _$MainPageCenterVisualFromJson(
  Map<String, dynamic> json,
) => MainPageCenterVisual(
  visual: json['visual'] as String,
  width: (json['width'] as num?)?.toDouble(),
  height: (json['height'] as num?)?.toDouble(),
);

Map<String, dynamic> _$MainPageCenterVisualToJson(
  MainPageCenterVisual instance,
) => <String, dynamic>{
  'visual': instance.visual,
  'width': instance.width,
  'height': instance.height,
};
