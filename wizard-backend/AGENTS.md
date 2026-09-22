# wizard-backend — agent guide

Firebase project for Bargain Wiz: Cloud Functions (2nd gen, Python 3.12), Firestore rules and
indexes, Storage rules. Repo-wide conventions: `../AGENTS.md`. Endpoint-by-endpoint reference:
`functions/README.md`.

## Tech stack

| Concern | What we use |
|---|---|
| Runtime | Python **3.12** on Cloud Functions **2nd gen** (`firebase-functions` ≥0.4) — `on_request`, `on_task_dispatched`, `on_schedule`; region `us-central1`, codebase `lines-that-land` |
| Admin access | `firebase-admin` ≥6.6 — Firestore, Cloud Storage, Auth / App Check token verification (`initialize_app()` once in `main.py`) |
| Validation | **pydantic v2** for every request/response model; no dataclasses |
| Model | `google-genai` ≥1.0 against **Vertex AI** (`genai.Client(vertexai=True, …)`), default `gemini-3.8-flash`, `response_mime_type=application/json` + `response_schema`; Gemini 3 settings from `.env`: `VERTEX_THINKING_LEVEL=low` (3.x Flash cannot switch thinking off), `VERTEX_MEDIA_RESOLUTION=high` (1,120 tokens per screenshot), temperature left at 1.0. Every call logs `gemini usage …` with prompt / cached / output / thought token counts |
| Images | Pillow — server-side re-encode to JPEG (`IMAGE_MAX_SIDE` 1600, quality 85) before upload |
| Async | Cloud Tasks queue `generate` (`RateLimits` + `RetryConfig` = the rate limiter and retry policy) and a Cloud Scheduler `refresh_lines` job |
| Config | `firebase_functions.params` (`StringParam`/`IntParam`/`BoolParam`) in `config.py`, values from `functions/.env` |
| Tests / lint | `pytest` ≥8 (`tests/`, `pythonpath=["."]`), `ruff` ≥0.5 (line length 100, target py312) |
| Local | Firebase CLI emulator suite — auth 9099, firestore 8080, functions 5001, storage 9199, UI 4000 (`firebase.json`, `singleProjectMode`) |

No web framework, no ORM, no DI container: a function builds its collaborators and returns a
dict that `@json_endpoint` serialises.

## Toolchain

Everything runs from `wizard-backend/functions/` with the local virtualenv (`functions/venv`,
created with `uv venv venv --python 3.12` or `python3.12 -m venv venv`, then
`uv pip install --python venv/bin/python -r requirements-dev.txt`):

```bash
venv/bin/python -m pytest -q          # tests/ — fast, no emulator needed
venv/bin/ruff check .                 # line-length 100, target py312
venv/bin/ruff format .
cd .. && firebase emulators:start --import=.emulator-data --export-on-exit   # see the local-stack skill
```

`pyproject.toml` ignores `TRY004`: pydantic turns a `ValueError` raised in a validator into a
400-able `ValidationError`, so type checks in validators raise `ValueError`, not `TypeError`.

## Shape of the code

`main.py` holds **entry points only** — `initialize_app()`, `options.set_global_options(...)`,
one `@https_fn.on_request` + `@json_endpoint(...)` per endpoint, the `@tasks_fn.on_task_dispatched`
worker and the `@scheduler_fn.on_schedule` job. It builds collaborators per call
(`conversation_service()`, `VertexGenerator()`, …) and keeps nothing between requests. It stays
at the root of `functions/` because that is where the Firebase CLI looks for it; everything else
lives in a package.

Below it, the same layering as the Flutter app: `core/` is what every feature may use, and each
feature is split into the three layers.

| Layer | Holds | May import |
|---|---|---|
| `presentation` | Request body → model, sub-path routing. The HTTP edge of a feature. | its own domain, `core` |
| `domain` | Models, rules, prompts, the service that runs a use case, and the `Protocol`s it needs from the outside (`ports.py`). Pure Python, no SDK calls. | `core`, another feature's domain |
| `data` | The implementations of those ports: Firestore, Cloud Storage, Cloud Tasks, the in-memory doubles. | its own domain, `core` |

