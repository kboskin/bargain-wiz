# wizard-backend — agent guide

Firebase project for Bargain Wiz: Cloud Functions (2nd gen, Python 3.12), Firestore rules and
indexes, Storage rules. Repo-wide conventions: `../AGENTS.md`. Endpoint-by-endpoint reference:
`functions/README.md`.

## Tech stack

| Concern | What we use |
|---|---|
| Runtime | Python **3.12** on Cloud Functions **2nd gen** (`firebase-functions` ≥0.4) — `on_request`, `on_task_dispatched`, `on_schedule`; region `us-central1`, codebase `lines-that-land` |
| Admin access | `firebase-admin` ≥6.6 — the default app and its credentials (`initialize_app()` once in `main.py`), Cloud Storage, Auth / App Check token verification, Cloud Tasks; Firestore through `google-cloud-firestore`'s `AsyncClient`, one per invocation (`core/firestore.py`) |
| Validation | **pydantic v2** for every request, response, answer, settings and document model; no dataclasses |
| Model | `ModelManager` (`core/ai/manager.py`) in front of one `ModelProvider` per API, chosen by `AI_MODEL=<provider>/<model>`: `vertex/gemini-3.8-flash` (the `google-genai` SDK against **Vertex AI**) in the cloud, `ollama/qwen2.5vl:7b` (a local model) in the emulator and the tests. Output is always constrained to a pydantic answer model's JSON schema and validated against it |
| Images | Pillow — server-side re-encode to JPEG (`IMAGE_MAX_SIDE` 1600, quality 85) before upload |
| Concurrency | `async` from the entry point down: each invocation runs on an event loop of its own (`asyncio.run` in `main.py`, because Firebase calls Python functions synchronously). Native async clients, one per invocation: Firestore's `AsyncClient`, google-genai's `client.aio`, `httpx.AsyncClient`. `asyncio.to_thread` only where no async SDK exists (Cloud Storage, Auth / App Check verification, the Cloud Tasks enqueue) and for Pillow; `asyncio.gather` for independent I/O |
| Background work | Cloud Tasks queue `generate` (`RateLimits` + `RetryConfig` = the rate limiter and retry policy) and a Cloud Scheduler `refresh_lines` job |
| Config | Every environment variable is declared once, on the typed section that reads it (`core/config/settings.py`, `FromEnv(params.XParam(...))`); values from `functions/.env`, with `functions/.env.local` (git-ignored) over it in the emulator |
| Observability | A `Telemetry` per invocation: structured JSON logs for Cloud Logging with the function and the request's trace on every line, and metrics as log entries (`model_call`, `http_request`, `generation`, `lines_refresh`) for log-based metrics |
| Tests / lint | `pytest` ≥8 (`tests/`, `pythonpath=["."]`), `ruff` ≥0.5 (line length 100, target py312) |
| Local | Firebase CLI emulator suite — auth 9099, firestore 8080, functions 5001, storage 9199, UI 4000 (`firebase.json`, `singleProjectMode`); Ollama on 11434 for the model |

No web framework and no ORM. `container.py` is the composition root: one `Container` per
invocation holds the `CoreServices` (`core/services.py`) and one module per feature
(`features/<name>/module.py`), each building its collaborators on first use — the same shape
as the app's GetIt container calling each feature's `di.dart`.

## Toolchain

Everything runs from `wizard-backend/functions/` with the local virtualenv (`functions/venv`,
created with `uv venv venv --python 3.12` or `python3.12 -m venv venv`, then
`uv pip install --python venv/bin/python -r requirements-dev.txt`):

```bash
venv/bin/python -m pytest -q -rs      # tests/ — no emulator; model tests need Ollama (below)
venv/bin/ruff check .                 # line-length 100, target py312
venv/bin/ruff format .
cd .. && firebase emulators:start --import=.emulator-data --export-on-exit   # see the local-stack skill
```

**Tests never fake the model.** A test that needs an answer asks the local model through the
real Ollama provider and is skipped — with the `ollama pull …` that fixes it — when Ollama or
the model is missing (`-rs` shows why). `TEST_AI_MODEL` picks the model (default
`ollama/qwen2.5vl:7b`; it must be multimodal for the screenshot tests). Failure paths aim the
same provider at a closed port and need nothing running. Every other test asks no model and
takes about two seconds.

Tests call a coroutine with `asyncio.run(...)` (no pytest plugin); the in-memory doubles in
`tests/support/` implement the async ports and keep plain methods beside them (`seed_*`,
`conversation`, `doc`, …) for arranging and inspecting state. `pyproject.toml` turns
`RuntimeWarning` into an error, so a forgotten `await` fails the test that hit it.

`pyproject.toml` ignores `TRY004`: pydantic turns a `ValueError` raised in a validator into a
400-able `ValidationError`, so type checks in validators raise `ValueError`, not `TypeError`.

