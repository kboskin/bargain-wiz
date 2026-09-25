import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/plural_text.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/gradient_background_config.dart';
import 'package:appwizard/features/shared/data/models/deal_objective.dart';
import 'package:json_annotation/json_annotation.dart';

part 'main_page_config.g.dart';

/// Remote config for the main (home) page.
/// RC key: [main_page_config].
@JsonSerializable()
class MainPageConfig {
  MainPageConfig({
    this.headerText,
    this.primaryCtaButton,
    this.additionCtaButton,
    this.generationCtaButton,
    this.expressDealmakerKeywordHint,
    this.expressDealmakerHoldReplyHint,
    this.expressDealmakerTapReplyHint,
    this.photoPermissionDeniedTitle,
    this.photoPermissionDeniedMessage,
    this.photoPermissionSnackbar,
    this.openSettingsButtonText,
    this.cancelButtonText,
    this.galleryUnavailableMessage,
    this.galleryErrorMessage,
    this.galleryErrorTryAgainMessage,
    this.centerVisual,
    this.stripeOpacity,
    this.background,
    this.showMic = true,
    this.emptyHeadline,
    this.emptyHeadlineHighlight,
    this.firstRunNudge,
    this.historySectionTitle,
    this.historySeeAll,
    this.tabs,
    this.expressPickTitle,
    this.expressPickDescription,
    this.expressPickDropzone,
    this.expressPickDropzoneSub,
    this.expressPickCta,
    this.expressUploadingStatus,
    this.expressSeeingPrefix,
    this.expressErrorTitle,
    this.expressErrorBody,
    this.replyWhyLabel,
    this.replyHideLabel,
    this.replyDislikeToast,
    this.proReadingLabel,
    this.proOptionsCta,
    this.proRedoCta,
    this.proAttachCta,
    this.dealCloserObjectiveTitle,
    this.dealCloserObjectives = const [],
    this.offlineBanner,
  });

  /// Text between the top view (app bar) and the center image. Part of main_page_config.
  @JsonKey(name: 'header_text', fromJson: _multilocaleFromJson)
  final dynamic headerText;

  @JsonKey(name: 'primary_cta_button', fromJson: _multilocaleFromJson)
  final dynamic primaryCtaButton;

  @JsonKey(name: 'addition_cta_button', fromJson: _multilocaleFromJson)
  final dynamic additionCtaButton;

  @JsonKey(name: 'generation_cta_button', fromJson: _multilocaleFromJson)
  final dynamic generationCtaButton;

  /// Express Dealmaker: keyword input placeholder. RC key: express_dealmaker_keyword_hint.
  @JsonKey(name: 'express_dealmaker_keyword_hint', fromJson: _multilocaleFromJson)
  final dynamic expressDealmakerKeywordHint;

  /// Express Dealmaker: "hold a reply for more" hint. RC key: express_dealmaker_hold_reply_hint.
  @JsonKey(name: 'express_dealmaker_hold_reply_hint', fromJson: _multilocaleFromJson)
  final dynamic expressDealmakerHoldReplyHint;

  /// Express Dealmaker: tap reply to copy hint. RC key: express_dealmaker_tap_reply_hint.
  @JsonKey(name: 'express_dealmaker_tap_reply_hint', fromJson: _multilocaleFromJson)
  final dynamic expressDealmakerTapReplyHint;

  /// Title for the dialog when photo permission was permanently denied.
  @JsonKey(name: 'photo_permission_denied_title', fromJson: _multilocaleFromJson)
  final dynamic photoPermissionDeniedTitle;

  /// Message for the dialog when photo permission was permanently denied.
  @JsonKey(name: 'photo_permission_denied_message', fromJson: _multilocaleFromJson)
  final dynamic photoPermissionDeniedMessage;

  /// SnackBar text when photo permission is denied (not permanently).
  @JsonKey(name: 'photo_permission_snackbar', fromJson: _multilocaleFromJson)
  final dynamic photoPermissionSnackbar;

  /// Label for the "Open Settings" button in the permission-denied dialog.
  @JsonKey(name: 'open_settings_button_text', fromJson: _multilocaleFromJson)
  final dynamic openSettingsButtonText;

  /// Label for the Cancel button in dialogs (e.g. permission-denied).
  @JsonKey(name: 'cancel_button_text', fromJson: _multilocaleFromJson)
  final dynamic cancelButtonText;

  /// Shown when gallery picker fails with channel-error (e.g. after hot reload).
  @JsonKey(name: 'gallery_unavailable_message', fromJson: _multilocaleFromJson)
  final dynamic galleryUnavailableMessage;

  /// Fallback when gallery picker fails with a platform error (no message).
  @JsonKey(name: 'gallery_error_message', fromJson: _multilocaleFromJson)
  final dynamic galleryErrorMessage;

  /// Shown when gallery picker fails with an unexpected error.
  @JsonKey(name: 'gallery_error_try_again_message', fromJson: _multilocaleFromJson)
  final dynamic galleryErrorTryAgainMessage;

  @JsonKey(name: 'center_visual')
  final MainPageCenterVisual? centerVisual;

  /// Opacity of the stripe (0.0–1.0). If null, uses 0.12. Use 0 to hide the stripe.
  @JsonKey(name: 'stripe_opacity')
  final double? stripeOpacity;

  /// Gradient background for the main screen. If null, app uses default gradient.
  @JsonKey(name: 'background')
  final GradientBackgroundConfig? background;

  /// Whether the microphone button in the start-with-text input is shown.
  /// RC key: show_mic. Defaults to true when missing.
  @JsonKey(name: 'show_mic', defaultValue: true)
  final bool showMic;

