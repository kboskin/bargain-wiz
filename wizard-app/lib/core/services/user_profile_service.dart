import 'package:flutter/foundation.dart';

import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_answer_flattener.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

/// The user's onboarding answers: local storage is the source of truth, the backend gets a
/// copy of every change (PROFILE_SYNC.md).
///
/// Deliberately dumb — it knows no answer. Remote Config names everything: a screen's
/// `answer_structure.answer_key_name` is both the key the answer is stored under and the field
/// it is sent as, so wiring a new question to the backend is a config edit, not a release.
/// Read answers by key ([answer], [answers], [valueOf], [payload]) or as the configured
/// fields behind them ([fields], [fieldFor], [optionFor]); write with [setAnswer] /
/// [setAnswers]: they persist locally first, then hand the new state to the backend.
///
/// Notifies listeners after every load and every write.
class UserProfileService extends ChangeNotifier {
  /// [pushToBackend] sends the stored answers to the `profile` function; resolved lazily by
  /// the DI container to `ProfileSyncService.schedulePush` (debounced and retried there), so
  /// this service never talks to the network itself.
  UserProfileService(
    this._repository,
    this._remoteConfig,
    this._logger, {
    void Function()? pushToBackend,
  }) : _pushToBackend = pushToBackend;

  final OnboardingRepository _repository;
  final RemoteConfigService _remoteConfig;
  final AppLogger _logger;
  final void Function()? _pushToBackend;

  OnboardingDataEntity? _data;
  bool _loaded = false;

