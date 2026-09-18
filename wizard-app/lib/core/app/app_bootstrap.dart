import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/profile_sync_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';

/// Startup, split into what the first real screen needs and what can follow it.
///
/// [run] is the only thing the UI waits for: Firebase, the dependency container and the
/// bundled Remote Config defaults (all local, no network). [warmUp] then starts the work that
/// used to sit on the critical path: the Remote Config fetch (up to 10 s) and profile sync.
/// Anonymous sign-in is started by `AuthBloc` for the same reason, so no screen waits on it.
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
  }
}
