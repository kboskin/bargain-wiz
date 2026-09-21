import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// A selectable value and everything the UI draws for it, straight from the option's remote
/// config. This is the only description of an answer value in the app: there is no Dart-side
/// catalogue of tones, push levels or deal sizes.
class ProfileOption {
  const ProfileOption(
    this.value,
    this.label, {
    this.iconRaw,
    this.colorHex,
    this.subtext,
    this.emoji,
    this.savingsLow,
    this.savingsHigh,
    this.shortLabel,
    this.prompt,
  });

  final String value;

  /// String or multilocale map; resolve with `TemplateText.textOf`.
  final dynamic label;

  /// Raw remote `icon` config (`{code, font}` map) when the option defines one.
  final dynamic iconRaw;

  /// Accent colour as configured (`metadata.color`, then `tint_color`); null when the option
  /// sets none and the caller should use its screen's highlight colour.
  final String? colorHex;

  /// One-line explanation under the label (String or multilocale map), when configured.
  final dynamic subtext;

  /// Decorative prefix for push stops (`🌊`, `🔥`, …), when configured.
  final String? emoji;

  /// What a deal of this size is worth negotiating, when the stop configures it.
  final int? savingsLow;
  final int? savingsHigh;

  /// A shorter label for chips and inline copy (`metadata.short`); [label] when unset.
  final dynamic shortLabel;

  /// This option's contribution to the system prompt: one English sentence telling the
  /// model what picking it means (`metadata.prompt` on an option, `prompt` on a slider
  /// stop). Forwarded with every AI request on the answer it describes; when it is null the
  /// answer reaches the model as silence and the backend logs it — there is no server-side
  /// sentence left to cover for it. Never shown in the UI and never localized — see
  /// AI_INTEGRATION.md.
  final String? prompt;

  /// "$lo–hi", or null when the stop configures no savings.
  String? get savingsRange =>
      savingsLow != null && savingsHigh != null ? '\$$savingsLow–$savingsHigh' : null;
}

/// One thing the buyer tapped, and the line remote config writes for it. One of these per
/// *pick*, so a multi-select becomes several answers sharing a [key].
///
/// The sentence rides on the answer it describes, which is what stops a per-request override
/// describing the wrong option: there is nowhere to put a line for something not being sent.
class ProfileAnswer {
  const ProfileAnswer(this.key, this.value, this.prompt);

  /// `answer_structure.answer_key_name` — whatever remote config named the question.
  final String key;

  /// The picked option's value: one option id, one slider stop, or a text answer.
  final dynamic value;

  /// This option's `metadata.prompt`, or null when nothing describes it — the backend then
  /// renders no line for it and logs the miss. Never localized, never shown in the UI.
  final String? prompt;

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        if (prompt != null) 'prompt': prompt,
      };
}

/// What one AI request carries about the buyer, out of a single traversal
/// ([UserProfileService.snapshot]) so the two views can never disagree.
class ProfileSnapshot {
  const ProfileSnapshot(this.fields, this.answers);

  /// `{answer key: value}` — exactly what [UserProfileService.payload] returns, and what
  /// `PATCH /profile` stores. A record wants a map; the prompt wants an order.
  final Map<String, dynamic> fields;

  /// The same answers as an ordered list, one entry per pick, each with its own sentence.
  /// Order is onboarding screen order, and it is the order the buyer block reads in.
  final List<ProfileAnswer> answers;
}

/// How an answer is edited: one chip, several chips, or a text field.
enum ProfileFieldKind { single, multi, text }

/// One onboarding answer as the Profile screen shows and edits it.
class ProfileField {
  const ProfileField({
    required this.key,
    required this.label,
    required this.kind,
    this.options = const [],
    this.numeric = false,
    this.minSelected = 0,
    this.placeholder,
    this.uppercase = false,
    this.defaultValue,
    this.template,
    this.conversationScoped = false,
  });

  /// `answer_structure.answer_key_name` — the key the answer is stored under.
  final String key;

  /// Row label (String or multilocale map); resolve with `TemplateText.textOf`.
  final dynamic label;

  final ProfileFieldKind kind;

  /// Choices for [ProfileFieldKind.single] / [ProfileFieldKind.multi].
  final List<ProfileOption> options;

  /// Option values are slider stops: store the answer as an `int`, not a `String`.
  final bool numeric;

  /// Minimum picks before a multi-select can be saved.
  final int minSelected;

  /// Hint for a text field (String or multilocale map).
  final dynamic placeholder;

  /// Text answers that are codes, stored upper-cased (referral codes).
  final bool uppercase;

