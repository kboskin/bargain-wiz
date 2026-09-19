---
name: backend-endpoint
description: Add or change a Cloud Function endpoint, queue worker or scheduled job in wizard-backend. Use when the task touches functions/main.py, a request model, a config param, Firestore rules or indexes.
---

# Backend endpoint

Work from `wizard-backend/functions/`. House rules that shape every change are in
`wizard-backend/AGENTS.md`; this is the order of operations.

## 1. Config before code

Every tunable is a Firebase param, declared once in `core/config.py` with a description, and read
as `config.NAME.value` **at call time**:

```python
MAX_THINGS = params.IntParam("MAX_THINGS", default=10, description="Things per request.")
```

Add the matching line to `.env`. No module constants, no values cached across requests. Avoid
`FIREBASE_*` and reserved names like `FUNCTION_MEMORY_MB` — the CLI rejects the whole file.

## 2. Request and response models

Pydantic, in the domain of the feature it belongs to
(`features/<feature>/domain/models.py`). Validators raise `ValueError`;
`core.validation.validate_model` turns the `ValidationError` into a 400 listing
`field: message` — call it from `features/<feature>/presentation/` and reuse the helpers in
`core/validation.py` instead of re-implementing trimming or bounds.

## 3. Service logic

Put it in `features/<feature>/domain/` — never in `main.py`, and never in `data/`. The service
takes its collaborators as constructor arguments, typed by the `Protocol`s in
`domain/ports.py`, so a test passes the in-memory double and production passes the Firestore
one from `data/`. A new feature gets its own package with the same three layers; anything two
features need lives in `core/`. Nothing may live at module scope but pure definitions.

## 4. Entry point

`main.py` gets the thin wrapper only:

```python
@https_fn.on_request(cors=CORS)
@json_endpoint(methods=("POST",))
def my_endpoint(req: https_fn.Request) -> https_fn.Response:
    body = validate_model(MyRequest, json_body(req))
    return json_response(my_service().handle(body))
```

Queue workers use `@tasks_fn.on_task_dispatched` with `RetryConfig`/`RateLimits` from
`config`; enqueue their payload wrapped as `{"data": model.model_dump(mode="json")}`.
Scheduled jobs use `@scheduler_fn.on_schedule` and bake the schedule at deploy time.

## 5. Rules, indexes, docs

- New Firestore query → add the composite index to `wizard-backend/firestore.indexes.json`.
- New path or access pattern → `firestore.rules` / `storage.rules`. Clients read; only
  functions write conversation data.
- Wire format changed → update `wizard-app/AI_INTEGRATION.md` or `wizard-app/CONVERSATIONS.md`
  **and** `functions/README.md` in the same commit, then the Dart models in
  `wizard-app/lib/features/*/data/models/` (`fvm dart run build_runner build`).

## 6. Verify

```bash
venv/bin/python -m pytest -q
venv/bin/ruff check .
```

Tests set params with `monkeypatch.setenv` and swap the constructors `main` imports for fakes
— `tests/` stays flat, one file per feature; follow `tests/test_conversations.py`. Then exercise it against the
emulator (`local-stack` skill) if the change is more than a rename.
