# Profile sync — onboarding answers and preferences in Firestore

> **2026-09-19:** the uid is the only identity. `AppBootstrap.run` **awaits** the anonymous
> sign-in before the first screen and shows a blocking failure screen when it fails (see
> `CONVERSATIONS.md` §2), so every request carries an ID token and the document is always
> keyed by that uid. The `installation_id` — and `InstallationIdService` with it — is gone:
> there is no signed-out document to key by, nothing to fold, and the endpoint now rejects a
> call with no token instead of writing `users/inst_<id>`.

The device is still the source of truth for the funnel (answers live in `SharedPreferences`
under `onboarding_data`), but every change is mirrored to a Firestore document through the
`profile` Cloud Function so the profile survives reinstalls, follows a signed-in user across
devices, and can be analysed. The client never talks to Firestore directly (Admin SDK only, so
Firestore security rules can stay closed).

## One shape for the answers

Onboarding is a remote-configured template: screens, `answer_key_name`s and value types
change whenever the funnel is edited. **`preferences` is the whole record** — every answer
the screens collect, under the key that names it. A screen fills one by naming its answer
after the field: `answer_structure.answer_key_name` (a `select_group` group carries its own)
**is** the field name, so there is no mapping to keep in step, and wiring a new question to
the backend is a config edit, not a client release.

The fields `PATCH /profile` names (`vibe`, `push`, `marketplace`, `deals_per_month`,
`deal_size`, `hurdles`, `locale`) are typed and coerced; every other answer is stored as sent, so a
question added in Remote Config is recorded without a backend deploy. Beside it sits
**`onboarding_status`** — `completed_at`, stamped by the server when a client first reports
the funnel finished.

The answers are pushed **step by step** (2026-09-23): each time the person moves on from a
screen that asks something, the flow sends everything answered so far. A document exists from
the first launch (every launch sets `app.last_opened_at`, see below), so `created_at` is
when the app was first opened; one with no `onboarding_status.completed_at` is a funnel still
in progress or abandoned, and its `preferences` are recorded as far as it got. `updated_at`
moves on every write — a step, an edit or a launch — so it is not where someone stopped.
Signing in on the `create_account` screen keeps the uid (the anonymous user is linked), so the
same document carries on; signing into an account that already exists switches uid, and the
steps before it stay behind on the anonymous uid's document, unfinished.

There used to be a second `onboarding` section holding the same answers again plus a `flow`
trace of the screens shown. It was removed: the answers were a duplicate of `preferences`,
nothing read the trace, and one record that can hold any key does the same job. Experiment
assignment is Firebase A/B Testing's (Analytics user properties), not this document's — the
cost of the removal is that an answer can no longer be interpreted without the template
version that produced it, and the template is versioned in git.

```json
{"type": "select", "answer_structure": {"answer_key_name": "vibe"}, "options": [ … ]}
```

So the app names almost no key: `RemoteConfigService.getProfileFields()` turns the screens into
[`ProfileField`]s — key, kind, options and every attribute the UI draws (label, colour, icon,
subtext, emoji, savings, default) — and the profile services copy `{key: value}` pairs out of
local storage. `ProfileFields` spells out one key only, and says why: `referral_code` has a
wire section of its own and is the one answer the Profile screen never re-opens
(`ProfileFields.lockedKeys`). `vibe`, `push` and `marketplace` used to be named beside it;
they are not any more. Which answer gets a card instead of a settings row comes from the
template its screen used (`slider_lottie` → the meter, `select` → the chips, anything else →
a row), and which answer a single deal may carry its own value for comes from the screen's
`scope` — so both are the template's to decide and neither is a list in Dart.

An answer that no function reads simply rides along and is ignored; a field the funnel stops
asking for stops being sent. Two consequences worth knowing: an unanswered screen falls back
to its configured `default_value` / first option, never to a Dart constant — nothing is
required any more, the AI functions name no answer and so have none to demand, but what is
not sent is not coached on — and **renaming a key orphans the answers already stored under
the old one**: they stay in `preferences` under the old key and read as unanswered.

