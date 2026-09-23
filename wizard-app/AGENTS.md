# wizard-app — agent guide

Flutter client for Bargain Wiz (iOS + Android). Repo-wide conventions: `../AGENTS.md`.

## Tech stack

| Concern | What we use |
|---|---|
| Framework | Flutter **3.44.6** / Dart **3.12.2** (`environment: sdk ^3.9.2`), Material 3 |
| State | `flutter_bloc` 8 — Cubits for feature state, `Bloc` where events are worth naming; `equatable` on every state |
| DI | `get_it` — one container (`core/di/injection_container.dart`) calling each feature's `di.dart` |
| Errors | `dartz` `Either<Failure, T>` out of repositories/usecases; failures in `core/error/` |
| Routing | `go_router` 14 (`core/routing/app_router.dart`, route ids in `app_routes.dart`) |
| Network | `dio` behind `CloudFunctionsClient` — JSON over HTTPS to the Cloud Functions, base URL from the Remote Config `api_url`, Firebase ID token attached per call, POST timeout 70 s |
| Firebase | `firebase_core`, `firebase_auth` (anonymous → Google/Apple link), `cloud_firestore` (conversation listener, read-only), `firebase_storage`, `firebase_remote_config`, `firebase_analytics`, `firebase_crashlytics`, `firebase_messaging` |
| Serialization | `json_annotation` + `json_serializable` (`build_runner`); wire models are `*.g.dart`, never hand-written |
| i18n | `flutter_localizations` + `intl`, ARB in `lib/l10n/` (`app_en.arb`, `app_es.arb`), generated via `l10n.yaml` + `generate: true` |
| Design system | Tokens in `core/theme/wiz_theme.dart` (`WizColors`/`WizType`/`WizMotion`), shared widgets in `core/widgets/wiz/`; bundled Outfit + Figtree TTFs; `lottie`, `flutter_svg`, `font_awesome_flutter`, `flutter_html` for rich copy |
| Device / media | `image_picker`, `permission_handler`, `flutter_image_compress`, `speech_to_text`, `video_player`, `share_plus`, `url_launcher`, `connectivity_plus`, `shared_preferences` |
| Monetization | `in_app_purchase` behind `PaymentProviderType` (`--dart-define=PAYMENT_PROVIDER=iap|stripe`), `in_app_review` for Rate Us |
| Tests | `flutter_test` + hand-written fakes (a little `mockito`); 44 test files, ~300 tests, no emulator needed |
| Lints | `flutter_lints` 5 plus the extra rules in `analysis_options.yaml`; generated files excluded |

Platforms: Android `com.bargain.wiz` (Kotlin Gradle DSL, JVM 11, flavor dimension
`environment`), iOS deployment target **15.0**. No `.fvmrc` — `fvm flutter` resolves to the
global `stable` (3.44.6 today), so check `fvm list` if versions look off.

Every screen is a Remote Config template with defaults bundled in
`assets/config/remote_config_defaults.json`; changing UI copy or layout usually means editing
that JSON, not Dart.

## Toolchain

**Always `fvm flutter`, never bare `flutter`** — the toolchain is Flutter 3.44.6 / Dart 3.12.2.

```bash
fvm flutter pub get
fvm flutter test                       # 300+ tests, runs in ~10s
fvm flutter analyze lib test
fvm flutter run --flavor local -t lib/main.dart
fvm dart run build_runner build --delete-conflicting-outputs   # *.g.dart after model changes
```

`flutter analyze` reports ~2900 pre-existing infos (`prefer_final_parameters`,
`use_raw_strings`, …). **Filter, don't fix them all:**

```bash
fvm flutter analyze lib test 2>&1 | grep -E "error •|warning •"
```

Only clean up lints in code you touched.

## Flavors

Three: `dev`, `prod`, `local` (`lib/core/config/app_config.dart`, `README_FLAVORS.md`).
`local` points Firebase at the emulator suite — see the `local-stack` skill. Host differs per
platform: Android emulator reaches the host at `10.0.2.2`, iOS simulator at `127.0.0.1`.
Cleartext to those hosts is allowed in **debug builds only**
(`android/app/src/debug/res/xml/network_security_config.xml`).

iOS builds need the matching Xcode configuration (`Debug-local`, `Release-dev`, …) and scheme;
they exist for all three flavors. iOS plugins resolve through **Swift Package Manager** —
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
repositories), `domain/` (entities, repositories, usecases), `presentation/` (cubit, pages,
widgets), plus a `di.dart` the container calls. Cubits (BLoC) for state, `dartz` `Either` for
results, `json_serializable` for wire models.

Notable features: `conversation/` (the shared Firestore listener + API used by both AI flows),
`express_dealmaker/`, `pro_deal_closer/`, `lines_that_land/`, `home/`, `onboarding/`,
`subscription/`, `paywall/`.

## Things that will bite you

- **Startup is paint-first.** `main.dart` → `AppBootstrap` shows `AppSplash` and initialises
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
  `ensureSignedIn(force: true)` instead. There is no `installation_id` fallback identity any
  more: every endpoint requires an ID token.
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

`CONVERSATIONS.md` (backend-owned conversations, rules, indexes) · `AI_INTEGRATION.md`
(function contracts, prompts, image limits) · `PAYWALL_ART.md` (what the plan-card
illustrations must be, and how to swap them) · `PROFILE_SYNC.md` · `LINES_THAT_LAND.md` ·
`STARTUP.md` · `README_FLAVORS.md` + `QUICK_START_FLAVORS.md` · `FIREBASE_SETUP.md` ·
`AUTH_SETUP.md` · `LINTING.md` · `VERSIONING.md` · `BUILD_TROUBLESHOOTING.md` ·
`ANDROID_STUDIO_SETUP.md`.
