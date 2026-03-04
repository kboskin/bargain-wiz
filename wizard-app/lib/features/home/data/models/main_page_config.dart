import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/gradient_background_config.dart';
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

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  factory MainPageConfig.fromJson(Map<String, dynamic> json) =>
      _$MainPageConfigFromJson(json);

  Map<String, dynamic> toJson() => _$MainPageConfigToJson(this);
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
