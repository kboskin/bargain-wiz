# wizard-app — agent guide

Flutter client for Bargain Wiz (iOS + Android). Repo-wide conventions: `../AGENTS.md`.

## Tech stack

| Concern | What we use |
|---|---|
| Framework | Flutter **3.44.6** / Dart **3.12.2** (`environment: sdk ^3.9.2`), Material 3 |
| State | `flutter_bloc` 8 — Cubits for feature state, `Bloc` where events are worth naming; `equatable` on every state |
| DI | `get_it` — one container (`core/di/injection_container.dart`); newer slices register in their own `di.dart`, older ones inline there |
| Errors | `dartz` `Either<Failure, T>` out of repositories; failures in `core/error/` |
| Routing | `go_router` 14 (`core/routing/app_router.dart`, route ids in `app_routes.dart`) |
| Network | `dio` behind `CloudFunctionsClient` — JSON over HTTPS to the Cloud Functions, base URL from the Remote Config `api_url` (the `local` flavor uses the Functions emulator instead; the *bundled* default is that emulator URL too, so dev and prod depend on the published value), Firebase ID token attached per call, POST timeout 70 s |
| Firebase | `firebase_core`, `firebase_auth` (anonymous → Google/Apple link), `cloud_firestore` (conversation listener, read-only), `firebase_storage`, `firebase_remote_config`, `firebase_analytics`, `firebase_crashlytics`, `firebase_messaging` |
| Serialization | `json_annotation` + `json_serializable` (`build_runner`); wire models are `*.g.dart`, never hand-written |
| i18n | `flutter_localizations` + `intl`, ARB in `lib/l10n/` (`app_en.arb`, `app_es.arb`), generated via `l10n.yaml` + `generate: true` |
| Design system | Tokens in `core/theme/wiz_theme.dart` (`WizColors`/`WizType`/`WizMotion`), shared widgets in `core/widgets/wiz/`; bundled Outfit + Figtree TTFs; `lottie`, `flutter_svg`, `font_awesome_flutter`, `flutter_html` for rich copy |
| Device / media | `image_picker`, `permission_handler`, `flutter_image_compress`, `speech_to_text`, `video_player`, `share_plus`, `url_launcher`, `connectivity_plus`, `shared_preferences` |
| Monetization | `in_app_purchase` behind `PaymentProviderType`, chosen by Remote Config `paywall_config.payment_provider` (`iap` default, `stripe`), `in_app_review` for Rate Us |
| Tests | `flutter_test` + hand-written fakes (a little `mockito`); 56 test files, ~470 tests, no emulator needed |
| Lints | `flutter_lints` 5 plus the extra rules in `analysis_options.yaml`; generated files excluded |

Platforms: Android `com.bargain.wiz` (Kotlin Gradle DSL, JVM 11, flavor dimension
`environment`), iOS deployment target **15.0**. No `.fvmrc` — `fvm flutter` resolves to the
global `stable` (3.44.6 today), so check `fvm list` if versions look off.

Every screen is a Remote Config template with defaults bundled in
`assets/config/remote_config_defaults.json`; changing UI copy or layout usually means editing
that JSON, not Dart. The bundled value is only the fallback: a published key replaces its whole
JSON value, so a change must also be published — in every A/B arm that sets the key. Editing a
template string safely (decode, change, re-encode compact): the `onboarding-screen` skill.

## Toolchain

**Always `fvm flutter`, never bare `flutter`** — the toolchain is Flutter 3.44.6 / Dart 3.12.2.

```bash
fvm flutter pub get
fvm flutter test                       # ~470 tests, runs in ~10s
fvm flutter analyze lib test
fvm flutter run --flavor local --dart-define=FLAVOR=local -t lib/main.dart   # both switches, see Flavors
fvm dart run build_runner build --delete-conflicting-outputs   # *.g.dart after model changes
```

`flutter analyze` reports about 3,150 pre-existing infos (two thirds `prefer_final_parameters`)
and no errors or warnings. **Filter, don't fix them all:**

```bash
fvm flutter analyze lib test 2>&1 | grep -E "error •|warning •"
```

Only clean up lints in code you touched.

