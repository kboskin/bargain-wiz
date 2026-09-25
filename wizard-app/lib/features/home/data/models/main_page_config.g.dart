// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main_page_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MainPageConfig _$MainPageConfigFromJson(
  Map<String, dynamic> json,
) => MainPageConfig(
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
  emptyHeadline: MainPageConfig._multilocaleFromJson(json['empty_headline']),
  emptyHeadlineHighlight:
      json['empty_headline_highlight'] as Map<String, dynamic>?,
  firstRunNudge: MainPageConfig._multilocaleFromJson(json['first_run_nudge']),
  historySectionTitle: MainPageConfig._multilocaleFromJson(
    json['history_section_title'],
  ),
  historySeeAll: MainPageConfig._multilocaleFromJson(json['history_see_all']),
  tabs: (json['tabs'] as List<dynamic>?)
      ?.map((e) => MainPageTabConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
  expressPickTitle: MainPageConfig._multilocaleFromJson(
    json['express_pick_title'],
  ),
  expressPickDescription: MainPageConfig._multilocaleFromJson(
    json['express_pick_description'],
  ),
  expressPickDropzone: MainPageConfig._multilocaleFromJson(
    json['express_pick_dropzone'],
  ),
  expressPickDropzoneSub: MainPageConfig._multilocaleFromJson(
    json['express_pick_dropzone_sub'],
  ),
  expressPickCta: PluralText.fromJson(json['express_pick_cta']),
  expressUploadingStatus: MainPageConfig._multilocaleFromJson(
    json['express_uploading_status'],
  ),
  expressSeeingPrefix: MainPageConfig._multilocaleFromJson(
    json['express_seeing_prefix'],
  ),
  expressErrorTitle: MainPageConfig._multilocaleFromJson(
    json['express_error_title'],
  ),
  expressErrorBody: MainPageConfig._multilocaleFromJson(
    json['express_error_body'],
  ),
  replyWhyLabel: MainPageConfig._multilocaleFromJson(json['reply_why_label']),
  replyHideLabel: MainPageConfig._multilocaleFromJson(json['reply_hide_label']),
  replyDislikeToast: MainPageConfig._multilocaleFromJson(
    json['reply_dislike_toast'],
  ),
  proReadingLabel: MainPageConfig._multilocaleFromJson(
    json['pro_reading_label'],
  ),
  proOptionsCta: MainPageConfig._multilocaleFromJson(json['pro_options_cta']),
  proRedoCta: MainPageConfig._multilocaleFromJson(json['pro_redo_cta']),
  proAttachCta: PluralText.fromJson(json['pro_attach_cta']),
  dealCloserObjectiveTitle: MainPageConfig._multilocaleFromJson(
    json['deal_closer_objective_title'],
  ),
  dealCloserObjectives:
      (json['deal_closer_objectives'] as List<dynamic>?)
          ?.map((e) => DealObjective.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  offlineBanner: MainPageConfig._multilocaleFromJson(json['offline_banner']),
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
  'empty_headline': instance.emptyHeadline,
  'empty_headline_highlight': instance.emptyHeadlineHighlight,
  'first_run_nudge': instance.firstRunNudge,
  'history_section_title': instance.historySectionTitle,
  'history_see_all': instance.historySeeAll,
  'tabs': instance.tabs,
  'express_pick_title': instance.expressPickTitle,
  'express_pick_description': instance.expressPickDescription,
  'express_pick_dropzone': instance.expressPickDropzone,
  'express_pick_dropzone_sub': instance.expressPickDropzoneSub,
  'express_pick_cta': MainPageConfig._pluralToJson(instance.expressPickCta),
  'express_uploading_status': instance.expressUploadingStatus,
  'express_seeing_prefix': instance.expressSeeingPrefix,
  'express_error_title': instance.expressErrorTitle,
  'express_error_body': instance.expressErrorBody,
  'reply_why_label': instance.replyWhyLabel,
  'reply_hide_label': instance.replyHideLabel,
  'reply_dislike_toast': instance.replyDislikeToast,
  'pro_reading_label': instance.proReadingLabel,
  'pro_options_cta': instance.proOptionsCta,
  'pro_redo_cta': instance.proRedoCta,
  'pro_attach_cta': MainPageConfig._pluralToJson(instance.proAttachCta),
  'deal_closer_objective_title': instance.dealCloserObjectiveTitle,
  'offline_banner': instance.offlineBanner,
};

MainPageTabConfig _$MainPageTabConfigFromJson(Map<String, dynamic> json) =>
    MainPageTabConfig(
      id: json['id'] as String,
      label: MainPageTabConfig._multilocaleFromJson(json['label']),
    );

Map<String, dynamic> _$MainPageTabConfigToJson(MainPageTabConfig instance) =>
    <String, dynamic>{'id': instance.id, 'label': instance.label};

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
