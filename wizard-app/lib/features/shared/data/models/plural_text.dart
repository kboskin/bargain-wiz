import 'package:flutter/widgets.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// Remote-configurable text with an optional plural form.
///
/// JSON shapes accepted:
/// 1. `"Read {n} screenshots"` (string)
/// 2. `{"en": "...", "es": "..."}` (multilocale)
/// 3. `{"one": {"en": "Read 1 screenshot"}, "other": {"en": "Read {n} screenshots"}}`
class PluralText {
  const PluralText._(this.one, this.other);

  final MultilocaleText? one;
  final MultilocaleText other;

  static PluralText? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Map && (json.containsKey('one') || json.containsKey('other'))) {
      final other = json['other'] ?? json['one'];
      return PluralText._(
        json['one'] != null ? MultilocaleText.fromJson(json['one']) : null,
        MultilocaleText.fromJson(other),
      );
    }
    return PluralText._(null, MultilocaleText.fromJson(json));
  }

  dynamic toJson() => one == null
      ? other.toJson()
      : {'one': one!.toJson(), 'other': other.toJson()};

  /// Resolves the plural form for [count] and replaces `{n}`.
  String get(BuildContext context, int count) {
    final source = (count == 1 && one != null) ? one! : other;
    return source.get(context).replaceAll('{n}', '$count');
  }
}