  /// Loads answers once (cached). Call [refresh] to reload from storage.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    final result = await _repository.getOnboardingData();
    _data = result.fold((_) => null, (d) => d);
    _loaded = true;
    notifyListeners();
  }

  /// The stored onboarding entity (null before [ensureLoaded] or when nothing is saved).
  OnboardingDataEntity? get data => _data;

  bool get isOnboardingCompleted => _data?.isCompleted ?? false;

  /// Every answer key the configured onboarding asks for, in screen order.
  List<String> get answerKeys => [
        for (final screen in _remoteConfig.getOnboardingScreens()) ...screen.answerKeys,
      ];

  /// Stored answers by key; a later answer for the same key wins.
  Map<String, dynamic> get answers {
    final out = <String, dynamic>{};
    for (final a in _data?.answers ?? const <OnboardingAnswer>[]) {
      if (a.answerKey != null) out[a.answerKey!] = a.answer;
    }
    return out;
  }

  /// Raw answer by key (null when unanswered). Synchronous; call [ensureLoaded] first.
  dynamic answer(String key) {
    final stored = _data?.answers;
    if (stored == null) return null;
    for (final a in stored.reversed) {
      if (a.answerKey == key) return a.answer;
    }
    return null;
  }

  /// Every field the configured onboarding fills — what the functions receive. The answer
  /// key *is* the field name (`vibe`, `push`, `marketplace`, …), so there is no mapping: a
  /// screen is wired to the backend by naming its `answer_key_name` after the field.
  ///
  /// Unanswered keys fall back to the screen's configured default, so a request made before
  /// onboarding finishes still carries a complete profile. [overrides] wins over the stored
  /// answer, [except] drops keys the caller sends elsewhere.
  Map<String, dynamic> payload({
    Map<String, dynamic> overrides = const {},
    Set<String> except = const {},
  }) =>
      snapshot(overrides: overrides, except: except).fields;

  /// [payload]'s answers as the AI functions take them: an ordered list, one entry per
  /// pick, each carrying the `metadata.prompt` sentence remote config writes for that
  /// option (AI_INTEGRATION.md). Values and sentences are resolved in the same pass, so an
  /// [overrides] entry always describes the option actually being sent, not the stored one.
  ///
  /// The order is screen order, and it is the order the buyer block reads in. An option
  /// remote config no longer offers, or never described, carries no sentence: the backend
  /// renders no line for it and logs the miss.
  ProfileSnapshot snapshot({
    Map<String, dynamic> overrides = const {},
    Set<String> except = const {},
  }) {
    final stored = answers;
    final out = <String, dynamic>{};
    final list = <ProfileAnswer>[];
    for (final field in fields) {
      if (except.contains(field.key)) continue;
      final dynamic value =
          overrides.containsKey(field.key) ? overrides[field.key] : (stored[field.key] ?? field.defaultValue);
      if (value == null) continue;
      out[field.key] = value;
      for (final id in _optionIds(value)) {
        list.add(ProfileAnswer(field.key, _leafOf(value, id), field.optionFor(id)?.prompt));
      }
    }
    for (final entry in overrides.entries) {
      if (!except.contains(entry.key) && !out.containsKey(entry.key)) {
        out[entry.key] = entry.value;
        for (final id in _optionIds(entry.value)) {
          list.add(ProfileAnswer(entry.key, _leafOf(entry.value, id), null));
        }
      }
    }
    return ProfileSnapshot(out, list);
  }

  /// The option ids one answer stands for: every pick of a multi-select, otherwise the one
  /// value. Slider stops stringify to the ids [ProfileFields] built them with (`60`, `550`).
  static Iterable<String> _optionIds(dynamic value) =>
      value is List ? value.map((dynamic v) => v.toString()) : [value.toString()];

  /// What one pick is worth on the wire: the element for a multi-select, the value itself
  /// otherwise, so a slider stop stays the number it was stored as.
  static dynamic _leafOf(dynamic value, String id) => value is List ? id : value;

  /// The configured answers as fields, in screen order (memoised on [RemoteConfigService]).
  List<ProfileField> get fields => _remoteConfig.getProfileFields();

  /// The field that writes [key], or null when no configured screen does.
  ProfileField? fieldFor(String key) => fields.where((f) => f.key == key).firstOrNull;

  /// The stored answer for [key], or the screen's configured default when unanswered.
  dynamic valueOf(String key) => answer(key) ?? fieldFor(key)?.defaultValue;

  /// The option behind [key] — label, colour, icon, subtext, emoji — or null when the answer
  /// is unset or the config no longer offers it.
  ProfileOption? optionFor(String key) => fieldFor(key)?.optionFor(valueOf(key));

  /// Stores [value] under [key] locally, then sends the answers to the backend.
  Future<void> setAnswer(String key, dynamic value) => setAnswers({key: value});

  /// Stores several answers in one write (one save, one push).
  Future<void> setAnswers(Map<String, dynamic> values) async {
    if (values.isEmpty) return;
    await ensureLoaded();
    final current = _data ?? const OnboardingDataEntity(answers: [], isCompleted: false);
    final kept = current.answers.where((a) => !values.containsKey(a.answerKey)).toList();
    for (final entry in values.entries) {
      kept.add(_answerFor(entry.key, entry.value, current));
    }
    final updated = current.copyWith(answers: kept);
    final result = await _repository.saveOnboardingData(updated);
    result.fold(
      (f) => _logger.w('UserProfileService.setAnswers(${values.keys.join(', ')}) failed: ${f.message}'),
      (_) {
        _data = updated;
        notifyListeners();
        _pushToBackend?.call();
      },
    );
  }

  /// A stored answer keeps the trace of the screen that asks for [key] — the screen it came
  /// from when remote config still has it, else whatever the previous answer recorded.
  OnboardingAnswer _answerFor(String key, dynamic value, OnboardingDataEntity current) {
    final existing = current.answers.where((a) => a.answerKey == key).firstOrNull;
    final screens = _remoteConfig.getOnboardingScreens();
    final index = screens.indexWhere((s) => s.answerKeys.contains(key));
    final OnboardingModel? screen = index < 0 ? null : screens[index];
    return OnboardingAnswer(
      screenIndex: screen == null ? existing?.screenIndex ?? -1 : index,
      screenTitle: screen?.titleForStorage ?? existing?.screenTitle ?? key,
      screenType: screen?.type ?? existing?.screenType ?? OnboardingScreenType.select,
      answerKey: key,
      answer: value,
      options: screen == null
          ? existing?.options
          : OnboardingAnswerFlattener.optionsFor(screen, key) ?? existing?.options,
    );
  }
}
