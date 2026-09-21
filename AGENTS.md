# Bargain Wiz — agent guide

Two projects in one folder, one git repo. **The git root is this folder (`bwiz/`)**, not
`wizard-app/`: run git from here, or `git -C ..` when your shell sits inside a project.

| Path | What it is | Guide |
|---|---|---|
| `wizard-app/` | Flutter client (iOS + Android) | [`wizard-app/AGENTS.md`](wizard-app/AGENTS.md) |
| `wizard-backend/` | Firebase project: Cloud Functions (Python 3.12), Firestore rules, indexes, Storage rules | [`wizard-backend/AGENTS.md`](wizard-backend/AGENTS.md) |
| `design_handoff_bargain_wiz/` | Design source of truth: tokens, prototype, Remote Config patch | `design_handoff_bargain_wiz/README.md` |
| `DESIGN_SPEC.md` | Product and design spec behind the current UI | — |

## Tech stack

| Layer | What we use |
|---|---|
| Client | Flutter 3.44.6 / Dart 3.12.2 (always through `fvm`), BLoC + Cubit, GetIt, `dartz` `Either`, go_router, Dio, `json_serializable` |
| Functions | Python 3.12 on Cloud Functions **2nd gen** (`firebase-functions`), pydantic **v2** request models, `firebase-admin` for Firestore / Storage / Auth, Pillow for image re-encoding |
| Model | Gemini (`gemini-2.5-flash` by default) on **Vertex AI** via the `google-genai` SDK — JSON-schema-constrained output only, never free text |
| Async work | Cloud Tasks queue `generate` (also the project-wide rate limiter) + Cloud Scheduler job `refresh_lines` |
| Data | Firestore (profiles, conversations, generated Lines content), Cloud Storage (screenshots), Firebase Remote Config (screen templates and `api_url`) |
| Identity | Firebase Auth — anonymous from first launch, upgraded in place to Google / Apple; App Check behind a flag |
| Wire format | Plain JSON over HTTPS `on_request` functions with a Firebase ID token in `Authorization` — **not** callable functions |
| Tooling | `fvm` (Flutter), `uv` or `python3.12 -m venv` + `pytest` + `ruff` (backend), Firebase CLI emulator suite, `firebase deploy` |

Firebase project `wizard-app-dev` (`.firebaserc`), everything in `us-central1`, functions
deployed as the codebase `lines-that-land` (`firebase.json`).

## How the halves meet

The backend owns conversations; the app listens. The app POSTs a turn to the `conversations`
function, which writes to Firestore under `users/{uid}/conversations/{cid}/messages/{mid}` and
queues the model call on a Cloud Tasks queue. The app subscribes to those documents and renders
whatever lands — it never writes them. Screenshots go to Cloud Storage under
`users/{uid}/conversations/{cid}/`, readable only by that uid.

Identity is anonymous Firebase Auth from first launch, upgraded in place with
`linkWithCredential` when someone signs in. There is no signed-out path to the API.

Contracts live with the app because that is where they are consumed:
`wizard-app/CONVERSATIONS.md` (flow, rules, indexes), `wizard-app/AI_INTEGRATION.md` (function
contracts, prompts, limits), `wizard-app/PROFILE_SYNC.md`, `wizard-app/LINES_THAT_LAND.md`.
Change a contract → change the doc in the same commit.

## Working agreements

These came from the project owner; treat them as standing instructions.

- **Simplicity wins.** Prefer the smaller change. Do not build a framework where a function
  will do, and do not mirror a server rule in the client by hand when one side can simply own it.
- **No global state in functions.** Every tunable is a Firebase param declared once in
  `wizard-backend/functions/config.py` and read at call time — never a module constant, never a
  value cached across requests.
- **The client owns payload size.** The app compresses screenshots before upload; the function's
  byte caps are a backstop against a tampered client, not a contract the app has to hit.
- **Soft delete only.** Closing a deal sets `active: false`; nothing deletes conversation data.
- **Pydantic, not dataclasses**, for every backend request/response model.
- Keep the feature docs above current; they are the only description of the wire format.

## Skills

Repeatable workflows live in `.claude/skills/`:

| Skill | Use it when |
|---|---|
| `local-stack` | Running the emulator suite and the app against it |
| `backend-endpoint` | Adding or changing a Cloud Function endpoint end to end |
| `app-feature` | Adding a feature slice to the Flutter app |
| `ship-check` | Before handing work back: what to analyze, test and build |

## Environment state (2026-09-18)

Known blockers an agent cannot fix from here — surface them, don't work around them:

- **Vertex AI is disabled in `wizard-app-dev`.** Generation returns 403 `SERVICE_DISABLED`
  until `aiplatform.googleapis.com` is enabled and the runtime service account has
  `roles/aiplatform.user`.
- **No deploy credentials.** The authenticated `firebase`/`gcloud` account has no access to
  `wizard-app-dev` (403 on `cloudresourcemanager`), so functions, rules and indexes cannot be
  deployed from this machine.
- Also still pending in the dev project: Anonymous Auth enabled, Firestore database created,
  Storage bucket created, the `uploads/` lifecycle rule, App Check (`REQUIRE_APP_CHECK`).
- **The iOS Simulator cannot transcribe speech.** Audio capture works, but
  `localspeechrecognition` has no model asset (`UAF_Siri_Understanding` is a stub), so
  `SFSpeechRecognizer` returns `error_assets_not_installed` (iOS 102) and the press-and-hold
  mic in `ProComposer` yields no words. Verify dictation on a real device.
- **iOS has no Push Notifications capability.** There is no `Runner.entitlements`, so nothing
  sets `aps-environment`: the paywall/onboarding permission prompt appears and is recorded, but
  APNs registration fails and FCM cannot deliver the trial reminder. Needs the capability added
  in Xcode plus an APNs key uploaded to Firebase.
