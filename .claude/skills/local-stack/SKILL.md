---
name: local-stack
description: Run the Firebase emulator suite and the Flutter app against it (the `local` flavor). Use when testing end to end on this machine, reproducing a backend bug from the app, or when the user mentions emulators, the local flavor, or 10.0.2.2.
---

# Local stack

Two halves: the emulator suite from `wizard-backend/`, the app on the `local` flavor from
`wizard-app/`. Start the emulators first — the app retries anonymous sign-in every 5s, so it
recovers on its own if it wins the race. (That retry only covers *no* user; a user already on
disk that the emulator does not know is a dead end the app cannot fix — see Troubleshooting.)

## 1. Emulators

```bash
cd wizard-backend && firebase emulators:start --import=.emulator-data --export-on-exit
```

**Always pass `--import`/`--export-on-exit`.** Without them the Auth emulator starts empty on
every run, so the anonymous user the app holds on disk stops existing server-side (the
directory is git-ignored; it does not have to exist the first time).

| Service | Port |
|---|---|
| Emulator UI | 4000 |
| Functions | 5001 |
| Firestore | 8080 |
| Auth | 9099 |
| Storage | 9199 |

The functions codebase (`lines-that-land`) runs from `functions/venv`. If startup fails with
"Failed to load environment variables from .env", a key in `functions/.env` is reserved — the
CLI rejects `FIREBASE_*` and names like `FUNCTION_MEMORY_MB`; rename it (see
`wizard-backend/AGENTS.md`).

**No Cloud Tasks emulator runs by default.** `main._dispatcher()` notices and generates
inline, so conversations still work locally; queue rate limits and retries are simply not
exercised. Set `CLOUD_TASKS_EMULATOR_HOST` only if you actually start one.

**Scheduled functions are not reachable over HTTP in the emulator.** Trigger `refresh_lines`
from the Emulator UI at http://localhost:4000, not with curl.

**The model is the one thing not emulated.** By default the functions still call real Vertex
AI. To keep it local, run Ollama with a multimodal model and switch the emulator to it in
`functions/.env.local` (read over `.env` for the emulator only, never deployed, git-ignored):

```bash
ollama pull qwen2.5vl:7b          # any multimodal tag; text-only models reject screenshots
# functions/.env.local
AI_MODEL=ollama/qwen2.5vl:7b
REQUEST_TIMEOUT_SEC=300           # local models are slower, and the first call loads the model
```

Restart the emulators to pick it up. The function log shows one `model_call` metric line per call.
Without a Cloud Tasks emulator generation runs inline, so a conversation POST waits for the
model and the app gives up after its 70 s POST timeout — pick a model that answers faster.

## 2. App

```bash
cd wizard-app && fvm flutter run --flavor local -t lib/main.dart
```

Expect these lines in the log:

```
[INFO] Local flavor: Firebase emulators at 10.0.2.2 (auth 9099, firestore 8080, storage 9199, functions 5001)
[INFO] Signed in anonymously (<uid>)
```

Host per platform: Android emulator `10.0.2.2`, iOS simulator `127.0.0.1` — handled by
`lib/core/config/app_config.dart`.

## Troubleshooting

- **"Cleartext HTTP traffic to 10.0.2.2 not permitted"** — the build is not a debug build, or
  you passed a different `--flavor` than `local`. Cleartext is allowed only through
  `android/app/src/debug/res/xml/network_security_config.xml`.
- **Anonymous sign-in keeps failing** — emulators are not up, or the app is on `dev`/`prod`
  while you expected `local`. Check the "Local flavor" line above.
- **`Could not get an ID token: [firebase_auth/internal-error]`, then HTTP 401 `Sign in
  required`** — the session on disk was issued by someone else: the dev project (`dev` and
  `local` share the applicationId `com.bargain.wiz.dev`, hence one session store) or an
  earlier emulator run started without `--import`. The `local` flavor detects it at startup
  and prints an `[ERROR] … the Auth emulator does not know the session on this device` line;
  it does not sign out on its own (that would mint a new uid on every wipe), so clear the
  install once with `adb shell pm clear com.bargain.wiz.dev`. Tell-tale sign on the server: no Auth
  user at all, but a `users/inst_<uuid>` document — the `profile` function accepts
  unauthenticated callers and keys them by `installation_id`, while `conversations` does not.
- **Generation fails with 403 `SERVICE_DISABLED`** — the emulator still calls real Vertex AI,
  which is disabled in `wizard-app-dev`. That is an environment blocker, not a code bug; use
  the Ollama switch above to test locally.
- **`Ollama call failed: HTTP 404 … not found`** — the model in `AI_MODEL` is not pulled.
  **HTTP 400 "does not support multimodal requests"** — it is text-only and the turn had a
  screenshot. **"did not answer"** — `ollama serve` is not running, or `OLLAMA_URL` is wrong.
- Ports already bound: another emulator run is alive. Stop it rather than changing ports.
