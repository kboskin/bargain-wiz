import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:appwizard/core/config/app_config.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

/// Keeps the server-side profile (`profile` Cloud Function → Firestore) in step with the
/// onboarding answers stored on the device. See PROFILE_SYNC.md.
///
/// - Onboarding completion pushes the full answer set right away ([pushOnboarding]).
/// - Later edits ask for a push as they are stored; [schedulePush] debounces them.
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
    required AuthService auth,
    required OnboardingRepository onboarding,
    required AppLogger logger,
    this.debounce = const Duration(milliseconds: 1500),
    this.retryDelay = const Duration(seconds: 30),
    String Function()? localeCode,
  })  : _profile = profile,
        _remote = remote,
        _auth = auth,
        _onboarding = onboarding,
        _logger = logger,
        _localeCode = localeCode ?? (() => PlatformDispatcher.instance.locale.languageCode);

  final UserProfileService _profile;
  final ProfileRemoteDataSource _remote;
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
    _authSub = _auth.userChanges.listen((user) {
      final account = AuthService.isAccount(user);
      if (account && !_hadAccount) unawaited(onSignedIn());
      _hadAccount = account;
    });
  }

  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
  }

  /// Pushes the stored answers after [debounce] (a later call restarts the wait), so a run of
  /// edits travels once. [UserProfileService] calls this after every write.
  void schedulePush([Duration? delay]) {
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
      schedulePush(retryDelay);
    }
  }

  /// After sign-in: merge server-side, then hydrate a device that has no answers yet.
  Future<void> onSignedIn() async {
    await pushNow();
    try {
      await _profile.ensureLoaded();
      if (_profile.answers.isNotEmpty) return; // local answers already pushed and win
      final doc = await _remote.fetch();
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

  /// The partial update for [data]: every answer the configured screens collected, keyed by
  /// the `answer_key_name` that *is* the backend field name (plus the device locale), then
  /// the raw answers and, at completion, the ordered trace of screens with the options they
  /// offered ([includeFlow]). Only answers the person actually gave are sent — a screen's
  /// default is for prompting, not something to record as a choice.
  ProfilePatchRequest buildPatch(OnboardingDataEntity data, {required bool completed, bool includeFlow = false}) {
    final answers = <String, dynamic>{
      for (final a in data.answers)
        if (a.answerKey != null) a.answerKey!: a.answer,
    };
    final code = answers[ProfileFields.referralKey]?.toString().trim();
    return ProfilePatchRequest(
      // Everything answered, minus the referral code: that has a section of its own.
      preferences: {
        for (final field in _profile.fields)
          if (field.key != ProfileFields.referralKey && answers[field.key] != null)
            field.key: answers[field.key],
        'locale': _localeCode(),
      },
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
      referral: code == null || code.isEmpty ? null : ProfileReferral(code: code),
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
}
