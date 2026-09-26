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
a param: services get their section in the constructor (the feature's `module.py`, or
`CoreServices` for core, passes `ThingSettings.current()`), and a pydantic validator, which has no constructor, calls
`ThingSettings.current()` itself. A decorator in `main.py` that needs the param itself takes
`ThingSettings.param("max_things")`. Name it by the `.env` rule in the guide's Toolchain (a
reserved name makes the CLI reject the whole file).

## 2. Request, answer and document models

Pydantic, in the domain of the feature they belong to (`features/<feature>/domain/`).
Validators raise `ValueError`; `Validation.parse` (`core/utils/`) turns the `ValidationError`
into a 400 listing `field: message`. Reuse `Text.trim` / `Text.clip` instead of
re-implementing trimming or bounds, and put limits in `ClassVar` constants, not literals.

Anything a model must answer is an answer model too (see `negotiation/domain/answers.py`):
it is the JSON schema the output is constrained to and the validation of what comes back.
Call it with `ModelManager.generate(prompt, AnswerModel, operation="…")` ("The model" in the
guide); a document that stores the answer stores `.model` and `.usage` beside it, and a new
`operation` name labels the `model_call` metric.

## 3. Service logic

Follow the guide's rules "Async all the way down" and "Documents are models": a new port
method is `async`, returns validated documents and takes a `FirestoreDocument` or a merge
`Patch`; its Firestore implementation awaits the `AsyncClient` the feature module hands it from
`self._core.firestore.client`.

A new store (a port with a Firestore implementation) also needs a way in for the tests: a
keyword argument on `Container.__init__` (`container.py`, like `lines_store`) that its module
uses instead of building the Firestore one, and an in-memory double in
`tests/support/doubles.py`, exported from `tests/support/__init__.py`, so `install(monkeypatch,
…)` can inject it — otherwise the tests reach for real Firestore.

Put it in a class in `features/<feature>/domain/` — never in `main.py`, never in a
controller, never in `data/`. It takes its collaborators and settings in the constructor,
typed by the `Protocol`s in `domain/ports.py`, so a test passes the in-memory store and
production the Firestore one from `data/`. A new feature gets its own package with the same
three layers; anything two features need lives in `core/`. No module-level functions or state,
and log facts as fields (the guide's rules); a new measurement is a `MetricEvent` subclass,
emitted through `telemetry.metrics`.

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
`asyncio.run(app.run(lambda c: c.conversations.worker.run(...)))`; enqueue the payload wrapped
(the guide's "Enqueue task payloads wrapped"). Scheduled jobs use
`@scheduler_fn.on_schedule` and bake the schedule at deploy time.

## 5. Rules, indexes, docs

- New Firestore query → add the composite index to `wizard-backend/firestore.indexes.json`.
- New path or access pattern → `firestore.rules` / `storage.rules`. Clients read; only
  functions write conversation data.
- Wire format changed → update the contract it belongs to (`wizard-app/CONVERSATIONS.md`,
  `AI_INTEGRATION.md`, `PROFILE_SYNC.md` or `LINES_THAT_LAND.md`) in the same commit, then the Dart models in `wizard-app/lib/features/*/data/models/`
  (`fvm dart run build_runner build`).
- New model setting or metric → the tables in `wizard-backend/AGENTS.md` ("The model", "Logs and
  metrics").

## 6. Verify

```bash
venv/bin/python -m pytest -q -rs
venv/bin/ruff check .
```

Tests call the functions through `tests/support/` (`install(monkeypatch, …)` puts containers
wired to its in-memory stores in front of `main` and returns one, `call(...)` makes the
request) and set params with `monkeypatch.setenv`; the guide's Toolchain has the rest
(`asyncio.run`, doubles, no fake models). A test that needs an answer takes the `local_model`
fixture, one about a failure `unreachable_model`; everything else asks nothing and checks what
would be asked on the prompt instead (see `_prompt` in `tests/test_conversations.py`). Then exercise it against the emulator (`local-stack` skill) if the change is more
than a rename.
