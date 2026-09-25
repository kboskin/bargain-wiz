---
name: backend-endpoint
description: Add or change a Cloud Function endpoint, queue worker or scheduled job in wizard-backend. Use when the task touches functions/main.py, container.py, a feature module, a controller, a service, a request or answer model, a config param, a model provider, Firestore rules or indexes.
---

# Backend endpoint

Work from `wizard-backend/functions/`. House rules that shape every change are in
`wizard-backend/AGENTS.md`; this is the order of operations.

## 1. Config before code

Every tunable is a field on the typed section that owns it in `core/config/settings.py`, and
the field declares its environment variable — one declaration, with its type, default and
description:

```python
class ThingSettings(Section):
    max_things: Annotated[Positive, FromEnv(params.IntParam(
        "MAX_THINGS", default=10, description="Things per request.",
    ))]
```

Add the matching line to `.env` (`tests/test_config.py` fails until you do). Code never reads
a param: services get their section in the constructor (the container passes
`ThingSettings.current()`), and a pydantic validator, which has no constructor, calls
`ThingSettings.current()` itself. A decorator in `main.py` that needs the param itself takes
`ThingSettings.param("max_things")`. No module constants, no values cached across requests.
Avoid `FIREBASE_*` and reserved names like `FUNCTION_MEMORY_MB` — the CLI rejects the whole
file.

## 2. Request, answer and document models

Pydantic, in the domain of the feature they belong to (`features/<feature>/domain/`).
Validators raise `ValueError`; `Validation.parse` (`core/utils/`) turns the `ValidationError`
into a 400 listing `field: message`. Reuse `Text.trim` / `Text.clip` instead of
re-implementing trimming or bounds, and put limits in `ClassVar` constants, not literals.

Anything a model must answer is an answer model too (see `negotiation/domain/answers.py`):
it is the JSON schema the output is constrained to and the validation of what comes back.
Call it with `ModelManager.generate(prompt, AnswerModel, operation="…")` — never an SDK, never
a hand-written schema, never parsing model text yourself. It returns a `Generated`: the
`.answer`, the `.model` that wrote it and the call's `.usage` (None when the provider reported
none); a document that stores the answer stores those two beside it. A new `operation` name labels the
`model_call` metric.

## 3. Service logic

Everything that does I/O is `async def` and awaited, from the controller to the store (see
"Async all the way down" in `wizard-backend/AGENTS.md`). A new port method is `async` and speaks models: it
returns validated pydantic documents and takes a `FirestoreDocument` or a merge `Patch` (see
"Documents are models"). Its Firestore implementation awaits the invocation's `AsyncClient`,
which the feature module hands it from `self._core.firestore.client`; only Storage and Tasks,
which have no async SDK, wrap their call in `asyncio.to_thread`. Independent reads in a
service run with `asyncio.gather`.

Put it in a class in `features/<feature>/domain/` — never in `main.py`, never in a
controller, never in `data/`. It takes its collaborators and settings in the constructor,
typed by the `Protocol`s in `domain/ports.py`, so a test passes the in-memory store and
production the Firestore one from `data/`. A new feature gets its own package with the same
three layers; anything two features need lives in `core/`, and a helper every layer needs in
`core/utils/`. **No module-level functions or state**: a helper is a method of the class it
serves, a constant is a `ClassVar` or an enum. Log through the logger the constructor gets
(`telemetry.logger("feature")`), with keyword fields; a new measurement is a `MetricEvent`
subclass in `core/observability/metrics.py`, emitted through `telemetry.metrics`.

## 4. Controller, container, entry point

The controller (`features/<feature>/presentation/controller.py`) does auth, body → model and
the response, in `async def` methods that await the authenticator and the service. The feature's `module.py` gets a `cached_property` for each new service and
controller — the only place an implementation is chosen — and a new feature's module gets a
`cached_property` on `Container`. When behaviour varies by kind, give each kind its own class
behind an abstract base (see `conversations/domain/generations.py`) rather than branching on a
field in several places. `main.py` gets the thin wrapper:

```python
@https_fn.on_request(invoker="public", cors=JsonEndpoint.CORS)
def my_endpoint(req: https_fn.Request) -> https_fn.Response:
    app = Container.for_request("my_endpoint", req)
    return asyncio.run(app.serve(req, ("POST",), lambda c: c.my_feature.controller.handle))
```

Firebase calls the function synchronously; `asyncio.run` gives the invocation its own event
loop and `serve` closes what it opened before that loop ends. Queue workers use
`@tasks_fn.on_task_dispatched` with `RetryConfig`/`RateLimits` taking
`QueueSettings.param(...)`, build `Container.for_background("name")` and run the job with
`asyncio.run(app.run(lambda c: c.conversations.worker.run(...)))`; enqueue their payload
wrapped as `{"data": model.model_dump(mode="json")}`. Scheduled jobs use
`@scheduler_fn.on_schedule` and bake the schedule at deploy time.

## 5. Rules, indexes, docs

- New Firestore query → add the composite index to `wizard-backend/firestore.indexes.json`.
- New path or access pattern → `firestore.rules` / `storage.rules`. Clients read; only
  functions write conversation data.
- Wire format changed → update `wizard-app/AI_INTEGRATION.md` or `wizard-app/CONVERSATIONS.md`
  **and** `functions/README.md` in the same commit, then the Dart models in
  `wizard-app/lib/features/*/data/models/` (`fvm dart run build_runner build`).
- New param or metric → the tables in `functions/README.md` ("The model", "Logs and metrics").

## 6. Verify

```bash
venv/bin/python -m pytest -q -rs
venv/bin/ruff check .
```

Tests call the functions through `tests/support/` (`install(monkeypatch, …)` puts containers
wired to its in-memory stores in front of `main` and returns one, `call(...)` makes the
request) and set params with `monkeypatch.setenv`. A test that calls a coroutine directly wraps it in
`asyncio.run(...)`; a forgotten `await` fails the run (`RuntimeWarning` is an error). Test doubles live there, never in the
deployed code. **No fake models**: a test that needs an answer takes
the `local_model` fixture and asks the local Ollama model; one about a failure takes
`unreachable_model`; everything else asks nothing — check what would be asked on the prompt
instead (see `_prompt` in `tests/test_conversations.py`). `tests/` stays flat, one file per
feature. Then exercise it against the emulator (`local-stack` skill) if the change is more
than a rename.
