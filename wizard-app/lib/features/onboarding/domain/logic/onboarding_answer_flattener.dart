import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';

/// Turns the per-screen answer map (`screenIndex → value`) kept by the bloc into
/// flat [OnboardingAnswer]s keyed by `answer_key_name`.
///
/// Single-key screens store their value directly. Multi-key screens
/// (`select_group`) store a `Map<String, dynamic>` of `{answerKey: value}` which
/// is expanded into one answer per key, so other features can read e.g.
/// each of a `select_group`'s answers via `UserProfileService.answer(key)`.
class OnboardingAnswerFlattener {
  OnboardingAnswerFlattener._();

  static List<OnboardingAnswer> flatten(
    List<OnboardingModel> screens,
    Map<int, dynamic> answers,
  ) {
    final out = <OnboardingAnswer>[];
    final indices = answers.keys.toList()..sort();
    for (final index in indices) {
      if (index < 0 || index >= screens.length) continue;
      final value = answers[index];
      if (_isBlank(value)) continue;
      final screen = screens[index];
      final keys = screen.answerKeys;

      if (value is Map && (keys.length > 1 || screen is SelectGroupScreenModel)) {
        for (final entry in value.entries) {
          final key = entry.key.toString();
          if (keys.isNotEmpty && !keys.contains(key)) continue;
          if (_isBlank(entry.value)) continue;
          out.add(OnboardingAnswer(
            screenIndex: index,
            screenTitle: screen.titleForStorage,
            screenType: screen.type,
            answerKey: key,
            answer: entry.value,
            options: optionsFor(screen, key),
          ));
        }
        continue;
      }

      out.add(OnboardingAnswer(
        screenIndex: index,
        screenTitle: screen.titleForStorage,
        screenType: screen.type,
        answerKey: keys.isEmpty ? null : keys.first,
        answer: value,
        options: optionsFor(screen, keys.isEmpty ? null : keys.first),
      ));
    }
    return out;
  }

  /// Option ids the screen offers for [key]: select-type screens list their option values,
  /// sliders their stops; null for screens without options.
  static List<String>? optionsFor(OnboardingModel screen, String? key) {
    if (screen is SelectScreenModel) return [for (final o in screen.options) o.storedValue];
    if (screen is MultiSelectScreenModel) return [for (final o in screen.options) o.storedValue];
    if (screen is SelectGroupScreenModel) {
      for (final group in screen.groups) {
        if (group.answerKeyName == key) return [for (final o in group.options) o.storedValue];
      }
      return null;
    }
    if (screen is SliderScreenModel) return [for (final o in screen.options) _optionId(o.value)];
    if (screen is SliderLottieScreenModel) {
      final raw = screen.metadata?.options;
      if (raw is List) return [for (final o in raw) if (o is Map && o['value'] != null) _optionId(o['value'])];
    }
    return null;
  }

  /// Whole-number stops read as `550`, not `550.0`, so ids match the config as authored.
  static String _optionId(dynamic value) {
    if (value is num && value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// `answerKey → value` view of the in-flow answers (later screens win on duplicates).
  static Map<String, dynamic> byKey(
    List<OnboardingModel> screens,
    Map<int, dynamic> answers,
  ) {
    final out = <String, dynamic>{};
    for (final a in flatten(screens, answers)) {
      final k = a.answerKey;
      if (k != null && k.isNotEmpty) out[k] = a.answer;
    }
    return out;
  }

  /// The reverse of [byKey]: puts `answerKey → value` answers back on the screens that ask
  /// for them, in the per-screen shape the bloc keeps (a `select_group` gets a
  /// `{answerKey: value}` map of the groups answered). Keys no screen asks for are dropped, and
  /// so are picks a select-type screen no longer offers, which would otherwise enable
  /// Continue with nothing shown as selected.
  static Map<int, dynamic> byIndex(
    List<OnboardingModel> screens,
    Map<String, dynamic> answers,
  ) {
    final out = <int, dynamic>{};
    for (var i = 0; i < screens.length; i++) {
      final screen = screens[i];
      if (screen is SelectGroupScreenModel) {
        final group = <String, dynamic>{
          for (final key in screen.answerKeys)
            if (_offered(screen, key, answers[key]) case final value?) key: value,
        };
        if (group.isNotEmpty) out[i] = group;
        continue;
      }
      final keys = screen.answerKeys;
      if (keys.isEmpty) continue;
      final value = _offered(screen, keys.first, answers[keys.first]);
      if (value != null) out[i] = value;
    }
    return out;
  }

  /// [value] as far as [screen] still offers it for [key]: select-type screens keep only
  /// their current options, other screens take the value as it is; null when nothing is left.
  static dynamic _offered(OnboardingModel screen, String key, dynamic value) {
    if (_isBlank(value)) return null;
    final isPick = screen is SelectScreenModel || screen is MultiSelectScreenModel || screen is SelectGroupScreenModel;
    final options = isPick ? optionsFor(screen, key) : null;
    if (options == null) return value;
    if (value is List) {
      final kept = [for (final v in value) if (options.contains(v.toString())) v];
      return kept.isEmpty ? null : kept;
    }
    return options.contains(value.toString()) ? value : null;
  }

  /// `answerKey → value` for the answers picked from a configured option list (select,
  /// multi-select, select-group, both sliders). Answers the person typed — a referral code —
  /// are left out: the option ids are the config's words, a typed answer is the person's.
  static Map<String, dynamic> pickedOptions(
    List<OnboardingModel> screens,
    Map<int, dynamic> answers,
  ) =>
      {
        for (final a in flatten(screens, answers))
          if (a.answerKey != null && a.options != null) a.answerKey!: a.answer,
      };

  static bool _isBlank(dynamic v) =>
      v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty) || (v is Map && v.isEmpty);
}