```
functions/
  main.py                     entry points only
  core/
    config.py                 every tunable, as a Firebase param; values in .env
    errors.py                 the error classes endpoints raise (→ HTTP status)
    validation.py             shared pydantic helpers (validate_model, trimmed, …)
    serialization.py          jsonable(): Firestore values → JSON body
    firestore.py              DELETE / SERVER_TIME patch markers and their translation
    runtime.py                the project id the runtime was given
    http/endpoint.py          JSON helpers, @json_endpoint(methods=…), error → status
    auth/firebase.py          Firebase ID token + App Check verification
    ai/vertex.py              google-genai client; generate(response_model=…) / generate_json
    storage/images.py         screenshot re-encode + Cloud Storage upload
  features/
    negotiation/              express_dealmaker + pro_deal_closer, and the prompts both use
      domain/models.py        Profile, Image, ExpressRequest, ProRequest
      domain/prompts.py       tone/push/marketplace tables → system prompt and parts
      domain/lines.py         response schemas and what we keep of an answer
      presentation/requests.py  body → model, pydantic errors → 400
    conversations/
      domain/models.py        the write bodies, the queue payload, SCHEMA_VERSION
      domain/ports.py         ConversationStore / Dispatcher, what the service needs
      domain/service.py       ConversationService: create/send/options/redo/patch/archive, the worker
      data/store.py           Firestore + Cloud Storage reads/writes, in-memory double
      data/dispatchers.py     Cloud Tasks queue, and the inline one for the emulator
      presentation/routes.py  sub-path → service call
    lines_that_land/
      domain/content.py       the content models = the response schema; fallback; current()
      domain/generation.py    fills the prompt params and makes the one model call
      data/store.py           content/lines_that_land, in-memory double
    profile/
      domain/profile.py       sections, patch validation, merge rules, Identity
      data/store.py           users/{uid}, in-memory double
  tests/                      flat, one file per feature; no emulator needed
```

Adding an endpoint: the `backend-endpoint` skill walks the whole path.

## Rules an agent must not quietly break

- **No global state, no module constants for tunables.** A new knob is a param in `config.py`
  plus a line in `.env`, read as `config.X.value` at call time.
- **Pydantic for every request body.** Validators raise `ValueError`; `validate_model` turns
  that into a 400 with `field: message`.
- **Reserved `.env` keys.** The Firebase CLI rejects the whole file if it sees keys like
  `FUNCTION_MEMORY_MB` or anything `FIREBASE_*`-prefixed — that is why the instance knobs are
  `INSTANCE_MEMORY_MB`, `REQUEST_TIMEOUT_SEC`, `MAX_INSTANCES`.
- **Enqueue task payloads wrapped.** The Python Admin SDK sends the body verbatim, while
  `on_task_dispatched` reads `json.loads(request.data)["data"]`. Enqueue
  `{"data": task.model_dump(mode="json")}` or every task is rejected as "Invalid request".
- **Rate limiting is the queue.** `options.RateLimits` + `RetryConfig` on the `generate`
  worker (`QUEUE_*` in `.env`), not a per-user bucket in application code.
- **Conversations are soft-deleted** (`active: false`) and nothing expires: there is no TTL
  policy and no expiry field. Retention, when it is wanted, hangs off `created_at` /
  `last_message_at`. Nothing deletes user content.
- **Image byte caps are a backstop.** The app compresses before upload; keep the server
  numbers comfortably above what the client produces.
- The schedule string of `refresh_lines` is fixed at deploy time, so changing
  `LINES_REFRESH_INTERVAL_HOURS` needs a redeploy.

## Data layout

```
users/{uid}                                  profile fields
users/{uid}/conversations/{cid}              active, type, created_at, updated_at, …
users/{uid}/conversations/{cid}/messages/{mid}
content/lines_that_land                      generated Lines content
```

Storage: `users/{uid}/conversations/{cid}/*.jpg`, readable only by that uid.
Rules: `firestore.rules`, `storage.rules`. Indexes: `firestore.indexes.json`
(composite `active` + `updated_at` — add one whenever a new query needs it).

## Deploy

```bash
firebase deploy --only functions
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Blocked today: the authenticated account has no access to `wizard-app-dev`, and Vertex AI is
disabled in that project. See "Environment state" in `../AGENTS.md`.