  /// What this answer is worth before the screen is answered — the screen's configured
  /// `default_value` / `default_index`, else the first option. Null for text fields and for
  /// a screen that offers nothing. Used to fill the profile sent with an AI request.
  final dynamic defaultValue;

  /// The type of the screen this answer came from. The Profile screen picks its widget
  /// from it, so a question added remotely draws itself without the template having to name
  /// a control this build might not have.
  final OnboardingScreenType? template;

  /// `scope: "conversation"` on the screen (or the `select_group` group): this answer
  /// describes the *deal*, not the person, so a conversation may carry its own value and a
  /// chip in the deal header edits it. Everything else is global — see CONVERSATIONS.md.
  final bool conversationScoped;

  /// The option [value] belongs to, or null when the config no longer offers it.
  ProfileOption? optionFor(dynamic value) {
    final v = value?.toString();
    if (v == null || v.isEmpty) return null;
    return options.where((o) => o.value == v).firstOrNull;
  }
}

/// The editable onboarding answers, derived from the `onboarding_screens` templates so the
/// Profile screen offers exactly what onboarding asked — including screens added remotely
/// after this build shipped.
///
/// Every screen that writes an answer becomes a field: `select` / `select_group` groups and
/// the two slider templates are single-choice, `multi_select` is multi-choice, `referral_code`
/// is text. Screens that ask nothing (engagement, permission, paywall, warmup, …) are skipped,
/// as are the [skip] keys — the ones the Profile screen renders with a card of its own (vibe,
/// push) and the [lockedKeys] onboarding fills once (the referral code).
class ProfileFields {
  ProfileFields._();

  /// Optional short row label on a screen's metadata; the screen title is the question
  /// ("Where has your money slipped away?"), too long for a settings row.
  static const String labelKey = 'profile_label';

  static const String emptyValue = '—';

  /// The one answer key the client names, because the wire gives it a section of its own
  /// (`referral.code`) instead of carrying it with the preferences.
  static const String referralKey = 'referral_code';

  /// Answers onboarding collects once and nothing may re-set afterwards. A referral code
  /// credits whoever brought this person in, so re-entering it later would re-attribute an
  /// install that is already credited: the Profile screen leaves these rows out and they
  /// never travel in a patch's `preferences` (`ProfileSyncService.buildPatch`). The function
  /// keeps the first code it is given, so an older client cannot overwrite one either —
  /// see PROFILE_SYNC.md.
  static const Set<String> lockedKeys = {referralKey};

  /// `scope` marking an answer as the deal's rather than the person's.
  static const String conversationScope = 'conversation';

  /// The answers a conversation may override, in onboarding order — the ones the template
  /// marks `scope: "conversation"`. These are what the deal header offers as chips.
  static List<ProfileField> conversationScoped(List<ProfileField> fields) =>
      [for (final f in fields) if (f.conversationScoped) f];

  /// Fields for [screens], in onboarding order. Empty when nothing is configured: the keys
  /// are remote config's to name, so there is nothing to fall back to.
  static List<ProfileField> fromScreens(
    List<OnboardingModel> screens, {
    Set<String> skip = const {},
  }) =>
      [
        for (final screen in screens)
          for (final field in _fieldsOf(screen))
            if (!skip.contains(field.key)) field,
      ];

  /// What the settings row shows on the right: the picked option's label, `N selected` for
  /// several picks, the code for a text answer, [emptyValue] when unanswered.
  static String displayValue(
    ProfileField field,
    dynamic answer,
    String Function(dynamic) resolve,
  ) {
    switch (field.kind) {
      case ProfileFieldKind.text:
        final text = answer?.toString().trim() ?? '';
        return text.isEmpty ? emptyValue : text;
      case ProfileFieldKind.multi:
        final values = valuesOf(answer);
        if (values.isEmpty) return emptyValue;
        if (values.length == 1) return labelOf(field, values.first, resolve);
        return '${values.length} selected';
      case ProfileFieldKind.single:
        final value = answer?.toString() ?? '';
        return value.isEmpty ? emptyValue : labelOf(field, value, resolve);
    }
  }

  /// Label of the option [value] belongs to, or the raw value when it is not offered
  /// any more (a remote config change should never blank out an answer).
  static String labelOf(ProfileField field, String value, String Function(dynamic) resolve) {
    final match = field.options.where((o) => o.value == value).firstOrNull;
    if (match == null) return value;
    final label = resolve(match.label);
    return label.isEmpty ? value : label;
  }

  /// A multi-select answer as a list of values (a bare string counts as one pick).
  static List<String> valuesOf(dynamic answer) {
    if (answer is List) return [for (final v in answer) v.toString()];
    if (answer is String && answer.isNotEmpty) return [answer];
    return const [];
  }

