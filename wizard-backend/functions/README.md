# Cloud Functions

Firebase Cloud Functions (2nd gen, Python 3.12) for the Bargain Wiz app, deployed from
`wizard-backend/` (`firebase.json`, `.firebaserc`).

| Function | Method | Purpose |
|---|---|---|
| `lines_that_land` | GET | Public negotiation lines for the Lines tab (Remote Config server template) |
| `express_dealmaker` | POST | Screenshots/text → three negotiation lines (Gemini on Vertex AI) |
| `pro_deal_closer` | POST | Chat coaching: reply or three lines (Gemini on Vertex AI) |
| `profile` | GET / PATCH | The user's profile document in Firestore (`users/{uid}`), partial updates |

Contracts, prompting and app wiring for the AI functions: `wizard-app/AI_INTEGRATION.md`.
Profile schema and sync rules: `wizard-app/PROFILE_SYNC.md` (needs Firestore enabled in the
project; the runtime service account needs `roles/datastore.user`).
`main.py` is the only file the Firebase CLI looks for: it calls `initialize_app()`, sets
`options.set_global_options(...)` and defines one `@https_fn.on_request` function per endpoint
— entry points and nothing else. Everything below it is a package, laid out in the same layers
as the Flutter app (`core/` plus `features/<name>/{domain,data,presentation}`); the map with
one line per module is in `../AGENTS.md`.

Nothing is kept between requests: each function builds its collaborators (`VertexGenerator()`,
`FirestoreProfileStore()`, …) when it runs, and the Admin SDK caches its own clients. Every
tunable is an environment variable declared once in `core/config.py` (Firebase params, values
in `.env`) and read at call time; tests set them with `monkeypatch.setenv` and swap the
constructors `main` imports for fakes. `core/http/endpoint.py` has the JSON helpers and the
`@json_endpoint(methods=…)` decorator that maps the `core/errors.py` classes to statuses;
`core/auth/firebase.py` verifies Firebase ID tokens and App Check; `core/validation.py` holds
the pydantic helpers.
Request bodies are **pydantic** models; validators raise `ValueError`, `validate_model` turns
the `ValidationError` into a 400 with a `field: message` list (ruff ignores TRY004 for that).

## AI functions

- Vertex AI API must be enabled; the runtime service account needs **Vertex AI User**
  (`roles/aiplatform.user`). Region and model: `VERTEX_LOCATION`, `VERTEX_MODEL` in `.env`.
- Public invoker; an `Authorization: Bearer <Firebase ID token>` header is optional (uid is
  logged when present, invalid tokens are rejected). Add App Check before scaling.
- Local run: `venv/bin/functions-framework --target=express_dealmaker --source=main.py --port=8089`,
  then POST `{"text": "Selling bike $300"}` to `http://localhost:8089/`. Uses your Application
  Default Credentials and their project for Vertex AI.

## `lines_that_land` and `refresh_lines`

The content is generated, not authored: `refresh_lines` is a `scheduler_fn.on_schedule`
function that runs every `LINES_REFRESH_INTERVAL_HOURS`, asks Gemini for the categories with
structured output (the `GeneratedLines` pydantic model as the response schema, the same
generator as the chat) and writes them to Firestore at `content/lines_that_land`. The HTTP
endpoint serves that document and falls back to the bundled categories until a generation
lands, so the tab always has content. A failed
run changes nothing and the next run retries. The schedule string is fixed at deploy time, so
changing the interval needs a redeploy. Trigger a run by hand from the Emulator UI locally, or
`gcloud scheduler jobs run firebase-schedule-refresh_lines-us-central1` once deployed.