## Flavors

Three: `dev`, `prod`, `local` (`lib/core/config/app_config.dart`). **Two switches, and both are
needed:** `--flavor <f>` picks the platform side (Android product flavour; iOS scheme plus the
`Debug|Profile|Release-<f>` configuration), and `--dart-define=FLAVOR=<f>` picks the Dart side.
`AppConfig.flavor` reads only the define and defaults to `prod`, so `--flavor local` on its own
runs the prod configuration.

- **`local`** is the dev app pointed at the Firebase emulators (Auth, Firestore, Storage,
  Functions; Remote Config has no emulator and still reads dev) — see the `local-stack` skill.
  The Android emulator reaches the host at `10.0.2.2`, the iOS simulator at `127.0.0.1`, a
  physical device at `--dart-define=EMULATOR_HOST=<lan ip>`. Cleartext HTTP to the emulators is
  allowed in every **debug** build (`android/app/src/debug/res/xml/network_security_config.xml`)
  and in any build of the `local` flavour (`android/app/src/local/AndroidManifest.xml`), so a
  release or profile build against the emulators needs `--flavor local`.
- **Android ids**: `prod` is `com.bargain.wiz`; `dev` and `local` share `com.bargain.wiz.dev`
  (so `google-services.json` matches), which also means they share one Auth session store —
  after switching between them, `adb shell pm clear com.bargain.wiz.dev`. Version names get
  `-dev` / `-local`; the version itself is `pubspec.yaml`'s on both platforms.
- **iOS ids**: all three configurations build `com.bargain.wiz` against the one (dev) Firebase
  app. When a prod project exists, give the `*-prod` configurations their own
  `PRODUCT_BUNDLE_IDENTIFIER` and `GoogleService-Info.plist`. To add a flavour: duplicate the
  three configurations (the `xcodeproj` gem that ships with CocoaPods can), copy
  `Runner.xcscheme` to `<f>.xcscheme` with the configuration names rewritten, add it to the
  Podfile's list and `pod install`.
- **App name** lives in three places that must agree: Android `resValue("string", "app_name")`
  per flavour, iOS `APP_DISPLAY_NAME` per configuration, and `AppConfig.appName` (Bargain Wiz /
  Bargain Wiz Dev / Bargain Wiz Local).

iOS plugins resolve through **Swift Package Manager** —
CocoaPods only owns `permission_handler_apple` and `sign_in_with_apple`. When a pod does need
reinstalling:

```bash
cd ios && GEM_HOME=/opt/homebrew/Cellar/cocoapods/1.17.0/libexec \
  /opt/homebrew/Cellar/cocoapods/1.17.0/libexec/bin/pod install
```

(The "CocoaPods did not set the base configuration" warnings on the `-<flavour>` configs are
expected: those configs inherit the plain `Pods-Runner.debug.xcconfig`, and the pod set is the
same for every configuration.)

`permission_handler_apple` compiles every permission **out** unless the Podfile switches it on:
`PermissionHandlerEnums.h` defaults each `PERMISSION_*` to `0`, and the excluded permissions
fall back to `UnknownPermissionStrategy`, which answers `permanentlyDenied` without ever showing
a system prompt. The `post_install` hook enables `PERMISSION_PHOTOS` and
`PERMISSION_NOTIFICATIONS`; adding a new `Permission.x` on iOS means adding its macro there, its
`NS…UsageDescription` to `Runner/Info.plist`, and a `pod install`.

## Layout

`lib/core/` — cross-feature infrastructure: `app/` (bootstrap + splash), `config/`, `di/`
(GetIt, `injection_container.dart`), `network/` (`CloudFunctionsClient`), `services/` (auth,
Firebase, Remote Config, profile), `routing/`, `theme/`, `utils/`, `widgets/`.

`lib/features/<feature>/` — clean-architecture slice: `data/` (datasources, models,
repositories), `domain/` (entities, repositories — there are no use-case classes),
`presentation/` (cubit or bloc, pages, widgets), and in newer slices a `di.dart` the container
calls. Many slices carry empty scaffold folders (`data/network/`, …) — ignore them, don't copy
them. Cubits for new state, `dartz` `Either` for results, `json_serializable` for wire models.