  /// `option value → every label the config gives it`, in every locale, so a search box
  /// matches what the person saw whichever language they used.
  static Map<String, String> searchLabels(ProfileField? field) => {
        for (final option in field?.options ?? const <ProfileOption>[])
          option.value: [
            ...labelTexts(option.label),
            ...labelTexts(option.shortLabel),
          ].join(' '),
      };

  /// Every string inside a remote label (a String, a `{en: …, es: …}` map or a
  /// [MultilocaleText]).
  static Iterable<String> labelTexts(dynamic label) {
    if (label == null) return const [];
    if (label is String) return [label];
    if (label is MultilocaleText) return labelTexts(label.toJson());
    if (label is Map) return label.values.map((v) => v.toString());
    return [label.toString()];
  }

  /// What [setAnswer] should store for a picked option: slider stops are ints.
  static dynamic storedValue(ProfileField field, String value) =>
      field.numeric ? (int.tryParse(value) ?? value) : value;

  static List<ProfileField> _fieldsOf(OnboardingModel screen) {
    final key = screen.answerStructure?.answerKeyName ?? '';
    switch (screen) {
      case final SelectScreenModel s when key.isNotEmpty:
        return [
          ProfileField(
            key: key,
            label: _label(s),
            kind: ProfileFieldKind.single,
            options: _options(s.options),
            defaultValue: _firstValue(_options(s.options)),
            template: s.type,
            conversationScoped: _scoped(s.answerStructure?.scope),
          ),
        ];
      case final MultiSelectScreenModel s when key.isNotEmpty:
        return [
          ProfileField(
            key: key,
            label: _label(s),
            kind: ProfileFieldKind.multi,
            options: _options(s.options),
            minSelected: s.minSelected,
            template: s.type,
            conversationScoped: _scoped(s.answerStructure?.scope),
          ),
        ];
      case final SelectGroupScreenModel s:
        return [
          for (final group in s.groups)
            if (group.answerKeyName.isNotEmpty)
              ProfileField(
                key: group.answerKeyName,
                label: group.label,
                kind: ProfileFieldKind.single,
                options: _options(group.options),
                defaultValue: _firstValue(_options(group.options)),
                template: s.type,
                conversationScoped: _scoped(group.scope),
              ),
        ];
      case final SliderScreenModel s when key.isNotEmpty:
        return [
          ProfileField(
            key: key,
            label: _label(s),
            kind: ProfileFieldKind.single,
            numeric: true,
            options: [
              for (final o in s.sortedOptions)
                ProfileOption('${o.intValue}', o.label,
                    subtext: o.subtext,
                    savingsLow: o.savingsLow,
                    savingsHigh: o.savingsHigh,
                    prompt: o.prompt),
            ],
            defaultValue: s.sortedOptions.isEmpty ? null : s.sortedOptions[s.defaultIndex].intValue,
            template: s.type,
            conversationScoped: _scoped(s.answerStructure?.scope),
          ),
        ];
      case final SliderLottieScreenModel s when key.isNotEmpty:
        return [
          ProfileField(
            key: key,
            label: _label(s),
            kind: ProfileFieldKind.single,
            numeric: true,
            options: [
              for (final stop in s.stops)
                ProfileOption('${stop.value}', stop.label,
                    subtext: stop.subtext, emoji: stop.emoji, colorHex: stop.colorHex, prompt: stop.prompt),
            ],
            defaultValue: s.defaultValue,
            template: s.type,
            conversationScoped: _scoped(s.answerStructure?.scope),
          ),
        ];
      case final ReferralCodeScreenModel s when key.isNotEmpty:
        return [
          ProfileField(
            key: key,
            label: _label(s),
            kind: ProfileFieldKind.text,
            placeholder: s.placeholder,
            uppercase: true,
            template: s.type,
          ),
        ];
      default:
        return const [];
    }
  }

  static bool _scoped(String? scope) => scope?.toLowerCase() == conversationScope;

  static dynamic _label(OnboardingModel screen) =>
      screen.metadata?.raw?[labelKey] ?? screen.title;

  static List<ProfileOption> _options(List<OnboardingOption> options) => [
        for (final o in options)
          ProfileOption(
            o.storedValue,
            o.label,
            iconRaw: o.iconRaw,
            colorHex: o.colorHex,
            subtext: o.subtext,
            shortLabel: o.metadata?.raw?['short'],
            prompt: o.prompt,
          ),
      ];

  /// First option's value, the fallback default for a screen that configures none.
  static dynamic _firstValue(List<ProfileOption> options) =>
      options.isEmpty ? null : options.first.value;
}
