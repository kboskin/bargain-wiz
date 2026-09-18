import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:appwizard/core/config/app_config.dart';
import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/installation_id_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';

/// Keeps the server-side profile (`profile` Cloud Function → Firestore) in step with the
/// onboarding answers stored on the device. See PROFILE_SYNC.md.
///
/// - Onboarding completion pushes the full answer set right away ([pushOnboarding]).
/// - Later edits (Profile screen) are pushed debounced whenever [UserProfileService] changes.
/// - Signing in pushes once more (the server folds the install's anonymous profile into
///   the account) and, on a device with no local answers, pulls the account's answers down
///   so the profile follows the user.
///
/// Every push is a partial update: the server merges. Failures are logged and retried once
/// after [retryDelay]; the UI never waits on this service.
class ProfileSyncService {
  ProfileSyncService({
    required UserProfileService profile,
    required ProfileRemoteDataSource remote,
    required InstallationIdService installation,
    required AuthService auth,
    required OnboardingRepository onboarding,
    required AppLogger logger,
    this.debounce = const Duration(milliseconds: 1500),
    this.retryDelay = const Duration(seconds: 30),
    String Function()? localeCode,
  })  : _profile = profile,
        _remote = remote,
        _installation = installation,
        _auth = auth,
        _onboarding = onboarding,
        _logger = logger,
        _localeCode = localeCode ?? (() => PlatformDispatcher.instance.locale.languageCode);

  final UserProfileService _profile;
  final ProfileRemoteDataSource _remote;
  final InstallationIdService _installation;
  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final AppLogger _logger;
  final Duration debounce;
  final Duration retryDelay;
  final String Function() _localeCode;

  Timer? _timer;
  StreamSubscription<Object?>? _authSub;
  bool _started = false;
  bool _hadAccount = false;

  void start() {
    if (_started) return;
    _started = true;
    _profile.addListener(_schedule);
    _authSub = _auth.userChanges.listen((user) {
      final account = AuthService.isAccount(user);
      if (account && !_hadAccount) unawaited(onSignedIn());
      _hadAccount = account;
    });
  }

  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    if (_started) _profile.removeListener(_schedule);
  }

  void _schedule([Duration? delay]) {
    _timer?.cancel();
    _timer = Timer(delay ?? debounce, () => unawaited(pushNow()));
  }

  /// Onboarding just finished: push the completed answers with the screen trace (called by
  /// the repository's `uploadUserData`, before the answers are persisted locally).
  Future<void> pushOnboarding(OnboardingDataEntity data) =>
      _push(buildPatch(data, completed: true, includeFlow: true));

  /// Pushes the current local answers, if any.
  Future<void> pushNow() async {
    await _profile.ensureLoaded();
    final data = _profile.data;
    if (data == null || data.answers.isEmpty) return;
    await _push(buildPatch(data, completed: data.isCompleted));
  }

  Future<void> _push(ProfilePatchRequest patch) async {
    try {
      await _remote.patch(patch);
    } on Object catch (e) {
      _logger.w('Profile sync failed, retrying in ${retryDelay.inSeconds}s: $e');
      _schedule(retryDelay);
    }
  }

  /// After sign-in: merge server-side, then hydrate a device that has no answers yet.
  Future<void> onSignedIn() async {
    await pushNow();
    try {
      await _profile.ensureLoaded();
      if (_profile.answers.isNotEmpty) return; // local answers already pushed and win
      final doc = await _remote.fetch(installationId: _installation.id);
      final answers = doc?.onboarding?.answers;
      if (answers == null || answers.isEmpty) return;
      final entity = entityFromAnswers(answers, completed: doc!.onboarding!.completedAt != null);
      final saved = await _onboarding.saveOnboardingData(entity);
      await saved.fold(
        (f) async => _logger.w('Profile hydrate: could not save answers: ${f.message}'),
        (_) async {
          await _profile.refresh();
          _logger.i('Profile hydrated from the account (${answers.length} answers)');
        },
      );
    } on Object catch (e, st) {
      _logger.e('Profile hydrate failed', e, st);
    }
  }

  /// The partial update for [data]: typed preferences (same derivation rules as
  /// [UserProfileService]), the raw answers and, at completion, the ordered trace of
  /// screens with the options they offered ([includeFlow]).
  ProfilePatchRequest buildPatch(OnboardingDataEntity data, {required bool completed, bool includeFlow = false}) {
    final answers = <String, dynamic>{
      for (final a in data.answers)
        if (a.answerKey != null) a.answerKey!: a.answer,
    };
    final referral = answers[UserProfileService.keyReferral]?.toString();
    final marketplace = answers[UserProfileService.keyMarketplace]?.toString();
    final dealsPerMonth = answers[UserProfileService.keyDealsPerMonth]?.toString();
    final hurdlesRaw = answers[UserProfileService.keyHurdles];
    final hurdles = hurdlesRaw is List
        ? [for (final h in hurdlesRaw) h.toString()]
        : (hurdlesRaw is String && hurdlesRaw.isNotEmpty ? [hurdlesRaw] : const <String>[]);
    return ProfilePatchRequest(
      installationId: _installation.id,
      preferences: ProfilePreferences(
        vibe: answers[UserProfileService.keyVibe]?.toString() ?? WizCatalog.defaultVibeId,
        push: _intOf(answers[UserProfileService.keyPush], WizCatalog.defaultPushValue),
        marketplace: (marketplace?.isEmpty ?? true) ? null : marketplace,
        dealsPerMonth: (dealsPerMonth?.isEmpty ?? true) ? null : dealsPerMonth,
        dealSize: _intOf(answers[UserProfileService.keyDealSize], WizCatalog.defaultDealSizeValue),
        locale: _localeCode(),
        hurdles: hurdles.isEmpty ? null : hurdles,
      ),
      onboarding: ProfileOnboarding(
        answers: answers,
        completed: completed ? true : null,
        flow: includeFlow
            ? [
                for (final a in data.answers)
                  if (a.answerKey != null)
                    ProfileFlowStep(
                      index: a.screenIndex,
                      key: a.answerKey,
                      type: a.screenType.name,
                      title: a.screenTitle,
                      options: a.options,
                    ),
              ]
            : null,
      ),
      referral: referral == null || referral.isEmpty ? null : ProfileReferral(code: referral),
      app: ProfileApp(
        platform: Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : Platform.operatingSystem),
        flavor: AppConfig.flavor,
        locale: _localeCode(),
      ),
    );
  }

  /// Local entity rebuilt from server answers (screen metadata is not needed to use them).
  static OnboardingDataEntity entityFromAnswers(Map<String, dynamic> answers, {required bool completed}) =>
      OnboardingDataEntity(
        answers: [
          for (final e in answers.entries)
            OnboardingAnswer(
              screenIndex: -1,
              screenTitle: e.key,
              screenType: OnboardingScreenType.select,
              answerKey: e.key,
              answer: e.value,
            ),
        ],
        isCompleted: completed,
      );

  static int _intOf(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
