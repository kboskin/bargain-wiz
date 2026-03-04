import 'package:flutter/material.dart';
import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:json_annotation/json_annotation.dart';

part 'share_config.g.dart';

/// Remote config for share content (key: [share_config]).
/// Used when the user taps Share to generate a Firebase link / share message.
@JsonSerializable()
class ShareConfig {
  ShareConfig({
    this.title,
    this.description,
    this.imageUrl,
    this.linkUrl,
  });

  /// Share title (localized or plain string).
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic title;

  /// Share description (localized or plain string).
  @JsonKey(fromJson: _multilocaleFromJson)
  final dynamic description;

  /// Image URL for link preview (e.g. OG image).
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  /// Firebase / app link URL to share.
  @JsonKey(name: 'link_url')
  final String? linkUrl;

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  String getTitle(BuildContext context) {
    if (title == null) return '';
    if (title is MultilocaleText) return (title as MultilocaleText).get(context);
    if (title is String) return title;
    return title.toString();
  }

  String getDescription(BuildContext context) {
    if (description == null) return '';
    if (description is MultilocaleText) return (description as MultilocaleText).get(context);
    if (description is String) return description;
    return description.toString();
  }

  factory ShareConfig.fromJson(Map<String, dynamic> json) =>
      _$ShareConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ShareConfigToJson(this);

  /// Default config when Remote Config is unavailable or not set.
  static ShareConfig get defaultConfig => ShareConfig(
        title: MultilocaleText.fromJson('Bargain Wiz'),
        description: MultilocaleText.fromJson(
          'Get the best deals. Never overpay again.',
        ),
        imageUrl: 'https://example.com/bargain-wiz-og.png',
        linkUrl: 'https://bargainwiz.page.link/app',
      );
}