A plain HTTPS function (https://firebase.google.com/docs/functions/http-events), GET only,
no body, public:

```bash
curl -s https://us-central1-<project>.cloudfunctions.net/lines_that_land
```

```json
{"categories": [{"id": "opening",
                 "name": {"en": "Opening lines", "es": "Frases de apertura"},
                 "tips": [{"en": "Is there flexibility on the price?",
                           "es": "¿Hay flexibilidad en el precio?"}]}],
 "locales": ["en", "es"],
 "updated_at": "2026-09-12T10:00:00Z", "refresh_interval_hours": 24, "source": "generated"}
```

No query parameters: every locale is returned and the app picks the language. Errors are
`{"error": {"status": "METHOD_NOT_ALLOWED", "message": "…"}}` with the matching HTTP status. The response carries `Cache-Control: public, max-age=<interval>`
and `Last-Modified`. The app calls it with Dio (`GET {api_url}/lines_that_land`).

- **`GeneratedLines` is the whole contract.** The pydantic models in
  `features/lines_that_land/domain/content.py` are the response schema Gemini is constrained
  to, the validation of what comes back, the shape stored in Firestore and the shape served,
  and every `Field(description=…)` is prompt as much as documentation. Nothing normalises or
  reshapes the answer afterwards.
- **What to generate is configuration, not code.** Five params in `.env`, all read per call:
  `LINES_CATEGORY_IDS` (default `opening,followup,closing`), `LINES_PER_CATEGORY` (5),
  `LINES_LOCALES` (`en,es`), `LINES_SYSTEM_PROMPT` and `LINES_TASK_PROMPT`. The first three
  are written into the schema when the SDK builds it — the ids as the `enum` of `id`, the
  locales as the required properties of every text — so Gemini cannot answer with a category
  or a language that was not asked for. The same three values fill `{categories}`, `{count}`,
  `{lines_per_category}` and `{locales}` in the task prompt, so the prompt and the schema
  cannot drift apart. Params are baked in at deploy time: editing a prompt needs a redeploy.
- **The models stay lenient on purpose.** A `Category` only needs an id and a text in at
  least one language, so the bundled fallback and documents written under an older
  `LINES_LOCALES` keep rendering after the config changes. What a *generation* must contain
  is the schema's job, not the model's.
- `locales` in the response is what the content actually has (`locales_of`), not what the
  param asks for — they differ while the fallback is being served.
- `LINES_REFRESH_INTERVAL_HOURS` (`.env`, default 24) is *the* cadence: the schedule, the
  `Cache-Control` max-age, and the value the app uses for its own cache and its "new lines
  every …" caption. Change it there and redeploy.
- The bundled `FALLBACK_CATEGORIES` are served with `source: "fallback"` until the first
  generation lands, and whenever the stored document cannot be read or no longer fits the
  model — the tab never fails, it just shows the older content.
- Remote Config has no part in this any more: the `lines_that_land_categories` parameter is
  dead and the client template is not read by anything.
- No sign-in is required: the content is public and the function is deployed with a
  public invoker.

Files: `main.py` (the endpoint and the schedule), `features/lines_that_land/domain/`
(`content.py`: the models, the fallback and `current()`; `generation.py`: the prompt and the
call), `features/lines_that_land/data/store.py` (the Firestore document),
`core/ai/vertex.py` (`generate(response_model=…)`), `tests/test_lines_that_land.py`.

## `conversations`

Backend-owned deal conversations (design and security model: `wizard-app/CONVERSATIONS.md`).
The app writes through this function and reads with a Firestore listener; every write carries
a Firebase ID token (anonymous users included). Writes carry no client key: `active_turn`
already limits a conversation to one outstanding turn, and `pending_options` does the same for
"Give me options", so the server's own state is the guard against a double submit.

- Firestore: `users/{uid}/conversations/{cid}` + `messages/{mid}`; rules in
  `../firestore.rules` (owner read, no client writes). Screenshots are re-encoded with Pillow
  and stored in Cloud Storage under `users/{uid}/conversations/{cid}/`; rules in
  `../storage.rules`. Deploy both with `firebase deploy --only firestore:rules,storage`.
- Project setup: enable **Anonymous** sign-in in Authentication; create the Firestore
  database and the default Storage bucket (set `STORAGE_BUCKET` in `.env` if it is not the
  default one); add the `uploads/` bucket lifecycle rule (CONVERSATIONS.md §8); grant the
  runtime service account `roles/datastore.user` and `roles/storage.objectAdmin` on the
  bucket. No Firestore TTL policy: nothing expires, see CONVERSATIONS.md §7.
- Env (`.env`): `STORAGE_BUCKET`, `MAX_MESSAGES_PER_CONVERSATION`,
  `QUEUE_MAX_DISPATCHES_PER_SECOND`, `QUEUE_MAX_CONCURRENT_DISPATCHES`, `QUEUE_MAX_ATTEMPTS`,
  `IMAGE_MAX_SIDE`, `IMAGE_JPEG_QUALITY`, `REQUIRE_APP_CHECK` (false until the app ships App
  Attest / Play Integrity); full list in `core/config.py`.
- Generation is queued: a write stores the turn plus a `pending` wizard placeholder and
  enqueues the `generate` task-queue function, whose `RateLimits` (`QUEUE_MAX_*` in `.env`)
  are the rate limiter — project-wide, not per user — and whose `RetryConfig` retries a
  failed call; only the last attempt
  marks the message `failed`. Responses carry ids only — every answer arrives through the
  app's Firestore listener. Locally, without a Cloud Tasks emulator, generation runs inline.
- Routes: `POST /conversations` (the first turn opens the conversation),
  `POST /conversations/{cid}/messages`,
  `POST /conversations/{cid}/options`, `POST /conversations/{cid}/redo`,
  `PATCH|GET /conversations/{cid}`, `DELETE /conversations/{cid}` (soft delete: `active: false`,
  the data stays), `GET /conversations` (active ones).
  409 while a reply is pending, 404 for anything not owned or archived.
- The history query needs the composite index in `../firestore.indexes.json`
  (`active` + `updated_at`), deployed with `firebase deploy --only firestore`.

## Local development

Emulators (Auth, Functions, Firestore, Storage, UI on http://127.0.0.1:4000) from `wizard-backend/`:

```bash
firebase emulators:start
```

The Functions emulator runs `functions/venv/bin/python`, so create the venv first (below) and
keep `functions/.env` valid: keys must be `UPPER_SNAKE_CASE` and must not use the CLI's
reserved names (`FUNCTION_*`, `FIREBASE_*`, `GCLOUD_PROJECT`, `PORT`, …). Vertex AI calls go
to the real project with your Application Default Credentials; Firestore, Storage and Auth
stay local. To run the manifest discovery by hand (what the emulator does on start):

```bash
cd functions && set -a && source .env && set +a
GCLOUD_PROJECT=wizard-app-dev venv/bin/python -c "from firebase_functions.private.serving import *; print(functions_as_yaml(get_functions()))"
```


```bash
cd wizard-backend/functions
uv venv venv --python 3.12                       # or: python3.12 -m venv venv
uv pip install --python venv/bin/python -r requirements-dev.txt
venv/bin/python -m pytest -q

# Run the function locally
venv/bin/functions-framework --target=lines_that_land --source=main.py --port=8089
curl -s http://localhost:8089/
# or the Firebase emulator, from wizard-backend/:
firebase emulators:start --only functions
```

The Firebase CLI expects the virtualenv at `functions/venv` for Python deploys.

## Deploy

```bash
cd wizard-backend
firebase deploy --only functions:lines_that_land --project wizard-app-dev
```

Requirements on the project:

- Billing (Blaze) enabled; Cloud Functions, Cloud Build, Artifact Registry and Cloud Run APIs
  (the first deploy enables them).
- The Admin SDK uses the function's Application Default Credentials. Its runtime service
  account needs read access to Remote Config: grant **Firebase Remote Config Viewer**
  (`roles/cloudconfig.viewer`). Without it, or before the server parameter exists, the
  function serves the built-in fallback (the log says why).
- The function is public (`invoker="public"`); the content is not sensitive.