## Shape of the code

`main.py` holds **entry points only**: process setup (`initialize_app()`,
`LoggingSetup.configure(...)`, `options.set_global_options(...)`) and one function per
endpoint that makes a `Container` for its invocation (`Container.for_request` /
`for_background`) and runs it with `asyncio.run(app.serve(...))` (HTTP) or
`asyncio.run(app.run(...))` (queue, schedule). `serve` hands the request to the controller
inside a `JsonEndpoint` (method check, error → status, `http_request` metric); both close what
the invocation opened (`Container.aclose`) before its event loop ends. The decorators take the params
themselves (`RuntimeSettings.param("timeout_sec")`, …), so the deploy manifest carries them.
The Firebase CLI discovers functions as decorated module-level callables, so `main.py` is the
one module that has any; `main.py` and `container.py` stay at the root of `functions/` because
that is where the CLI looks, and everything else lives in a package.

Below them, the same layering as the Flutter app: `core/` is what every feature may use, and
each feature is split into three layers.

| Layer | Holds | May import |
|---|---|---|
| `presentation` | The controller: auth, body → model, sub-path routing, the response. The HTTP edge of a feature. | its own domain, `core` |
| `domain` | Models, rules, prompts, the services that run a use case, and the `Protocol`s they need from the outside (`ports.py`). No SDK calls. | `core`, another feature's domain |
| `data` | The implementations of those ports: Firestore, Cloud Storage, Cloud Tasks. (The tests' in-memory ones live in `tests/support/`.) | its own domain, `core` |

Every class takes its collaborators and settings in its constructor; only a feature's
`module.py` (and `core/services.py` for the shared ones) decides which implementation is used.
Where behaviour varies by kind, it is a class per kind behind an abstraction: one
`ModelProvider` per model API, one `Generation` per kind of queued generation (reply, Express
answer, options), one `MetricEvent` per metric.

```
functions/
  main.py                       entry points only
  container.py                  Container: CoreServices + one module per feature, one per invocation
  core/
    config/settings.py          every environment variable, on its typed section (ModelSettings, …)
    services.py                 CoreServices: runtime, clock, telemetry, auth, bucket, model, endpoint
    ai/manager.py               ModelManager: provider from AI_MODEL, validation, metrics
    ai/images.py                StoredImageInliner: gs:// screenshots → bytes for providers that need them
    ai/provider.py              ModelProvider: the contract every model API implements
    ai/providers/vertex.py      Gemini on Vertex AI (google-genai)
    ai/providers/ollama.py      a local model through Ollama's /api/chat
    ai/providers/registry.py    ProviderRegistry: AI_MODEL's prefix → provider class
    ai/types.py                 Prompt, TextPart, ImagePart, Completion, TokenUsage
    observability/              Telemetry (per invocation), StructuredLogger, MetricEvent subclasses, Invocation
    http/endpoint.py            JsonEndpoint + JSON helpers
    auth/firebase.py            Authenticator: Firebase ID token + App Check
    storage/cloud.py            CloudStorage (the bucket) and BlobReader (gs:// → bytes)
    storage/images.py           ImageProcessor: screenshot re-encode
    errors.py                   ApiError hierarchy (→ HTTP status); ConfigError, ModelCallFailed, InvalidModelAnswer
    firestore.py                FirestoreConnection (the invocation's AsyncClient), FirestoreDocument,
                                Patch, FieldOp (DELETE / SERVER_TIME), FirestorePatch (→ SDK data)
    utils/                      helpers every layer may use: Text, Validation (→ 400), JsonValue,
                                GcsUri, Clock, EnvValue, RuntimeEnvironment
  features/
    negotiation/                express_dealmaker + pro_deal_closer, and what both they and the worker ask
      module.py                 NegotiationModule: prompts, service, controller
      domain/models.py          Profile, Image, StoredImage, ExpressRequest, ProRequest
      domain/answers.py         ExpressAnswer, ReplyAnswer, OptionsAnswer = the response schemas
      domain/prompts.py         PromptBuilder: profile + request → Prompt
      domain/service.py         NegotiationService: express / reply / options
      presentation/controller.py
    conversations/
      module.py                 ConversationsModule: stores, dispatcher, service, worker, controller
      domain/models.py          the write bodies and the queue payload (GenerationTask)
      domain/documents.py       the documents as models: StoredConversation / StoredMessage (read),
                                NewConversation / NewMessage (created, via ConversationDocuments),
                                ImageRef, ExpressRecord; ConversationPatches (every change), Summaries
      domain/history.py         ChatHistory: which turns a generation reads
      domain/screenshots.py     Screenshots: re-encode, store, reference
      domain/service.py         ConversationService: create/send/options/redo/patch/archive
      domain/generations.py     Generation (abstract) → ReplyGeneration / ExpressGeneration /
                                OptionsGeneration: what each kind asks and writes
      domain/worker.py          GenerationWorker: job() (what to ask) and run() (ask, write, measure)
      domain/ports.py           ConversationStore / ScreenshotStore / Dispatcher
      data/store.py             the documents in Firestore
      data/screenshots.py       CloudScreenshotStore: the screenshots in the bucket
      data/dispatchers.py       Cloud Tasks queue, and the inline one for the emulator
      presentation/controller.py  sub-path routing
    lines_that_land/
      module.py                 LinesModule: store, service, generator, controller
      domain/content.py         the content models = the response schema; the bundled fallback
      domain/service.py         LinesService (what the tab shows), LinesGenerator (the schedule)
      data/store.py             content/lines_that_land
      presentation/controller.py
    profile/
      module.py                 ProfileModule: store, service, controller
      domain/patches.py         PATCH sections → a Firestore merge
      domain/service.py         ProfileService: read, patch, write-once fields
      domain/ports.py           ProfileStore
      data/store.py             users/{uid}
      presentation/controller.py
  tests/                        flat, one file per feature; conftest.py has the model fixtures
    support/                    in-memory stores, a static authenticator, InMemoryMetrics, install()/call()
```

Adding an endpoint: the `backend-endpoint` skill walks the whole path. Adding a model API:
subclass `ModelProvider`, add it to `ProviderRegistry.default()`, and add its section to
`settings.py`.

## Rules an agent must not quietly break

- **Async all the way down.** Every method that does I/O is `async def` and is awaited — the
  ports, the stores, the model providers, the authenticator, the services, the controllers.
  Use the SDK's own async client wherever there is one: Firestore's `AsyncClient`, the Vertex
  provider's `client.aio`, the Ollama provider's `httpx.AsyncClient`. Each is made per
  invocation and closed before the invocation's event loop ends (`CoreServices.aclose`),
  because a gRPC or HTTP client belongs to the loop it first ran on and every invocation gets
  a new one — so never the Admin SDK's `firestore_async.client()`, which is cached per
  process and fails from the second request on ("Event loop is closed"). Stores take the
  client from `CoreServices.firestore`. Only an SDK with no async client (Cloud Storage, Auth
  / App Check verification, the Cloud Tasks enqueue) and CPU work (Pillow) go through
  `asyncio.to_thread`; a coroutine never calls a blocking method directly. Independent reads
  run together with `asyncio.gather` (conversation + history, several screenshots). Pure,
  I/O-free methods stay plain `def` (`new_id`, `uri`, prompt building).
- **Documents are models.** A store takes and returns pydantic models, never a dict to pick
  apart: reads come back validated (`StoredConversation`, `StoredMessage`), a new document
  goes in whole as a `FirestoreDocument` (its None fields are not written), and a change is a
  merge `Patch` whose values are models wherever the value has a shape (`ImageRef`,
  `TokenUsage`, `Line`, `ExpressRecord`). `FirestorePatch` makes both plain at the store —
  the only place a model becomes a dict — and the in-memory stores apply the same rules.

- **No module-level functions and no module-level state** outside `main.py`. A helper is a
  method of the class it serves; one every layer needs goes in `core/utils/`. Constants are
  class constants (`ClassVar`) or enums; loggers and metrics come from the invocation's
  `Telemetry` through the constructor — no module-level logger, no context variable. Only
  classes, type aliases and `__all__` live at module scope.
- **Tunables are settings.** A new knob is a field on the section that owns it in
  `core/config/settings.py`, declaring its variable with `FromEnv(params.XParam(...))`, plus a
  line in `.env` (`tests/test_config.py` fails when the two disagree). Code reads the section
  — injected by the container, or `Section.current()` inside a pydantic validator — never a
  param and never a value cached across requests.
- **Imports at the top**, except an SDK that costs over 0.1 s to import (Firestore, Storage,
  Auth, google-genai): its adapter imports it on first use with a one-line reason, because
  every function shares one image and a cold start pays for whatever `main` imports.
- **Test doubles live in `tests/support/`**, never in the deployed code.
- **One way to a model.** Everything goes through `ModelManager.generate(prompt, AnswerModel,
  operation=…)`, which returns a `Generated` (`.answer`, `.model`, `.usage`): no SDK call
  outside `core/ai/providers/`, no hand-written JSON schema, no parsing of model text anywhere
  else. Whatever stores an answer stores its `model` and `usage` beside it, as the wizard
  message does.
- **No fake models, in tests or anywhere.** Use the local model (see Toolchain).
- **Log facts as fields**: `self._log.info("turn queued", uid=uid, cid=cid)` with the logger
  the constructor got from `telemetry.logger(name)`, not formatted into the message. A new
  measurement is a `MetricEvent` subclass in `core/observability/metrics.py`.
- **Pydantic for every request body.** Validators raise `ValueError`; `Validation.parse`
  turns that into a 400 with `field: message`.
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