Notable features: `conversation/` (the shared Firestore listener + API used by both AI flows),
`express_dealmaker/`, `pro_deal_closer/`, `lines_that_land/`, `home/`, `onboarding/`,
`subscription/`, `paywall/`.

## Things that will bite you

- **Startup is paint-first.** `main.dart` paints `BootSplash` while `AppBootstrap` initialises
  Firebase, Remote Config and auth *after* the first frame. Never add synchronous work before
  `runApp`, and never `await` a network call on the way to the first frame. See `STARTUP.md`.
- **The app never writes conversation documents.** Send through `ConversationsApi`, then read
  the result off the stream (`ConversationsStream`). A "wizard is typing" placeholder is a
  pending message with no text — the projection skips those, so don't render them.
- **Screenshot payloads are the client's responsibility.** `core/utils/screenshot_encoder.dart`
  compresses natively (flutter_image_compress) and retries at lower quality/size until the image
  is under `AttachmentLimits.maxImageBytes`. Limits live in `core/config/attachment_limits.dart`
  — one place, mirroring the function's looser ceiling.
- **The app never runs without a uid.** `AppBootstrap.run` awaits the anonymous sign-in and
  returns a message instead of starting the app when it fails, so `BootSplash` stays up with
  tap-to-retry. Background retries are throttled (`AuthService.retryCooldown`, 5 s) — do not
  add a retry loop on top; a caller the person is waiting on passes
  `ensureSignedIn(force: true)` instead. Every endpoint the app calls requires an ID token.
- **Firebase config lives in the platform files, not in Dart.** `Firebase.initializeApp()`
  takes no options: Android reads `android/app/google-services.json` (compiled into resources
  by the `com.google.gms.google-services` plugin) and iOS reads
  `ios/Runner/GoogleService-Info.plist` from the app bundle. There is no
  `firebase_options.dart` — do not let `flutterfire configure` reintroduce one, and if you
  regenerate the Xcode project, re-check that the plist is still in the Runner target's Copy
  Bundle Resources (a missing plist fails at launch, not at build).
- **The gallery picker asks for nothing.** `PHPickerViewController` (iOS 14+) and
  `ACTION_GET_CONTENT` (Android) run out of process and need no photo-library permission, so
  `GalleryPickerHelper` opens the picker straight away; a pre-flight `Permission.photos` only
  adds a prompt that can come back `limited`/`denied` and block a picker that would have
  worked. The handoff §10 "Photo access" dialog is shown only on the picker's own
  `photo_access_denied` / `photo_access_restricted`.
- **Notification permission has one owner.** `FirebaseService.requestNotificationPermission()`
  — used by the onboarding `permission` screen and by the paywall's reminder step (any step with
  `button_action: request_permission`, or the legacy `reminder` id). It prompts *and* registers
  for FCM; do not add a second path through `permission_handler`.
- **Push topics have one owner too.** `PushTopicService` keeps each install in exactly one
  FCM topic — `onboarding_phase` → `subscription_phase` → `premium_phase` — derived from local
  state (paid tier, else finished onboarding, else onboarding), never stored. It re-applies on
  every FCM token (so at launch, once there is one), when onboarding finishes and when the
  stored entitlement changes. Campaigns target these names: renaming one leaves installs in
  the old topic, because only the current names are ever unsubscribed. Do not call
  `subscribeToTopic` anywhere else.
- Emulator startup timings swing wildly with host load — measure with `--trace-startup` on an
  idle machine before claiming a regression (`STARTUP.md`).

## Docs in this folder

Contracts (the only description of the wire format — change one with the code):
`CONVERSATIONS.md` (backend-owned conversations, rules, indexes) · `AI_INTEGRATION.md`
(function contracts, prompts, limits) · `PROFILE_SYNC.md` · `LINES_THAT_LAND.md`.
Notes: `STARTUP.md` (the paint-first boot and how to measure it) · `PAYWALL.md` (the offer,
trial, wording, plan cards, payment provider and which features are Premium — all Remote
Config). Character art: the `illustration-asset` skill.
