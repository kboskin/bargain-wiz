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

## Why two shapes for the same answers

Onboarding is a remote-configured template: screens, `answer_key_name`s and value types
change whenever the funnel is edited. The schema therefore separates:

- **`preferences`** — the fields the backend logic depends on. A screen fills one by naming
  its answer after it: `answer_structure.answer_key_name` (a `select_group` group carries its
  own) **is** the field name, so there is no mapping to keep in step — wiring a new question to
  the backend is a config edit, not a client release.
- **`onboarding`** — the raw answers exactly as collected, under the same keys, plus the
  **`flow`**: an ordered trace of the screens shown with the options they offered. That makes
  every answer interpretable without the config that produced it, which matters once several
  funnel variants run at the same time. This is the analysis surface; it may hold keys the app
  does not know about.

```json
{"type": "select", "answer_structure": {"answer_key_name": "vibe"}, "options": [ … ]}
```

So the app names almost no key: `RemoteConfigService.getProfileFields()` turns the screens into
[`ProfileField`]s — key, kind, options and every attribute the UI draws (label, colour, icon,
subtext, emoji, savings, default) — and the profile services copy `{key: value}` pairs out of
local storage. `ProfileFields` spells out four keys only, and says why: `referral_code` (its
own wire section), `vibe`, `push` (chips and a meter instead of a settings row) and
`marketplace` (saved with a conversation).

An answer that no function reads simply rides along and is ignored; a field the funnel stops
asking for stops being sent. Two consequences worth knowing: the AI functions **require**
`vibe` and `push`, so keep screens asking for them (an unanswered screen falls back to its
configured `default_value` / first option, never to a Dart constant), and **renaming a key
orphans the answers already stored under the old one** — they stay in `onboarding.answers` and
read as unanswered.

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
  "schema_version": 1,
  "identity": {
    "uid": "firebase-uid",                      // always present; the document's own id
    "provider": "google.com | apple.com"        // from the ID token, absent while anonymous
  },
  "preferences": {                               // one entry per answer the screens collect
    "vibe": "friendly | no_nonsense | tactical | quiet_closer",
    "push": 60,                                  // 0–100, from the push slider
    "marketplace": "ebay | amazon | facebook | olx | craigslist | other",
    "deals_per_month": "0_2 | 3_5 | 6_plus",
    "deal_size": 550,                            // USD midpoint of the chosen bucket
    "hurdles": ["starting", "fair_price"],       // ids of the money-leak screen
    "locale": "en | es"                          // the device's, not an answer
  },
  "onboarding": {
    "answers": {                                 // raw, keyed by answer_key_name
      "main_hurdle": ["starting", "fair_price"],
      "negotiation_vibe": "tactical",
      "risk_tolerance": 80,
      "favorite_marketplace": "ebay",
      "deals_per_month": "3_5",
      "average_deal_size": 550,
      "referral_code": "FRIEND-42"
    },
    "completed_at": "2026-09-17T12:00:00Z",      // server time, set when completed=true
    "flow": [                                    // ordered trace, recorded at completion
      {"index": 0, "key": "main_hurdle", "type": "multiSelect",
       "title": "Where has your money slipped away?",
       "options": ["starting", "counter_offers", "being_rude", "holding_ground", "fair_price"]},
      {"index": 1, "key": "negotiation_vibe", "type": "select", "title": "Who negotiates for you?",
       "options": ["friendly", "no_nonsense", "tactical", "quiet_closer"]}
    ]
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
that. What it adds is the `flow` trace: exactly which screens and options a user was served,
so answers from different arms stay interpretable in Firestore on their own and can be joined
to the experiment via the Analytics export (uid) when needed.

Profile edits after onboarding push answers and preferences again but no `flow`; the
completion trace stays as recorded.

## Preferences into the model

`preferences` is the block the AI functions consume. Today the app sends the same
`{key: value}` pairs with every `express_dealmaker` / `pro_deal_closer` request, plus the
locale; `features/negotiation/domain/prompts.py` turns hurdles and deal frequency into coaching hints in the system
prompt. The referral code is the one answer that stays out of `preferences`: it has a section
of its own (`referral.code`, stamped with `entered_at`). The next step, once profiles are populated, is to let
the functions read `users/{id}` themselves and drop the fields from the request body.

## Endpoint

`PATCH /profile` — body `{preferences?, onboarding?, referral?, app?}`.
Partial update: nested maps merge, a `null` leaf deletes the field, `onboarding.completed:
true` stamps `completed_at`. Returns the merged document. `identity` is server-managed.

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
| Onboarding "Setting up" step | `OnboardingRepository.uploadUserData` → `pushOnboarding`: full answers with `completed: true`. Best effort: onboarding finishes even if the backend is down. |
| Profile screen edit | `UserProfileService` stores the answer, then calls `schedulePush`: a debounced (1.5 s) push of the full current state, which the server merges. |
| Sign-in (`authStateChanges`) | Push once (server merges the anonymous profile), then if the device has no local answers, `GET` the account profile and save its answers locally (`saveOnboardingData` + `refresh`), so the profile follows the user. |
| Failure | Logged, retried once after 30 s; every later change pushes the full state again. |

## What the Profile screen edits

The Profile screen edits the same answers onboarding collected, and it reads the list from the
same place: `ProfileFields.fromScreens` walks the `onboarding_screens` templates and turns every
screen that writes an answer into a row — `select` / `select_group` groups and both slider
templates into a one-chip sheet, `multi_select` into tick rows, `referral_code` into a text
field. Screens that ask nothing are skipped, and so are the `vibe` and `push` answers, which
keep their own vibe chips and push meter. A screen added to the funnel remotely
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
- **Deleting an answer**: send `{"onboarding": {"answers": {"key": null}}}`.
- **Not stored**: names, emails, photos (they stay in Firebase Auth), purchases (store SDK),
  conversations (device only), screenshots.
- **Later**: App Check on the function; a `deleted_at`/account-deletion path (GDPR/CCPA
  "delete my data") is the next thing this endpoint needs before launch.
