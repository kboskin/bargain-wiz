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
    "completed_at": "2026-09-17T12:00:00Z"       // server time, set when completed=true
  },
  "referral": {"code": "FRIEND-42", "entered_at": "…"},
  "app": {"platform": "ios | android", "flavor": "dev | prod", "locale": "en", "version": "…"},
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
arm through the Analytics export on uid, and to the question that produced it through the
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
stamped with `entered_at`), which the client keeps sending — the device cannot change it and
the function keeps the first one, so a retried first push still credits it. The next step,
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
sends, so a chip in a deal's header describes the option actually being sent. They change that
deal only — nothing writes them back here, and this document keeps the default the Profile
screen sets.

## Endpoint

`PATCH /profile` — body `{preferences?, onboarding_status?, referral?, app?}`.
Partial update: nested maps merge, a `null` leaf deletes the field, `onboarding_status.completed:
true` stamps `completed_at`. Returns the merged document. `identity` is server-managed.

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
| Onboarding "Setting up" step | `OnboardingRepository.uploadUserData` → `pushOnboarding`: full answers with `onboarding_status.completed: true`. Best effort: onboarding finishes even if the backend is down. |
| Profile screen edit | `UserProfileService` stores the answer, then calls `schedulePush`: a debounced (1.5 s) push of the full current state, which the server merges. |
| Sign-in (`authStateChanges`) | Push once (server merges the anonymous profile), then if the device has no local answers, `GET` the account profile and save its answers locally (`saveOnboardingData` + `refresh`), so the profile follows the user. |
| Failure | Logged, retried once after 30 s; every later change pushes the full state again. |

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
