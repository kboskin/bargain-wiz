# Profile sync — onboarding answers and preferences in Firestore

> **2026-09-17:** every install now signs in to Firebase **anonymously** at startup and links
> the provider on sign-in (`AuthService`, see `CONVERSATIONS.md` §2), so requests always carry
> an ID token and the profile document is keyed by that uid. `installation_id` is still sent
> so a pre-existing `users/inst_<id>` document is folded into the uid document once.

The device is still the source of truth for the funnel (answers live in `SharedPreferences`
under `onboarding_data`), but every change is mirrored to a Firestore document through the
`profile` Cloud Function so the profile survives reinstalls, follows a signed-in user across
devices, and can be analysed. The client never talks to Firestore directly (Admin SDK only, so
Firestore security rules can stay closed).

## Why two shapes for the same answers

Onboarding is a remote-configured template: screens, `answer_key_name`s and value types
change whenever the funnel is edited. The schema therefore separates:

- **`preferences`** — a small, stable, typed block the app logic depends on today. The client
  derives it from the answers with the same rules as `UserProfileService`, so a renamed screen
  or a new option never breaks prompts or gating.
- **`onboarding`** — the raw answers exactly as collected, keyed by `answer_key_name`, plus
  the **`flow`**: an ordered trace of the screens shown with the options they offered. That
  makes every answer interpretable without the config that produced it, which matters once
  several funnel variants run at the same time. This is the analysis surface; it may hold
  keys the app does not know about.

Validation is deliberately loose: known preference fields are type-checked and clamped,
answers accept any JSON leaf up to size limits, unknown top-level sections are ignored (and
logged), never rejected.

## Document `users/{id}`

Everything about a person lives under one path: this document holds the profile, and the same
document parents the `conversations` and `limits` subcollections (see `CONVERSATIONS.md`).
`{id}` is the Firebase Auth uid, or `inst_<installation_id>` for an install that has no uid
yet. The app never reads this document with the Firestore SDK; it goes through the `profile`
function, and the security rules deny client access to it.

`id` is the Firebase Auth uid, or `inst_<installation_id>` while signed out.

```json
{
  "schema_version": 1,
  "identity": {
    "uid": "firebase-uid",                      // absent for signed-out profiles
    "provider": "google.com | apple.com",       // from the ID token
    "installation_ids": ["3fa85f64-…"],          // every install seen (array union)
    "merged_from": ["inst_3fa85f64-…"],          // anonymous profiles folded into this one
    "merged_into": "firebase-uid"                // set on an anonymous profile after fold
  },
  "preferences": {                               // model-ready; also sent with every AI request
    "vibe": "friendly | no_nonsense | tactical | quiet_closer",
    "push": 60,                                  // 0–100, onboarding risk_tolerance
    "marketplace": "ebay | amazon | facebook | olx | craigslist | other",
    "deals_per_month": "0_2 | 3_5 | 6_plus",
    "deal_size": 550,                            // USD midpoint of the chosen bucket
    "hurdles": ["starting", "fair_price"],       // onboarding main_hurdle ids
    "locale": "en | es"
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
to the experiment via the Analytics export (installation id / uid) when needed.

Profile edits after onboarding push answers and preferences again but no `flow`; the
completion trace stays as recorded.

## Preferences into the model

`preferences` is the block the AI functions consume. Today the app sends it with every
`express_dealmaker` / `pro_deal_closer` request (vibe, push, marketplace, deal_size,
deals_per_month, hurdles, locale); `negotiation.py` turns hurdles and deal frequency into
coaching hints in the system prompt. The next step, once profiles are populated, is to let
the functions read `users/{id}` themselves and drop the fields from the request body.

## Endpoint

`PATCH /profile` — body `{installation_id, preferences?, onboarding?, referral?, app?}`.
Partial update: nested maps merge, a `null` leaf deletes the field, `onboarding.completed:
true` stamps `completed_at`. Returns the merged document. `identity` is server-managed.

`GET /profile?installation_id=<uuid>` — the caller's document, 404 until the first PATCH.

Identity: an optional `Authorization: Bearer <Firebase ID token>` selects the uid document;
otherwise `installation_id` (a UUID minted on first launch, `InstallationIdService`) selects
the anonymous one. **Sign-in merge:** a PATCH that carries both folds the pending anonymous
profile into the uid profile — existing uid values win, gaps are filled — and marks the
anonymous document `merged_into`. Later PATCHes do not merge again.

Errors: `{"error": {"status": "INVALID_ARGUMENT" | "UNAUTHENTICATED" | "NOT_FOUND" | "METHOD_NOT_ALLOWED" | "INTERNAL", "message": "…"}}`.

## App side (`ProfileSyncService`)

| Trigger | What happens |
|---|---|
| Onboarding "Setting up" step | `OnboardingRepository.uploadUserData` → `pushOnboarding`: full answers with `completed: true`. Best effort: onboarding finishes even if the backend is down. |
| Profile screen edit (`UserProfileService` change) | Debounced (1.5 s) push of the full current state; the server merges. |
| Sign-in (`authStateChanges`) | Push once (server merges the anonymous profile), then if the device has no local answers, `GET` the account profile and save its answers locally (`saveOnboardingData` + `refresh`), so the profile follows the user. |
| Failure | Logged, retried once after 30 s; every later change pushes the full state again. |

Files: `core/services/profile_sync_service.dart`, `core/services/installation_id_service.dart`,
`features/profile/data/datasources/profile_remote_datasource.dart`,
`features/profile/data/models/profile_api_models.dart`; backend `functions/user_profile.py`.

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