Validation is deliberately loose: known preference fields are type-checked and clamped,
answers accept any JSON leaf, unknown top-level sections are ignored (and logged), never
rejected. Nothing bounds the size of a patch beyond Firestore's own 1 MiB document limit.

## Document `users/{id}`

Everything about a person lives under one path: this document holds the profile, and the same
document parents the `conversations` and `limits` subcollections (see `CONVERSATIONS.md`).
`{id}` is always the Firebase Auth uid — anonymous or linked to a provider, the app has no
state in which it lacks one. The app never reads this document with the Firestore SDK; it
goes through the `profile` function, and the security rules deny client access to it.

```json
{
  "schema_version": 2,
  "identity": {
    "uid": "firebase-uid",                      // always present; the document's own id
    "provider": "google.com | apple.com"        // from the ID token, absent while anonymous
  },
  "preferences": {                               // every answer the screens collect; the
                                                 // only record of them
    "vibe": "friendly | no_nonsense | tactical | quiet_closer",
    "push": 60,                                  // 0–100, from the push slider
    "marketplace": "ebay | amazon | facebook | olx | craigslist | other",
    "deals_per_month": "0_2 | 3_5 | 6_plus",
    "deal_size": 550,                            // USD midpoint of the chosen bucket
    "hurdles": ["starting", "fair_price"],       // ids of the money-leak screen
    "locale": "en | es",                         // the device's, not an answer
    "experience_level": "pro"                    // a question added in Remote Config: stored
                                                 // as sent, no backend change needed
  },
  "onboarding_status": {
    "completed_at": "2026-09-17T12:00:00Z"       // server time, set when completed=true;
                                                 // absent while the funnel is unfinished
  },
  "referral": {"code": "FRIEND-42", "entered_at": "…"},
  "app": {"platform": "ios | android", "locale": "en", "version": "…",
          "fcm_token": "…",                      // this install's FCM registration token
          "last_opened_at": "…"},                // device time, sent on every launch
  "created_at": "…",
  "updated_at": "…"
}
```

Timestamps are Firestore server timestamps, returned as ISO-8601 UTC strings.

## Experiments