  // ── Redesign (design_handoff_bargain_wiz) ──

  /// Home empty-state headline, e.g. "Your deal, upgraded." RC key: empty_headline.
  @JsonKey(name: 'empty_headline', fromJson: _multilocaleFromJson)
  final dynamic emptyHeadline;

  /// Highlight map for [emptyHeadline], e.g. {"upgraded.": "#7B5EA7"}.
  @JsonKey(name: 'empty_headline_highlight')
  final Map<String, dynamic>? emptyHeadlineHighlight;

  /// Bobbing hint shown until the first Express run. RC key: first_run_nudge.
  @JsonKey(name: 'first_run_nudge', fromJson: _multilocaleFromJson)
  final dynamic firstRunNudge;

  @JsonKey(name: 'history_section_title', fromJson: _multilocaleFromJson)
  final dynamic historySectionTitle;

  @JsonKey(name: 'history_see_all', fromJson: _multilocaleFromJson)
  final dynamic historySeeAll;

  /// Bottom tab bar items: [{id: home|lines|history|profile, label: {...}}].
  @JsonKey(name: 'tabs')
  final List<MainPageTabConfig>? tabs;

  @JsonKey(name: 'express_pick_title', fromJson: _multilocaleFromJson)
  final dynamic expressPickTitle;

  @JsonKey(name: 'express_pick_description', fromJson: _multilocaleFromJson)
  final dynamic expressPickDescription;

  @JsonKey(name: 'express_pick_dropzone', fromJson: _multilocaleFromJson)
  final dynamic expressPickDropzone;

  @JsonKey(name: 'express_pick_dropzone_sub', fromJson: _multilocaleFromJson)
  final dynamic expressPickDropzoneSub;

  /// Plural CTA: {"one": {...}, "other": {... "{n}" ...}}.
  @JsonKey(name: 'express_pick_cta', fromJson: PluralText.fromJson, toJson: _pluralToJson)
  final PluralText? expressPickCta;

  @JsonKey(name: 'express_uploading_status', fromJson: _multilocaleFromJson)
  final dynamic expressUploadingStatus;

  @JsonKey(name: 'express_seeing_prefix', fromJson: _multilocaleFromJson)
  final dynamic expressSeeingPrefix;

  @JsonKey(name: 'express_error_title', fromJson: _multilocaleFromJson)
  final dynamic expressErrorTitle;

  @JsonKey(name: 'express_error_body', fromJson: _multilocaleFromJson)
  final dynamic expressErrorBody;

  @JsonKey(name: 'reply_why_label', fromJson: _multilocaleFromJson)
  final dynamic replyWhyLabel;

  @JsonKey(name: 'reply_hide_label', fromJson: _multilocaleFromJson)
  final dynamic replyHideLabel;

  @JsonKey(name: 'reply_dislike_toast', fromJson: _multilocaleFromJson)
  final dynamic replyDislikeToast;

  @JsonKey(name: 'pro_reading_label', fromJson: _multilocaleFromJson)
  final dynamic proReadingLabel;

  @JsonKey(name: 'pro_options_cta', fromJson: _multilocaleFromJson)
  final dynamic proOptionsCta;

  @JsonKey(name: 'pro_redo_cta', fromJson: _multilocaleFromJson)
  final dynamic proRedoCta;

  @JsonKey(name: 'pro_attach_cta', fromJson: PluralText.fromJson, toJson: _pluralToJson)
  final PluralText? proAttachCta;

  /// The wizard's question above the objective chips, before a deal starts.
  @JsonKey(name: 'deal_closer_objective_title', fromJson: _multilocaleFromJson)
  final dynamic dealCloserObjectiveTitle;

  /// What a deal can be started for, in chip order; empty hides the question. Not tied to
  /// one flow: the Pro chat asks today, and any deal closer can reuse the same list.
  @JsonKey(name: 'deal_closer_objectives', defaultValue: <DealObjective>[], includeToJson: false)
  final List<DealObjective> dealCloserObjectives;

  @JsonKey(name: 'offline_banner', fromJson: _multilocaleFromJson)
  final dynamic offlineBanner;

  static dynamic _pluralToJson(PluralText? value) => value?.toJson();

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  factory MainPageConfig.fromJson(Map<String, dynamic> json) =>
      _$MainPageConfigFromJson(json);

  Map<String, dynamic> toJson() => _$MainPageConfigToJson(this);
}

/// One bottom tab. RC: main_page_config.tabs[].
@JsonSerializable()
class MainPageTabConfig {
  MainPageTabConfig({required this.id, this.label});

  /// "home" | "lines" | "history" | "profile"
  final String id;

  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic label;

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  factory MainPageTabConfig.fromJson(Map<String, dynamic> json) =>
      _$MainPageTabConfigFromJson(json);

  Map<String, dynamic> toJson() => _$MainPageTabConfigToJson(this);
}

/// Center visual: path + optional width/height (same approach as onboarding).
@JsonSerializable()
class MainPageCenterVisual {
  MainPageCenterVisual({
    required this.visual,
    this.width,
    this.height,
  });

  /// Asset path or URL (Lottie, SVG, or image) – rendered via VisualAssetWidget.
  final String visual;

  final double? width;
  final double? height;

  factory MainPageCenterVisual.fromJson(Map<String, dynamic> json) =>
      _$MainPageCenterVisualFromJson(json);

  Map<String, dynamic> toJson() => _$MainPageCenterVisualToJson(this);
}
