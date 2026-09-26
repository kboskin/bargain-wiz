# Startup

`main()` paints the first frame and initializes behind it. Exactly one network call is
allowed on the launch path — the anonymous sign-in — and everything else waits for a later
frame.

```
runApp(BargainWizApp)            first frame: BootSplash (flat ColoredBox, static, no MaterialApp,
                                 no DI, no assets)
  └─ AppBootstrap.run()          starts only after that frame is rasterized
       ├─ FirebaseService.initialize()          ~1.4 s, platform thread
       ├─ di.init()                             SharedPreferences + registrations
       ├─ RemoteConfigService.loadDefaults()    bundled asset, no network
       └─ AuthService.ensureSignedIn()          the one awaited network call
  └─ AppBootstrap.warmUp()       background, never awaited
       ├─ RemoteConfigService.refresh()         fetch + activate → notifies listeners
       ├─ ProfileSyncService.start()
       ├─ PushTopicService.start()              one FCM topic per install
       └─ AnalyticsService.setUserId(uid)       the uid run() signed in
```

Rules that keep it fast:

- **Never `await` a network call before `runApp`.** The Remote Config fetch has a 10 s timeout
  and was measured at 3.8 s on a cold iOS simulator; it now runs in `warmUp` and the tree
  rebuilds when values activate (`RemoteConfigService` is a `ChangeNotifier`).
- **Anonymous sign-in is the one exception, and it blocks.** It happens behind the splash,
  after the first frame, and the app is not shown until it succeeds: every endpoint requires
  an ID token, so a launch without a uid can only produce 401s. On failure `run()` returns a
  message and `BootSplash` stays up with tap-to-retry (`ensureSignedIn(force: true)` skips
  the 5 s cooldown for it). `AuthBloc` still reads `currentUser` synchronously and keeps
  itself in sync through `AuthService.userChanges`; the home route decides from the
  onboarding flag in preferences.
- **Initialize after the frame is on screen.** `AppBootstrap.firstFrameRendered()` waits for a
  real `FrameTiming`, because native Firebase initialization occupies the platform thread and
  would otherwise delay the first paint.
- **The splash is static.** Firebase's native init blocks the platform thread for a moment
  right after the splash appears, so an animation there would visibly stall.
- **No app-wide `BackdropFilter`.** Blurring the gradient repainted the whole screen every
  frame for no visible difference and dominated the first build.

- **Config is parsed once, not per build.** `RemoteConfigService` memoises the parsed objects
  (`_memo`) and clears them when new values activate. The getters are called from `build`
  methods, including the root gradient, so decoding the same JSON every frame was pure waste.

- **The boot splash is one flat colour, not a `MaterialApp`.** Building a `MaterialApp` (theme,
  localizations, navigator) plus a gradient shader for the very first frame cost 1.2 s in debug;
  a `ColoredBox` matching the native launch background costs 0.3 s.

## Measured

Phase breakdown from Flutter itself (`flutter run --trace-startup`, debug build, Android
emulator, `build/start_up_info.json`):

| phase | before | after |
| --- | --- | --- |
| engine + Dart VM → framework init | 1.46s | 1.66s |
| `runApp` → first frame built (**our code**) | 1.21s | 0.30s |
| first frame built → rasterized (Impeller on GLES) | 1.37s | 1.47s |
| total to first frame rasterized | 4.04s | 3.43s |

Only the second row is ours; the others are the engine, the Dart VM and the emulator's GL
stack. `am start -W` on the same APK measures 0.9–1.5 s with an idle Mac and 5–6 s when the
Firebase emulators, Gradle and the IDE are running, so always note the host load with a number.

## Why `flutter run` feels slow, and what to do

The wait in the IDE is mostly not startup:

- `pub get`, then Gradle assembling the variant. The first build of a new flavour/build-type
  combination (for example `localDebug`) is a full one; later runs are incremental.
- Install, then Android verifying the dex of a fresh APK.
- `--start-paused`, which the IDE passes in debug: the Dart isolate waits for the debugger.
- `androidx.profileinstaller` writing the baseline profile at every first launch. It is now
  removed from debug builds in `android/app/src/debug/AndroidManifest.xml`; release keeps it.

Faster loop: hot restart (`R`) instead of re-running, keep the Firebase emulators off unless
you need them, and judge startup from a release or profile build on a real device.
