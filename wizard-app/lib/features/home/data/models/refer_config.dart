import 'package:flutter/material.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:json_annotation/json_annotation.dart';

part 'refer_config.g.dart';

/// Remote config for the Refer / invite-friends flow (key: [refer_config]).
/// Title, benefit bullets, and CTA button text; optional referral-specific share content.
/// [highlightWords] and [highlightColor] match onboarding: same shape as rate_us_modal / onboarding
/// (e.g. highlight_words: { "title": {"earn": "#4ECDC4"}, "description": {"rewards": "bold"} }).
@JsonSerializable()
class ReferConfig {
  ReferConfig({
    this.title,
    this.benefits = const [],
    this.ctaButtonText,
    this.shareTitle,
    this.shareDescription,
    this.shareLinkUrl,
    this.highlightWords,
    this.highlightColor,
    this.textColor,
  });

  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;

  @JsonKey(fromJson: _benefitsFromJson)
  final List<dynamic> benefits;

  @JsonKey(name: 'cta_button_text', fromJson: _multilocaleFromJson)
  final dynamic ctaButtonText;

  @JsonKey(name: 'share_title', fromJson: _multilocaleFromJson)
  final dynamic shareTitle;

  @JsonKey(name: 'share_description', fromJson: _multilocaleFromJson)
  final dynamic shareDescription;

  @JsonKey(name: 'share_link_url')
  final String? shareLinkUrl;

  /// Same as onboarding: map with "title" and/or "description" keys; values are word→color/bold maps.
  @JsonKey(name: 'highlight_words')
  final dynamic highlightWords;

  /// Default highlight color (hex string) when word has no specific color.
  @JsonKey(name: 'highlight_color')
  final String? highlightColor;

  /// Base text color for title and body (hex string). Defaults to white when null or invalid.
  @JsonKey(name: 'text_color')
  final String? textColor;

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  static List<dynamic> _benefitsFromJson(dynamic json) {
    if (json is! List) return [];
    return json
        .map((e) => e != null ? MultilocaleText.fromJson(e) : const MultilocaleText(''))
        .toList();
  }

  factory ReferConfig.fromJson(Map<String, dynamic> json) => _$ReferConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ReferConfigToJson(this);

  /// Resolve [textColor] to a [Color]. Returns white when null or invalid.
  Color getTextColor(ColorHelper colorHelper) {
    if (textColor == null || textColor!.isEmpty) return Colors.white;
    return colorHelper.getColor(textColor) ?? Colors.white;
  }

  String getTitle(BuildContext context) {
    if (title == null) return '';
    if (title is MultilocaleText) return (title as MultilocaleText).get(context);
    if (title is String) return title as String;
    return title.toString();
  }

  String getCtaButtonText(BuildContext context) {
    if (ctaButtonText == null) return '';
    if (ctaButtonText is MultilocaleText) return (ctaButtonText as MultilocaleText).get(context);
    if (ctaButtonText is String) return ctaButtonText as String;
    return ctaButtonText.toString();
  }

  List<String> getBenefits(BuildContext context) {
    return benefits.map((e) {
      if (e is MultilocaleText) return e.get(context);
      if (e is String) return e;
      return e?.toString() ?? '';
    }).toList();
  }

  String getShareTitle(BuildContext context) {
    if (shareTitle == null) return '';
    if (shareTitle is MultilocaleText) return (shareTitle as MultilocaleText).get(context);
    if (shareTitle is String) return shareTitle as String;
    return shareTitle.toString();
  }

  String getShareDescription(BuildContext context) {
    if (shareDescription == null) return '';
    if (shareDescription is MultilocaleText) return (shareDescription as MultilocaleText).get(context);
    if (shareDescription is String) return shareDescription as String;
    return shareDescription.toString();
  }
}
