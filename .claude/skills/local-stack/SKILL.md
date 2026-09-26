---
name: local-stack
description: Run the Firebase emulator suite and the Flutter app against it (the `local` flavor). Use when testing end to end on this machine, reproducing a backend bug from the app, or when the user mentions emulators, the local flavor, or 10.0.2.2.
---

# Local stack

Two halves: the emulator suite from `wizard-backend/`, the app on the `local` flavor from
`wizard-app/`. Start the emulators first: boot waits for the anonymous sign-in, and if the
emulators are not up yet the splash stays with tap-to-retry — it does not retry on its own. (A
user already on disk that the emulator does not know is a different dead end — see
Troubleshooting.)

## 1. Emulators

```bash
cd wizard-backend && firebase emulators:start --import=.emulator-data --export-on-exit
```

**Always pass `--import`/`--export-on-exit`.** Without them the Auth emulator starts empty on
every run, so the anonymous user the app holds on disk stops existing server-side (the
directory is git-ignored; it does not have to exist the first time).

Ports (`firebase.json`): UI 4000, Functions 5001, Firestore 8080, Auth 9099, Storage 9199. The
functions run from `functions/venv`. "Failed to load environment variables from .env" means a
reserved key in `functions/.env` — see the naming rule in `wizard-backend/AGENTS.md` Toolchain.

**The queue.** The CLI starts a Cloud Tasks emulator for the `generate` queue with the
functions (`tasks`, port 9499, in `curl -s localhost:4400/emulators`), so a turn is queued as in
the cloud. (An old CLI without one makes `RuntimeEnvironment.queues_inline` run the worker inside
the request: the POST then waits for the model, and the app gives up after its 70 s timeout.)

**`refresh_lines` does not run in the emulator.** The CLI emulates a schedule as a Pub/Sub
trigger, `firebase.json` configures no Pub/Sub emulator, so the function is skipped ("function
ignored because the pubsub emulator does not exist") — and the Emulator UI has no button to
run one anyway. Exercise the generation through `tests/test_lines_that_land.py`; the tab serves
the stored or bundled lines meanwhile.

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

## 2. Backend end to end

With the suite up, `tests/test_e2e.py` drives the real functions the way the app does — an
anonymous Auth-emulator user, a Pro deal (reply, options, redo, follow-up), an Express deal,
the history list, the profile, the Lines tab — and checks the documents the listener would see
(`usage`, image refs, `seq`, `active_turn`). It is opt-in:

```bash
cd wizard-backend/functions
E2E=1 venv/bin/python -m pytest tests/test_e2e.py -rs      # ~1–3 min with qwen2.5vl:7b
```

**Restart the emulators after changing backend code**: the Python functions are loaded when
the suite starts, so an old suite runs old code. Each run signs up a fresh anonymous user, so
its data stays under that uid (browse it in the Emulator UI). `E2E_TIMEOUT_SEC` (default 300)
bounds each wait for the model; a failed generation fails the test at once with the error the
backend recorded.

## 3. App

```bash
cd wizard-app && fvm flutter run --flavor local --dart-define=FLAVOR=local -t lib/main.dart
```

Both switches are needed — without the define the app runs as `prod` and never touches the
emulators ("Flavors" in `wizard-app/AGENTS.md`: hosts per platform, cleartext, the shared
Android id).

Expect these lines in the log:

```
[INFO] Local flavor: Firebase emulators at 10.0.2.2 (auth 9099, firestore 8080, storage 9199, functions 5001)
[INFO] Signed in anonymously (<uid>)
```


## Troubleshooting

- **"Cleartext HTTP traffic to 10.0.2.2 not permitted"** — a release or profile build with a
  `--flavor` other than `local`. Cleartext is allowed in every debug build
  (`android/app/src/debug/res/xml/network_security_config.xml`) and in any `local` build
  (`android/app/src/local/AndroidManifest.xml`).
- **Anonymous sign-in keeps failing** — emulators are not up, or the app is on `dev`/`prod`
  while you expected `local` (usually a missing `--dart-define=FLAVOR=local`). Check the "Local
  flavor" line above.
- **`Could not get an ID token: [firebase_auth/internal-error]`, then HTTP 401 `Sign in
  required`** — the session on disk was issued by someone else: the dev project (`dev` and
  `local` share the applicationId `com.bargain.wiz.dev`, hence one session store) or an
  earlier emulator run started without `--import`. The `local` flavor detects it at startup
  and prints an `[ERROR] … the Auth emulator does not know the session on this device` line;
  it does not sign out on its own (that would mint a new uid on every wipe), so clear the
  install once with `adb shell pm clear com.bargain.wiz.dev`. Every endpoint the app calls,
  `profile` included, answers such a request with 401.
- **Generation fails with 403 `SERVICE_DISABLED`** — the emulator still calls real Vertex AI,
  which is disabled in `wizard-app-dev`. That is an environment blocker, not a code bug; use
  the Ollama switch above to test locally.
- **`Ollama call failed: HTTP 404 … not found`** — the model in `AI_MODEL` is not pulled.
  **HTTP 400 "does not support multimodal requests"** — it is text-only and the turn had a
  screenshot. **"did not answer"** — `ollama serve` is not running, or `OLLAMA_URL` is wrong.
- Ports already bound: another emulator run is alive. Stop it rather than changing ports.
