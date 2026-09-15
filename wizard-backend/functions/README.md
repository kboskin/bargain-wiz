# Cloud Functions — `lines_that_land`

Firebase Cloud Functions (2nd gen, Python 3.12) for the Bargain Wiz app, deployed from
`wizard-backend/` (`firebase.json`, `.firebaserc`). Currently one function.

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
and `Last-Modified`. The app calls it with Dio (`GET {functions_base_url}/lines_that_land`).

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

## Local development

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