Onboarding experiments run in the Firebase console (A/B Testing on Remote Config): each arm
serves its own `onboarding_screens`, and Firebase tracks the assignment through Analytics
(`firebase_exp_<id>` user properties, exported to BigQuery). The profile does not duplicate
that, and no longer records which screens or options a user was served: join an answer to its
arm through the Analytics export on uid — the uid is the Analytics user id, see
[Funnel analytics](#funnel-analytics) — and to the question that produced it through the
`onboarding_screens` template version in git.

## Preferences into the model

`preferences` is the record; an AI request carries the same answers in a different shape. A
request nests them under `profile`: `{"answers": [{"key", "value", "prompt"?}], "locale"}` —
one entry per *pick*, so a multi-select is several entries sharing a key, in onboarding screen
order, which is the order the buyer block reads in. A map is what a record wants; an order is
what a prompt wants, and `UserProfileService.snapshot()` produces both from one traversal
(`ProfileSnapshot(fields, answers)`), so the two views can never describe different options.
Nothing is required: the backend names no key, so an empty `answers` list is a valid request
that simply produces a prompt with no buyer block — keep the screens asking, because an
answer that is not sent is not coached on. The referral code is the one answer that stays out
of `preferences`, and out of `answers` too: it has a section of its own (`referral.code`,
stamped with `entered_at`). The client holds it back from the step-by-step pushes — the
function keeps the first code it gets, and until the funnel is finished the person can still
go back and correct one — and sends it from the completion push on: the device cannot change
it after that, so a retried first push still credits it. The next step,
once profiles are populated, is to let the functions read `users/{id}` themselves and drop
the profile from the request body.

Each entry carries the `metadata.prompt` sentence remote config writes next to the option that
was picked, which is what the prompt renders instead of the backend keeping its own copy of
the option list (`AI_INTEGRATION.md`). Those sentences are **not** part of `preferences` and
are never stored: they are copy belonging to a template version, they would go stale in the
document the moment someone edits one, and the template version in git records which options a
screen offered. Mechanically there is nothing to do — `ProfileSyncService.buildPatch` builds
`preferences` from the configured fields and the stored answers, never from
`payload()`/`snapshot()`.

A deal's own answers travel beside the profile rather than inside it. A conversation write
also carries `overrides`, `{answer key: value}` for the answers a screen marks
`scope: "conversation"` (`CONVERSATIONS.md`); the app resolves them into the `answers` it
sends, so what a deal shows is the option actually being sent. They change that
deal only — nothing writes them back here, and this document keeps the default the Profile
screen sets.

## Endpoint

`PATCH /profile` — body `{preferences?, onboarding_status?, referral?, app?}`.
Partial update: nested maps merge, a `null` leaf deletes the field, `onboarding_status.completed:
true` stamps `completed_at`. `app.last_opened_at` is an ISO-8601 time, stored as a Firestore
timestamp. Returns the merged document. `identity` is server-managed.

`referral.code` is **write-once** (`WRITE_ONCE` in `domain/profile.py`): the first code a
profile is given stands, and a later PATCH carrying one is dropped and logged instead of
re-attributing an install that is already credited. An explicit `null` still clears it, and
the next code after that is treated as the first. The app hides the field (below), so this is
what holds for an older or tampered client.

`GET /profile` — the caller's document, 404 until the first PATCH.

Identity: `Authorization: Bearer <Firebase ID token>` is **required** on both methods and is
the only identity — the uid in the token picks the document. A call without one is
`UNAUTHENTICATED`; the client sends no id of its own. Linking a provider to the anonymous
user keeps the uid, so the same document simply gains `identity.provider` — there is nothing
to merge.

Errors: `{"error": {"status": "INVALID_ARGUMENT" | "UNAUTHENTICATED" | "NOT_FOUND" | "METHOD_NOT_ALLOWED" | "INTERNAL", "message": "…"}}`.

## App side (`ProfileSyncService`)

| Trigger | What happens |
|---|---|
| Onboarding step left | Moving forward off a screen that asks something (`_pushProgress` in `onboarding_screen.dart`): `uploadUserData` → `pushOnboarding` with every answer so far, no `onboarding_status`, no `referral`. Screens that ask nothing send nothing; going back sends nothing, and the next step forward sends a changed answer. Best effort and not awaited. |
| Onboarding "Setting up" step | `OnboardingRepository.uploadUserData` → `pushOnboarding`: full answers with `onboarding_status.completed: true` and the referral code. Best effort: onboarding finishes even if the backend is down. |
| Profile screen edit | `UserProfileService` stores the answer, then calls `schedulePush`: a debounced (1.5 s) push of the full current state, which the server merges. |
| Sign-in (`authStateChanges`) | Push once (server merges the anonymous profile), then if the device has no local answers, `GET` the account profile and save its answers locally (`saveOnboardingData` + `refresh`), so the profile follows the user. |
| Launch | `start()` (from `AppBootstrap.warmUp`, once per launch, after the launch has signed in) sends `{"app": {"platform", "locale", "last_opened_at"}}`, the time now in UTC by the device clock — whether or not onboarding has begun, so the first launch creates the document. A cold start only: coming back from the background is not a launch. Not retried: the next launch sends it again. |
| FCM token | `FirebaseService.fcmTokens()` — the token at launch, then every rotation. Every push above carries the latest as `app.fcm_token`; a token that arrives while the app runs is also sent on its own (`{"app": {"fcm_token": …}}`) when the device has answers, so an existing profile learns it without waiting for an edit. That is one small write per launch, which doubles as the "still in use" signal for pruning stale tokens. Not retried: the next launch or edit sends it again. |
| Failure | Retried once after 30 s with the same patch (a change made meanwhile pushes the full state instead). A failed retry is reported to Crashlytics as a non-fatal — the count of profiles the server is missing — and is not retried again: the next change pushes the full state. |

### The FCM token

`app.fcm_token` is where a push to this person goes. It is reported whether or not the
notification permission was granted — the token exists either way; the permission only
decides whether an alert is shown — so a sender has to expect some tokens it can reach but
not alert. One token per profile, like the rest of `app`: the last device to push wins, so a
person signed in on two devices is reachable on the last one used. Nothing is sent while no
token can be had (iOS before APNs registers; and on iOS APNs cannot register until the push
capability exists, see `../AGENTS.md`), and a missing token never deletes a stored one. The
function stores it trimmed and never clipped: a truncated token addresses nothing.

## Funnel analytics

The device only writes the answers to `SharedPreferences` on submit. The profile gets them step
by step, so someone who drops out at screen four leaves the answers of screens one to three in
`preferences` — but not the screens that ask nothing, the order they were seen in, or where
someone turned back. That trace exists in Firebase Analytics or nowhere, and the flow reports
itself (`core/services/analytics_service.dart`, called from
`features/onboarding/presentation/pages/onboarding_screen.dart`):

| Event | When | Parameters |
|---|---|---|
| `screen_view` | a screen comes into view | `screen_name` `onboarding/<step_id>`, `screen_class` `OnboardingFlowPage`, plus `step_index`, `step_count`, `step_id`, `step_type`, `direction` |
| `onboarding_step_answered` | the person moves on from that screen | `step_index`, `step_id`, `step_type`, `answer_keys` (left out when the screen asks nothing), and one parameter per answer picked from the screen's options, named by its key: `vibe` `tactical`, `deal_size` `550`, `hurdles` `starting,fair_price` |
| `onboarding_completed` | the funnel finishes, beside the profile push | `step_count`, `answered_count` |

A step is a screen, so it is reported as one: the flow calls `AnalyticsService.logScreenView`
with the funnel position as the screen view's own parameters, rather than a custom event
repeating it beside the screen view.

`step_id` is the screen's `answer_key_name`: screens have no id of their own, and the key is
what survives the funnel being reordered — a screen that asks nothing is named by its template
instead. Both events fire only where a screen actually changes, never per keystroke or slider
tick.

**What was picked rides on `onboarding_step_answered`** (2026-09-23; until then only
`answer_keys` were sent). `preferences` is the record, of unfinished funnels too; the event
puts the same picks beside the screen trace, so the funnel can be broken down by answer ("do
small-deal sellers quit earlier?") and joined with the A/B arm in the BigQuery export on uid,
finished or not. Rules:

- **Option ids only.** Only answers picked from a configured option list are sent — `select`,
  `multi_select`, `select_group`, `slider`, `slider_lottie`
  (`OnboardingAnswerFlattener.pickedOptions`). Typed answers (the referral code, any future
  text screen) are never sent: Google Analytics forbids personal data, and free text can
  carry it.
- **The answer key is the parameter name**, so it must be a valid Analytics name (snake_case,
  ≤ 40 characters, not `firebase_`/`google_`/`ga_`-prefixed — every key today is). A key that
  clashes with one of the step's own parameters is dropped in their favour. Values are cut at
  100 characters by Analytics; a multi-select is its ids comma-joined.
- **To see them in the console**, register each key as an event-scoped custom dimension
  (Analytics → Custom definitions; 50 per property). BigQuery has every parameter without
  that, once the Analytics → BigQuery link is on for the project.

Screen views for the rest of the app come from a `FirebaseAnalyticsObserver` on the router.
It reads `route.settings.name`, so every page built by a custom `pageBuilder` carries a
`name` — go_router only fills that in for the pages it builds itself, and a page without one
is silently skipped. Onboarding is a single route with a `PageView`, which is why its steps
send their own `screen_view` instead.

### Identity

`AppBootstrap.warmUp` calls `AnalyticsService.setUserId` once, with the uid the launch signed
in under, so every event is attributed to the uid this document is keyed by. It is never null
there: `run` blocks the app until the anonymous sign-in succeeds. Linking a provider keeps
that uid, so nothing has to be re-sent; signing into a credential that already has an account
switches it, and that session keeps reporting under the uid it started with until the next
launch — which the profile document and Firebase Auth both record properly anyway.

The uid is the **only** identity reported, and **no user properties are set at all**. Who that
uid turned out to be lives on `identity.provider` above and in Firebase Auth; which device it was
lives on `app` above (each Firebase project is one flavor, so the flavor is not recorded); the answers live in `preferences` and on the funnel events. All of it joins to Analytics on the uid whenever it is actually wanted, and a user
property would only be a second copy to keep true. (The `local` flavor turns collection off
in the SDK, in `FirebaseService`, so emulator runs stay out of the data entirely.)

## What the Profile screen edits

The Profile screen edits the same answers onboarding collected, and it reads the list from the
same place: `ProfileFields.fromScreens` walks the `onboarding_screens` templates and turns every
screen that writes an answer into a field — `select` / `select_group` groups and both slider
templates single-choice, `multi_select` multi-choice, a text screen a text field. **Which
widget an answer gets comes from the template its screen used**, not from a list of keys and
not from a config key naming a control: `slider_lottie` becomes the meter card, `select` the
chip card, and everything else a settings row that opens a sheet — a one-chip sheet, tick
rows, or a text field, by kind. So the push meter and the tone chips are just what those two
screens' templates draw, and a question added remotely draws itself with a control this build
already has. Screens that ask nothing are skipped, and so is every key in
`ProfileFields.lockedKeys` — today
just `referral_code`. A referral code is an attribution, not a preference: it is asked for once
during onboarding, so the screen offers no row for it and a profile push leaves it out of
`preferences` (the function's write-once rule is what stops any client re-setting it). A screen
added to the funnel remotely
therefore becomes an editable row without an app release; one removed stops being offered, while
an answer already stored still shows its raw value rather than disappearing.

Row labels come from an optional `metadata.profile_label` on the screen (a `select_group` group
uses its own `label`), because the screen title is the question — "Where has your money slipped
away?" is not a settings row. Without one the title is used as-is. Edits go through
`UserProfileService.setAnswer`, so they are stored, pushed by this service and picked up by
`preferences` exactly like an onboarding answer; slider stops are stored as ints, multi-selects
as the ordered list of values.

Files: `core/services/user_profile_service.dart`, `core/services/profile_sync_service.dart`,
`core/theme/option_style.dart` (how a configured option is drawn),
`features/profile/domain/profile_fields.dart`,
`features/profile/data/datasources/profile_remote_datasource.dart`,
`features/profile/data/models/profile_api_models.dart`; backend
`functions/features/profile/` (`domain/profile.py` + `data/store.py`).

## Decisions and open points

- **Firestore via Admin SDK only.** No client SDK, no rules to maintain; the function
  validates. Keep Firestore rules at deny-all.
- **Full-state pushes, partial-update endpoint.** The client sends everything it knows (a few
  hundred bytes); the endpoint still honours true partial bodies for other clients or tools.
- **Deleting an answer**: send `{"preferences": {"key": null}}`.
- **Not stored**: names, emails, photos (they stay in Firebase Auth), purchases (store SDK),
  conversations (device only), screenshots.
- **Later**: App Check on the function; a `deleted_at`/account-deletion path (GDPR/CCPA
  "delete my data") is the next thing this endpoint needs before launch.
