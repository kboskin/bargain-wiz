# Bargain Wiz — agent guide

Two projects in one folder, one git repo. **The git root is this folder (`bwiz/`)**, not
`wizard-app/`: run git from here, or `git -C ..` when your shell sits inside a project.

| Path | What it is | Guide |
|---|---|---|
| `wizard-app/` | Flutter client (iOS + Android) | [`wizard-app/AGENTS.md`](wizard-app/AGENTS.md) |
| `wizard-backend/` | Firebase project: Cloud Functions (Python 3.12), Firestore rules, indexes, Storage rules | [`wizard-backend/AGENTS.md`](wizard-backend/AGENTS.md) |
| `design_handoff_bargain_wiz/` | Design source of truth: tokens, prototype, Remote Config patch — git-ignored, so only on the owner's machine | `design_handoff_bargain_wiz/README.md` |
| `marketing/` | Owner's marketing worksheets (not for agents) | — |

## Product

Bargain Wiz is an AI negotiation coach for **buyers** on peer-to-peer marketplaces (Facebook
Marketplace, eBay, OLX, Craigslist, Amazon third-party sellers): the buyer drops a screenshot of
a listing or of the chat with the seller, or describes the deal, and the wizard hands back
ready-to-paste messages that get a better price, in the tone the buyer picked. Express
Dealmaker turns screenshots into three lines, Pro Deal Closer is a coached chat, Lines that land
is a generic library. Who it is for:

- **Dana, 29** — casual buyer, one to five second-hand items a month; knows haggling is normal
  but freezes when it is time to type the message; wants to sound confident, not pushy, and fast.
- **Marco, 35** — reseller, six or more deals a month; wants sharper, faster counters in a
  consistent tone, and uses history to reopen deals.
- **Priya, 22** — first-timer who never negotiated and worries about sounding rude; needs the
  friendliest tone and reassurance.

Free: Lines that land, History, Profile. Premium (monthly with a 3-day trial, or weekly):
Express and Pro. Voice: confident, short, a little cheeky ("Choose your magic", "Lines that
land"); Spanish copy is warm and informal (tú).

## Tech stack

Overview only — versions, commands and details live in each half's guide.

| Layer | What we use |
|---|---|
| Client | Flutter through `fvm` — BLoC/Cubit, GetIt, `dartz`, go_router, Dio ([`wizard-app/AGENTS.md`](wizard-app/AGENTS.md)) |
| Functions | Python 3.12, Cloud Functions 2nd gen, pydantic v2, async throughout ([`wizard-backend/AGENTS.md`](wizard-backend/AGENTS.md)) |
| Model | Gemini on Vertex AI when deployed, a local Ollama model in the emulator and tests, behind one `ModelManager`; schema-constrained JSON only |
| Async work | Cloud Tasks queue `generate` (also the project-wide rate limiter) + Cloud Scheduler job `refresh_lines` |
| Data | Firestore (profiles, conversations, generated Lines content), Cloud Storage (screenshots), Remote Config (every screen's template, `api_url`) |
| Identity | Firebase Auth, anonymous from first launch, upgraded in place (`linkWithCredential`) to Google / Apple; no signed-out path to the API. App Check: a server switch (`REQUIRE_APP_CHECK`, off), no client yet |
| Wire | Plain JSON over HTTPS `on_request` functions, Firebase ID token in `Authorization` — **not** callable functions |

Firebase project `wizard-app-dev` (`wizard-backend/.firebaserc`), everything in `us-central1`,
functions deployed as the codebase `lines-that-land` (`wizard-backend/firebase.json`).

## How the halves meet

The backend owns conversations; the app listens. The app POSTs a turn to the `conversations`
function, which writes to Firestore under `users/{uid}/conversations/{cid}/messages/{mid}` and
queues the model call. The app subscribes to those documents and renders whatever lands — it
never writes them. Screenshots go to Cloud Storage under `users/{uid}/conversations/{cid}/`,
readable only by that uid.

The contracts live with the app, where they are consumed, and are the only description of the
wire format: `wizard-app/CONVERSATIONS.md` (flow, identity, rules, indexes),
`wizard-app/AI_INTEGRATION.md` (function contracts, prompts, limits, errors),
`wizard-app/PROFILE_SYNC.md`, `wizard-app/LINES_THAT_LAND.md`. Change a contract → change its
doc in the same commit.

## Working agreements

These came from the project owner; treat them as standing instructions.

- **Simplicity wins.** Prefer the smaller change. Do not build a framework where a function
  will do, and do not mirror a server rule in the client by hand when one side can simply own it.
- **No global state in functions.** Every tunable is a Firebase param declared once, on the
  typed section that reads it in `wizard-backend/functions/core/config/settings.py`, and read
  at call time — never a module constant, never a value cached across requests. No
  module-level functions or state outside `main.py` either (`wizard-backend/AGENTS.md`).
- **The client owns payload size.** The app compresses screenshots before upload; the function's
  byte caps are a backstop against a tampered client, not a contract the app has to hit.
- **Soft delete only.** Closing a deal sets `active: false`; nothing deletes conversation data.
- **Pydantic, not dataclasses**, for every backend request/response model.

## Skills

Repeatable workflows live in `.claude/skills/`:

| Skill | Use it when |
|---|---|
| `local-stack` | Running the emulator suite and the app against it |
| `backend-endpoint` | Adding or changing a Cloud Function endpoint end to end |
| `app-feature` | Adding a feature slice to the Flutter app |
| `ship-check` | Before handing work back: what to analyze, test and build |
| `onboarding-screen` | Adding or changing an onboarding question, option or its prompt sentence in the Remote Config template |
| `illustration-asset` | New or replaced character art — plan cards, paywall steps, mascot variants — or wiring in an image or Lottie the owner supplies |

## Environment state

Known blockers an agent cannot fix from here — surface them, don't work around them:

- **Vertex AI is disabled in `wizard-app-dev`.** Generation returns 403 `SERVICE_DISABLED`
  until `aiplatform.googleapis.com` is enabled and the runtime service account has
  `roles/aiplatform.user`.
- **No deploy credentials.** The authenticated `firebase`/`gcloud` account has no access to
  `wizard-app-dev` (403 on `cloudresourcemanager`), so functions, rules and indexes cannot be
  deployed from this machine.
- Also still pending in the dev project: Anonymous Auth enabled, Firestore database created,
  Storage bucket created, the `uploads/` lifecycle rule. App Check needs the app side first: there
  is no `firebase_app_check` client, so turning `REQUIRE_APP_CHECK` on would reject every call.
- **The iOS Simulator cannot transcribe speech.** Audio capture works, but
  `localspeechrecognition` has no model asset (`UAF_Siri_Understanding` is a stub), so
  `SFSpeechRecognizer` returns `error_assets_not_installed` (iOS 102) and the press-and-hold
  mic in `ProComposer` yields no words. Verify dictation on a real device.
- **iOS push needs a paid Apple Developer account to finish.** The app side is wired
  (`ios/Runner/Runner.entitlements`, whose comment has the details); missing are the capability
  on the App ID, an APNs key in Firebase and `aps-environment: production` for an archive. Until
  then reminders cannot be delivered, and a **device** build fails to sign on a free team — drop
  `CODE_SIGN_ENTITLEMENTS` from the Runner configs if you need one before the account exists.
