import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/icon_resolver.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

/// How a configured answer option is drawn: the colour and glyph the option itself declares,
/// plus the text colours that read on and beside it.
///
/// Nothing here knows what a tone, a push level or a marketplace is — it only resolves what
/// remote config sent with the option (`metadata.color` / `tint_color`, `icon`, `emoji`), so
/// the app has no catalogue of answer values to keep in step with the funnel.
class OptionStyle {
  const OptionStyle({
    required this.color,
    required this.textOnColor,
    required this.textColor,
    this.icon,
  });

  factory OptionStyle.of(ProfileOption? option, {Color fallback = WizColors.teal}) {
    final color = hexColor(option?.colorHex) ?? fallback;
    return OptionStyle(
      color: color,
      textOnColor: color.computeLuminance() > 0.5 ? WizColors.ink : Colors.white,
      textColor: readable(color),
      icon: iconOf(option),
    );
  }

  /// Fill colour: a selected chip, a meter segment, a tint.
  final Color color;

  /// Text that sits on [color].
  final Color textOnColor;

  /// [color] as text on a light surface — the pale tints in the templates are illegible raw.
  final Color textColor;

  /// The option's glyph, when it configures one.
  final IconData? icon;

  /// The glyph an option configures (`icon: {code, font}`), or null.
  static IconData? iconOf(ProfileOption? option) =>
      option?.iconRaw == null ? null : IconResolver.resolve(option!.iconRaw).icon;

  /// `#RRGGBB` or `#AARRGGBB` → colour; null for anything else.
  static Color? hexColor(String? value) {
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// Darkens [color] until it reads on white.
  static Color readable(Color color) {
    var hsl = HSLColor.fromColor(color);
    while (hsl.toColor().computeLuminance() > 0.35 && hsl.lightness > 0.05) {
      hsl = hsl.withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0));
    }
    return hsl.toColor();
  }
}
