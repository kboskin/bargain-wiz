# Cloud Functions

Firebase Cloud Functions (2nd gen, Python 3.12) for the Bargain Wiz app, deployed from
`wizard-backend/` (`firebase.json`, `.firebaserc`).

| Function | Method | Purpose |
|---|---|---|
| `lines_that_land` | GET | Public negotiation lines for the Lines tab (Remote Config server template) |
| `express_dealmaker` | POST | Screenshots/text → three negotiation lines (Gemini on Vertex AI) |
| `pro_deal_closer` | POST | Chat coaching: reply or three lines (Gemini on Vertex AI) |
| `profile` | GET / PATCH | The user's profile document in Firestore (`users/{uid|inst_<id>}`), partial updates |

Contracts, prompting and app wiring for the AI functions: `wizard-app/AI_INTEGRATION.md`.
Profile schema and sync rules: `wizard-app/PROFILE_SYNC.md` (needs Firestore enabled in the
project; the runtime service account needs `roles/datastore.user`).
Layout follows the firebase-functions-python samples: `main.py` calls `initialize_app()`,
sets `options.set_global_options(...)` and defines one `@https_fn.on_request` function per
endpoint. Nothing is kept between requests: each function builds its collaborators
(`VertexGenerator()`, `FirestoreProfileStore()`, …) when it runs, and the Admin SDK caches its
own clients. Every tunable is an environment variable declared once in `config.py` (Firebase
params, values in `.env`) and read at call time; tests set them with `monkeypatch.setenv` and
swap the constructors `main` imports for fakes. `http_layer.py` has the JSON helpers and the
`@json_endpoint(methods=…)` decorator that maps the `errors.py` classes to statuses; `auth.py`
verifies Firebase ID tokens and App Check; `validation.py` holds the pydantic helpers.
Domain modules: `negotiation.py` (prompts, request models, result shaping), `vertex.py`
(google-genai client), `user_profile.py` (profile schema + Firestore merge),
`conversations.py` + `conversation_store.py` + `images.py` (backend-owned conversations),
`lines_that_land_service.py`, `markers.py` (DELETE / SERVER_TIME patch markers).
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

## `lines_that_land`

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
 "updated_at": "2026-09-12T10:00:00Z", "refresh_interval_hours": 24, "source": "remote_config"}
```

No query parameters: every locale is returned and the app picks the language. Errors are
`{"error": {"status": "METHOD_NOT_ALLOWED", "message": "…"}}` with the matching HTTP status. The response carries `Cache-Control: public, max-age=<interval>`
and `Last-Modified`. The app calls it with Dio (`GET {api_url}/lines_that_land`).

- Content is the **`lines_that_land_categories` parameter of the project's *server*
  Remote Config template**, read with the Admin SDK (`firebase_admin.remote_config`,
  `init_server_template` → `load()` → `evaluate()`). In the Firebase console open Remote
  Config, switch the **Client/Server** selector at the top to **Server**, and define the
  parameter there. Dev and prod each serve their own values; editing the parameter is
  still how content changes. The client template is no longer read by anything.
- Texts are multilocale maps; a plain string in the Remote Config value is treated as
  English. The built-in fallback content is fully translated to Spanish.
- `LINES_REFRESH_INTERVAL_HOURS` (`.env`, default 24) is *the* cadence: in-process cache TTL
  and the value the app uses for its own cache and its "new lines every …" caption. Change
  it there and redeploy.
- The built-in content is registered as the template's `default_config`, so if Remote
  Config is unreachable or the parameter is missing/unusable the function serves it with
  `source: "fallback"` and retries after 5 minutes. A warm instance keeps its last good
  content when a refresh fails.
- No sign-in is required: the content is public and the function is deployed with a
  public invoker.

Files: `main.py` (the callable), `lines_that_land_service.py` (Remote Config read via the
Admin SDK, text normalisation, per-instance cache), `tests/` (fake server template).

## `conversations`

Backend-owned deal conversations (design and security model: `wizard-app/CONVERSATIONS.md`).
The app writes through this function and reads with a Firestore listener; every write carries
a Firebase ID token (anonymous users included) and a client `request_id` for idempotency.

- Firestore: `users/{uid}/conversations/{cid}` + `messages/{mid}`; rules in
  `../firestore.rules` (owner read, no client writes). Screenshots are re-encoded with Pillow
  and stored in Cloud Storage under `users/{uid}/conversations/{cid}/`; rules in
  `../storage.rules`. Deploy both with `firebase deploy --only firestore:rules,storage`.
- Project setup: enable **Anonymous** sign-in in Authentication; create the Firestore
  database and the default Storage bucket (set `STORAGE_BUCKET` in `.env` if it is not the
  default one); add a Firestore **TTL policy** on `expires_at` for the `conversations`
  collection group; grant the runtime service account `roles/datastore.user` and
  `roles/storage.objectAdmin` on the bucket.
- Env (`.env`): `STORAGE_BUCKET`, `CONVERSATION_RETENTION_DAYS`, `MAX_TURNS_PER_DAY`,
  `MAX_MESSAGES_PER_CONVERSATION`, `IMAGE_MAX_SIDE`, `IMAGE_JPEG_QUALITY`, `REQUIRE_APP_CHECK`
  (false until the app ships App Attest / Play Integrity); full list in `config.py`.
- Routes: `POST /conversations` (the first turn opens the conversation; `type: express`
  returns the result inline), `POST /conversations/{cid}/messages`,
  `POST /conversations/{cid}/options`, `POST /conversations/{cid}/redo`,
  `PATCH|GET /conversations/{cid}`, `DELETE /conversations/{cid}` (soft delete: `active: false`,
  the TTL removes the data later), `GET /conversations` (active ones).
  409 while a reply is pending, 429 over the daily cap, 404 for anything not owned or archived.
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
