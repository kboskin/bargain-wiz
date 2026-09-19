import 'dart:ui' show Color;

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// One summary chip for the warmup screen.
class SummaryChipSpec {
  const SummaryChipSpec({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;
}

/// Read-only view of the answers collected *so far* in the onboarding flow (nothing is
/// persisted until the end), resolved against the configured [ProfileField]s.
///
/// Fills the placeholders the warmup and data-upload templates use. Every answer key is a
/// placeholder of its own — `{vibe}`, `{push}`, `{marketplace}`, `{deal_size}` — resolved to
/// the picked option's short label. The derived ones (`{push_emoji}`, `{savings}`,
/// `{leak_count}`, `{monthly_leak}`) are read off the options' *attributes*, so no answer key
/// is spelled out here and a renamed screen keeps working.
class OnboardingProfileSnapshot {
  OnboardingProfileSnapshot({
    required Map<String, dynamic> answers,
    this.fields = const [],
    this.languageCode = 'en',
    Map<String, int> dealsMultiplier = const {},
  })  : _answers = answers,
        _dealsMultiplier = dealsMultiplier;

  final Map<String, dynamic> _answers;

  /// The configured answers, as `RemoteConfigService.getProfileFields()` builds them.
  final List<ProfileField> fields;
  final String languageCode;

  /// `{deals_per_month answer: months multiplier}` from the warmup screen's metadata.
  final Map<String, int> _dealsMultiplier;

  dynamic answer(String key) => _answers[key];

  ProfileField? fieldFor(String key) => fields.where((f) => f.key == key).firstOrNull;

  /// The option picked for [key], or null while its screen is unanswered. Unlike
  /// `UserProfileService`, an unanswered screen does *not* fall back to its default: this
  /// describes what the person has chosen so far.
  ProfileOption? optionFor(String key) => fieldFor(key)?.optionFor(_answers[key]);

  /// The picked option's short label ("Friendly"), or '' while unanswered.
  String labelOf(String key) {
    final option = optionFor(key);
    if (option == null) return '';
    return localize(option.shortLabel ?? option.label, languageCode);
  }

  /// The first answered option with an [attribute] — how the derived placeholders find the
  /// push emoji or the savings range without knowing which screen carries them.
  T? _attribute<T>(T? Function(ProfileOption) attribute) {
    for (final field in fields) {
      final option = optionFor(field.key);
      final value = option == null ? null : attribute(option);
      if (value != null) return value;
    }
    return null;
  }

  /// Values of the first multi-select answer — the "money leaks" count.
  List<String> get multiValues {
    for (final field in fields) {
      if (field.kind != ProfileFieldKind.multi) continue;
      return ProfileFields.valuesOf(_answers[field.key]);
    }
    return const [];
  }

  /// `savings_high(deal size) × multiplier(deals per month)`, 0 until both are answered.
  int get monthlyLeak {
    final savings = _attribute<int>((o) => o.savingsHigh);
    if (savings == null || _dealsMultiplier.isEmpty) return 0;
    for (final entry in _dealsMultiplier.entries) {
      if (_answers.values.any((v) => v?.toString() == entry.key)) return savings * entry.value;
    }
    return 0;
  }

  /// "$550" / "$7,200".
  String get monthlyLeakText => formatMoney(monthlyLeak);

  /// Placeholders for body copy: labels lowercased so they read inline
  /// ("A friendly wizard with a balanced push …").
  Map<String, String?> get bodyPlaceholders => {
        for (final entry in _basePlaceholders.entries)
          entry.key: fieldFor(entry.key) == null ? entry.value : entry.value?.toLowerCase(),
      };

  /// Placeholders for chips / status lines: labels keep their casing
  /// ("Friendly wizard", "⚖️ Balanced").
  Map<String, String?> get chipPlaceholders => _basePlaceholders;

  Map<String, String?> get _basePlaceholders => {
        for (final field in fields) field.key: labelOf(field.key),
        'push_emoji': _attribute<String>((o) => o.emoji) ?? '',
        'savings': _attribute<String>((o) => o.savingsRange) ?? '',
        'leak_count': multiValues.isEmpty ? '' : '${multiValues.length}',
        'monthly_leak': monthlyLeakText,
      };

  /// Fills [template] with the body placeholders.
  String fillBody(String template) => TemplateText.fill(template, bodyPlaceholders);

  /// Fills [template] with the chip placeholders and tidies empty counts
  /// ("{leak_count} money leaks → plugged" with no picks → "Money leaks → plugged").
  String fillChip(String template) {
    var s = TemplateText.fill(template, chipPlaceholders).replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (s.isNotEmpty && multiValues.isEmpty && template.contains('{leak_count}')) {
      s = s[0].toUpperCase() + s.substring(1);
    }
    return s;
  }

  /// Chips styled by the option they describe: its configured colour, or white when it sets
  /// none. The label colour follows the background's brightness.
  List<SummaryChipSpec> chips(List<String> templates) => [
        for (final t in templates)
          if (fillChip(t).isNotEmpty)
            SummaryChipSpec(
              label: fillChip(t),
              background: _chipBackground(t),
              foreground: _chipForeground(_chipBackground(t)),
            ),
      ];

  static const Color _chipDefault = Color(0xD9FFFFFF); // white 85%

  Color _chipBackground(String template) {
    for (final field in fields) {
      if (!template.contains('{${field.key}}')) continue;
      final color = _hexColor(optionFor(field.key)?.colorHex);
      if (color != null) return color;
    }
    return _chipDefault;
  }

  /// `#RRGGBB` / `#AARRGGBB` as configured. Parsed here rather than through the presentation
  /// helper so this stays a domain type.
  static Color? _hexColor(String? hex) {
    final raw = hex?.replaceAll('#', '').trim();
    if (raw == null || (raw.length != 6 && raw.length != 8)) return null;
    final value = int.tryParse(raw.length == 6 ? 'ff$raw' : raw, radix: 16);
    return value == null ? null : Color(value);
  }

  /// White on a dark chip, ink on a light one — so a colour added remotely stays readable.
  static Color _chipForeground(Color background) =>
      background.computeLuminance() > 0.5 ? WizColors.ink : const Color(0xFFFFFFFF);

  /// "$" + thousands-separated integer: 550 → "$550", 7200 → "$7,200".
  static String formatMoney(int amount) => '\$${formatThousands(amount)}';

  static String formatThousands(int n) {
    final negative = n < 0;
    final digits = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return '${negative ? '-' : ''}$buf';
  }

  /// Locale-resolves a remote value (String, `{en:..}` map or [MultilocaleText]) without a BuildContext.
  static String localize(dynamic source, String languageCode) {
    if (source == null) return '';
    if (source is MultilocaleText) return localize(source.toJson(), languageCode);
    if (source is String) return source;
    if (source is Map) {
      final v = source[languageCode] ?? source['en'] ?? (source.values.isEmpty ? null : source.values.first);
      return v?.toString() ?? '';
    }
    return source.toString();
  }
}
