import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/analytics_service.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/profile_sync_service.dart';
import 'package:appwizard/core/services/push_topic_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';

/// Startup, split into what the first real screen needs and what can follow it.
///
/// [run] is what the UI waits for: Firebase, the dependency container, the bundled Remote
/// Config defaults (all local) and **anonymous sign-in**, the one network call on the
/// critical path. It is there because a uid is not optional: every backend endpoint requires
/// an ID token and the app has no signed-out mode, so a launch without one can only produce
/// 401s. When it fails, [run] returns a message and `BargainWizApp` keeps the blocking
/// failure screen up with tap-to-retry instead of letting a crippled app through.
///
/// [warmUp] then starts what can lag behind the first screen: the Remote Config fetch (up to
/// 10 s), profile sync, the push topic and the analytics user id. The splash is already painted before any of this begins, so the
/// launch still shows something immediately (see STARTUP.md).
class AppBootstrap {
  const AppBootstrap._();

  /// Null when the app is ready to run, or a user-facing message when it cannot start.
  /// Waits for the splash to be on screen first (see [firstFrameRendered]).
  static Future<String?> run() async {
    await firstFrameRendered();
    try {
      await FirebaseService.initialize();
      await di.init();
      await di.sl<RemoteConfigService>().loadDefaults();
    } on Object catch (e, stackTrace) {
      debugPrint('[ERROR] Startup failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return 'Bargain Wiz could not start. Please try again.';
    }
    // Blocking on purpose: no uid, no usable app. `force` because the person is waiting.
    if (await di.sl<AuthService>().ensureSignedIn(force: true) == null) {
      debugPrint('[ERROR] Startup failed: no Firebase user');
      return 'Bargain Wiz could not connect. Check your internet connection.';
    }
    warmUp();
    return null;
  }

  /// Completes once a frame has actually been rasterized. Native Firebase initialization
  /// runs on the platform thread, so starting it any earlier holds back the first paint.
  /// Gives up after [timeout] (no frames are produced while the app is in the background).
  static Future<void> firstFrameRendered({Duration timeout = const Duration(seconds: 2)}) async {
    final binding = WidgetsBinding.instance;
    await binding.endOfFrame;
    final rendered = Completer<void>();
    void onTimings(List<FrameTiming> timings) {
      if (!rendered.isCompleted) rendered.complete();
    }

    binding.addTimingsCallback(onTimings);
    try {
      await rendered.future.timeout(timeout, onTimeout: () {});
    } finally {
      binding.removeTimingsCallback(onTimings);
    }
  }

  /// Background work; failures here degrade a feature, never the launch.
  static void warmUp() {
    unawaited(di.sl<RemoteConfigService>().refresh());
    di.sl<ProfileSyncService>().start();
    di.sl<PushTopicService>().start();
    // Attributes events to the uid [run] just signed in (never null here: the launch is
    // blocked until it exists). Signing into an account that already has a uid of its own
    // switches it, and that session keeps reporting under this one until the next launch.
    unawaited(di.sl<AnalyticsService>().setUserId(di.sl<AuthService>().currentUser?.uid));
  }
}
