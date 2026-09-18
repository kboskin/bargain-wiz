import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:json_annotation/json_annotation.dart';

part 'lines_that_land_response.g.dart';

/// Payload of `GET {api_url}/lines_that_land` (wizard-backend/functions); also the
/// on-device cache format. Every text is a [MultilocaleText]; the app picks the language.
/// See LINES_THAT_LAND.md.
@JsonSerializable(explicitToJson: true)
class LinesThatLandResponse {
  const LinesThatLandResponse({
    required this.categories,
    this.locales = const [],
    this.updatedAt,
    this.refreshIntervalHours = LinesThatLandResponse.defaultRefreshIntervalHours,
    this.source = 'unknown',
  });

  factory LinesThatLandResponse.fromJson(Map<String, dynamic> json) => _$LinesThatLandResponseFromJson(json);

  /// Cadence assumed when the payload does not declare one.
  static const int defaultRefreshIntervalHours = 24;

  @JsonKey(defaultValue: <LinesCategoryDto>[])
  final List<LinesCategoryDto> categories;

  /// Language codes present anywhere in the content.
  @JsonKey(defaultValue: <String>[])
  final List<String> locales;

  /// When the content last changed on the server (UTC).
  @JsonKey(name: 'updated_at', fromJson: _dateFromJson)
  final DateTime? updatedAt;

  /// How often the content is refreshed: on-device cache TTL and the Lines tab caption.
  @JsonKey(name: 'refresh_interval_hours', fromJson: _hoursFromJson)
  final num refreshIntervalHours;

  /// `remote_config` | `fallback`, as reported by the function.
  @JsonKey(defaultValue: 'unknown')
  final String source;

  Duration get refreshInterval => Duration(minutes: (refreshIntervalHours * 60).round());

  Map<String, dynamic> toJson() => _$LinesThatLandResponseToJson(this);

  static DateTime? _dateFromJson(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static num _hoursFromJson(Object? value) => value is num && value > 0 ? value : defaultRefreshIntervalHours;
}

/// One category: id plus multilocale name and lines.
@JsonSerializable(explicitToJson: true)
class LinesCategoryDto {
  const LinesCategoryDto({required this.id, required this.name, this.tips = const []});

  factory LinesCategoryDto.fromJson(Map<String, dynamic> json) => _$LinesCategoryDtoFromJson(json);

  @JsonKey(defaultValue: '')
  final String id;

  @JsonKey(fromJson: _textFromJson, toJson: _textToJson)
  final MultilocaleText name;

  @JsonKey(fromJson: _tipsFromJson, toJson: _tipsToJson)
  final List<MultilocaleText> tips;

  Map<String, dynamic> toJson() => _$LinesCategoryDtoToJson(this);

  static MultilocaleText _textFromJson(Object? value) => MultilocaleText.fromJson(value);

  static dynamic _textToJson(MultilocaleText text) => text.toJson();

  static List<MultilocaleText> _tipsFromJson(Object? value) =>
      value is List ? value.where((e) => e != null).map(MultilocaleText.fromJson).toList(growable: false) : const [];

  static List<dynamic> _tipsToJson(List<MultilocaleText> tips) => tips.map((t) => t.toJson()).toList();
}
