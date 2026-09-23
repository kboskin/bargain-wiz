import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/firebase_service.dart';
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
/// - Onboarding pushes the answers given so far each time a step is left, and the full set
///   when the funnel finishes ([pushOnboarding]).
/// - Later edits ask for a push as they are stored; [schedulePush] debounces them.
/// - Signing in pushes once more (the server folds the install's anonymous profile into
///   the account) and, on a device with no local answers, pulls the account's answers down
///   so the profile follows the user.
/// - Every push carries this install's FCM token (`app.fcm_token`); a token that arrives or
///   changes while the app runs is reported on its own ([_onFcmToken]).
/// - Every launch is reported once ([_reportOpened]) as `app.last_opened_at`.
///
/// Every push is a partial update: the server merges. A failure is retried once after
/// [retryDelay], and a failed retry is reported to Crashlytics; the UI never waits on this
/// service.
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
    final Stream<String> Function()? fcmTokens,
  })  : _profile = profile,
        _remote = remote,
        _auth = auth,
        _onboarding = onboarding,
        _logger = logger,
        _localeCode = localeCode ?? (() => PlatformDispatcher.instance.locale.languageCode),
        _fcmTokens = fcmTokens ?? FirebaseService.fcmTokens;

  final UserProfileService _profile;
  final ProfileRemoteDataSource _remote;
  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final AppLogger _logger;
  final Duration debounce;
  final Duration retryDelay;
  final String Function() _localeCode;
  final Stream<String> Function() _fcmTokens;

  /// The one `preferences` entry that is not an onboarding answer.
  static const String _localeKey = 'locale';

  Timer? _timer;
  StreamSubscription<Object?>? _authSub;
  StreamSubscription<String>? _fcmSub;
  bool _started = false;
  bool _hadAccount = false;

  /// The latest FCM token this install has been given; null until FCM hands one over.
  String? _fcmToken;

  void start() {
    if (_started) return;
    _started = true;
    _authSub = _auth.userChanges.listen((user) {
      final account = AuthService.isAccount(user);
      if (account && !_hadAccount) unawaited(onSignedIn());
      _hadAccount = account;
    });
    _fcmSub = _fcmTokens().listen(
      (final token) => unawaited(_onFcmToken(token)),
      onError: (final Object e) => _logger.w('FCM token unavailable: $e'),
    );
    unawaited(_reportOpened());
  }

  /// The app just started (this service starts once per launch, after the launch has signed
  /// in): sets `app.last_opened_at` to now, by the device clock. Sent whether or not
  /// onboarding has begun, so the first launch creates the profile. Not retried — the next
  /// launch reports again.
  Future<void> _reportOpened() async {
    try {
      await _remote.patch(
        ProfilePatchRequest(app: _app(lastOpenedAt: DateTime.now().toUtc().toIso8601String())),
      );
    } on Object catch (e) {
      _logger.w('Launch report failed: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    _fcmSub?.cancel();
  }

  /// A token FCM just handed over — at launch, or a rotated one. Every push carries the
  /// latest ([buildPatch]); this sends it on its own as well, so a profile that already exists
  /// learns it without waiting for the next edit. That is one small write per launch, which
  /// also tells the server the token is still in use. Before there is a profile there is
  /// nothing to report to: the onboarding pushes carry it.
  ///
  /// Not retried — the next launch or edit sends it again, and a retry here would replace a
  /// pending full push ([_push] owns the one timer).
  Future<void> _onFcmToken(final String token) async {
    if (token == _fcmToken) return;
    _fcmToken = token;
    await _profile.ensureLoaded();
    if (_profile.answers.isEmpty) return;
    try {
      await _remote.patch(ProfilePatchRequest(app: ProfileApp(fcmToken: token)));
    } on Object catch (e) {
      _logger.w('FCM token report failed: $e');
    }
  }

  /// Pushes the stored answers after [debounce] (a later call restarts the wait), so a run of
  /// edits travels once. [UserProfileService] calls this after every write.
  void schedulePush([Duration? delay]) {
    _timer?.cancel();
    _timer = Timer(delay ?? debounce, () => unawaited(pushNow()));
  }

  /// Pushes the in-flow answers (called by the repository's `uploadUserData`, before the
  /// answers are persisted locally): after every step, so a funnel that is never finished is
  /// recorded as far as it got, and once more when it finishes (`data.isCompleted`).
  Future<void> pushOnboarding(OnboardingDataEntity data) => _push(buildPatch(data, completed: data.isCompleted));

  /// Pushes the current local answers, if any.
  Future<void> pushNow() async {
    await _profile.ensureLoaded();
    final data = _profile.data;
    if (data == null || data.answers.isEmpty) return;
    await _push(buildPatch(data, completed: data.isCompleted));
  }

  /// A failure is retried once with the same patch — unless a later change schedules a push
  /// of its own first, which carries the full state anyway. A failed retry is reported to
  /// Crashlytics: it is the one point where the server is known to be missing what the
  /// device has, and until the next change it stays that way.
  Future<void> _push(ProfilePatchRequest patch, {bool retry = false}) async {
    try {
      await _remote.patch(patch);
    } on Object catch (e, st) {
      if (retry) {
        _logger.e('Profile sync failed after a retry', e, st);
        return;
      }
      _logger.w('Profile sync failed, retrying in ${retryDelay.inSeconds}s: $e');
      _timer?.cancel();
      _timer = Timer(retryDelay, () => unawaited(_push(patch, retry: true)));
    }
  }

  /// After sign-in: merge server-side, then hydrate a device that has no answers yet.
  Future<void> onSignedIn() async {
    await pushNow();
    try {
      await _profile.ensureLoaded();
      if (_profile.answers.isNotEmpty) return; // local answers already pushed and win
      final doc = await _remote.fetch();
      final answers = {...?doc?.preferences}..remove(_localeKey); // a device fact, not an answer
      if (answers.isEmpty) return;
      final entity = entityFromAnswers(answers, completed: doc!.onboardingStatus?.completedAt != null);
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

  /// The partial update for [data]: every answer the screens collected, keyed by the
  /// `answer_key_name` that *is* the backend field name, plus the device locale. Only
  /// answers the person actually gave are sent — a screen's default is for prompting, not
  /// something to record as a choice.
  ///
  /// `preferences` is the whole record: answers are not mirrored anywhere else, and a
  /// question whose screen is no longer configured keeps the answer it already has. The
  /// function types the fields it reads and stores the rest as sent.
  ProfilePatchRequest buildPatch(OnboardingDataEntity data, {required bool completed}) {
    final answers = <String, dynamic>{
      for (final a in data.answers)
        if (a.answerKey != null) a.answerKey!: a.answer,
    };
    final code = answers[ProfileFields.referralKey]?.toString().trim();
    return ProfilePatchRequest(
      // Everything answered, minus the keys onboarding locks: the referral code is not a
      // preference, it has a section of its own and the function keeps the first one it gets.
      preferences: {
        for (final entry in answers.entries)
          if (!ProfileFields.lockedKeys.contains(entry.key)) entry.key: entry.value,
        _localeKey: _localeCode(),
      },
      onboardingStatus: completed ? const ProfileOnboardingStatus(completed: true) : null,
      // Held back until the funnel is finished: the function keeps the first code it gets,
      // and until then the person can still go back and correct one. Sent on every push
      // after that — nothing edits it, so a retried first push still credits it.
      referral: !completed || code == null || code.isEmpty ? null : ProfileReferral(code: code),
      app: _app(),
    );
  }

  /// This install, as every push describes it.
  ProfileApp _app({String? lastOpenedAt}) => ProfileApp(
        platform: Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : Platform.operatingSystem),
        locale: _localeCode(),
        fcmToken: _fcmToken,
        lastOpenedAt: lastOpenedAt,
      );

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
