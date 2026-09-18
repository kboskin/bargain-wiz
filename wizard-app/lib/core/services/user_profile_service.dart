import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Read/write access to the user's onboarding answers (vibe, push level,
/// marketplace, deals per month, deal size, hurdles, referral code) after
/// onboarding. Backed by [OnboardingRepository]; notifies listeners on change.
///
/// Answer keys (see remote `onboarding_screens[].answer_structure.answer_key_name`):
/// `negotiation_vibe`, `risk_tolerance`, `favorite_marketplace`, `deals_per_month`,
/// `average_deal_size`, `main_hurdle` (list), `referral_code`.
class UserProfileService extends ChangeNotifier {
  UserProfileService(this._repository, this._remoteConfig, this._logger);

  static const String keyVibe = 'negotiation_vibe';
  static const String keyPush = 'risk_tolerance';
  static const String keyMarketplace = 'favorite_marketplace';
  static const String keyDealsPerMonth = 'deals_per_month';
  static const String keyDealSize = 'average_deal_size';
  static const String keyHurdles = 'main_hurdle';
  static const String keyReferral = 'referral_code';

  final OnboardingRepository _repository;
  final RemoteConfigService _remoteConfig;
  final AppLogger _logger;

  OnboardingDataEntity? _data;
  bool _loaded = false;
  WizCatalog? _catalog;

  /// Catalog of vibes / push levels / deal sizes, with remote onboarding options applied.
  WizCatalog get catalog => _catalog ??= _buildCatalog();

  WizCatalog _buildCatalog() {
    try {
      final raw = _remoteConfig.getString('onboarding_screens');
      if (raw.isEmpty) return const WizCatalog();
      final json = jsonDecode(raw);
      if (json is! List) return const WizCatalog();
      final byKey = <String, List<Map<String, dynamic>>>{};
      for (final screen in json.whereType<Map>()) {
        final key = (screen['answer_structure'] as Map?)?['answer_key_name']?.toString();
        if (key == null) continue;
        final opts = screen['options'] ?? (screen['metadata'] as Map?)?['options'];
        if (opts is List) {
          byKey[key] = opts.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
      }
      return const WizCatalog().withRemoteOptions(byKey);
    } catch (e, st) {
      _logger.e('UserProfileService: catalog parse failed', e, st);
      return const WizCatalog();
    }
  }

  /// Loads answers once (cached). Call `refresh()` to reload from storage.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    final result = await _repository.getOnboardingData();
    _data = result.fold((_) => null, (d) => d);
    _loaded = true;
    _catalog = null;
    notifyListeners();
  }

  bool get isOnboardingCompleted => _data?.isCompleted ?? false;

  /// The stored onboarding entity (null before [ensureLoaded] or when nothing is saved).
  OnboardingDataEntity? get data => _data;

  /// Raw answer by key (null when unanswered). Synchronous; call [ensureLoaded] first.
  dynamic answer(String key) {
    final answers = _data?.answers;
    if (answers == null) return null;
    for (final a in answers.reversed) {
      if (a.answerKey == key) return a.answer;
    }
    return null;
  }

  Map<String, dynamic> get answers {
    final out = <String, dynamic>{};
    for (final a in _data?.answers ?? const <OnboardingAnswer>[]) {
      if (a.answerKey != null) out[a.answerKey!] = a.answer;
    }
    return out;
  }

  String get vibeId => answer(keyVibe)?.toString() ?? WizCatalog.defaultVibeId;
  VibeDef get vibe => catalog.vibeById(vibeId);

  int get pushValue {
    final v = answer(keyPush);
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? WizCatalog.defaultPushValue;
    return WizCatalog.defaultPushValue;
  }

  PushDef get push => catalog.pushForValue(pushValue);

  String? get marketplace => answer(keyMarketplace)?.toString();
  String? get dealsPerMonth => answer(keyDealsPerMonth)?.toString();

  int get dealSizeValue {
    final v = answer(keyDealSize);
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? WizCatalog.defaultDealSizeValue;
    return WizCatalog.defaultDealSizeValue;
  }

  DealSizeDef get dealSize => catalog.dealSizeForValue(dealSizeValue);

  List<String> get hurdles {
    final v = answer(keyHurdles);
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  String? get referralCode => answer(keyReferral)?.toString();

  int get monthlyLeak => catalog.monthlyLeak(dealSize: dealSizeValue, dealsPerMonth: dealsPerMonth);

  /// Adds or replaces the answer for [key] and persists it.
  Future<void> setAnswer(String key, dynamic value) async {
    await ensureLoaded();
    final current = _data ?? const OnboardingDataEntity(answers: [], isCompleted: false);
    final kept = current.answers.where((a) => a.answerKey != key).toList();
    final existing = current.answers.where((a) => a.answerKey == key).firstOrNull;
    kept.add(OnboardingAnswer(
      screenIndex: existing?.screenIndex ?? -1,
      screenTitle: existing?.screenTitle ?? key,
      screenType: existing?.screenType ?? OnboardingScreenType.select,
      answerKey: key,
      answer: value,
    ));
    final updated = current.copyWith(answers: kept);
    final result = await _repository.saveOnboardingData(updated);
    result.fold(
      (f) => _logger.w('UserProfileService.setAnswer($key) failed: ${f.message}'),
      (_) {
        _data = updated;
        notifyListeners();
      },
    );
  }

  Future<void> setVibe(String id) => setAnswer(keyVibe, id);
  Future<void> setPush(int value) => setAnswer(keyPush, value);
  Future<void> setMarketplace(String value) => setAnswer(keyMarketplace, value);
  Future<void> setDealsPerMonth(String value) => setAnswer(keyDealsPerMonth, value);
}
