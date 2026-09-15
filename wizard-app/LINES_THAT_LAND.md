# Lines that land

"Lines that land" (the Lines tab and the home bottom sheet) is served by a Google Cloud
Function, not read from Remote Config by the app and not part of the subscriptions service.

## Function

`lines_that_land` — plain HTTPS Firebase Cloud Function (2nd gen, Python 3.12) in
`wizard-backend/functions/`, deployed per Firebase project (dev / prod), region `us-central1`.
The app calls it with Dio:

```
GET {functions_base_url}/lines_that_land
```

No body, no auth. `functions_base_url` is a Remote Config key set per Firebase project
(bundled default: the dev project's `https://us-central1-wizard-app-dev.cloudfunctions.net`).
Errors come back as `{"error": {"status": "...", "message": "..."}}` with a 4xx/5xx status.

Response:

```json
{
  "categories": [
    {
      "id": "opening",
      "name": {"en": "Opening lines", "es": "Frases de apertura"},
      "tips": [
        {"en": "Is there flexibility on the price?", "es": "¿Hay flexibilidad en el precio?"}
      ]
    }
  ],
  "locales": ["en", "es"],
  "updated_at": "2026-09-12T10:00:00Z",
  "refresh_interval_hours": 24,
  "source": "remote_config"
}
```

- **Texts are multilocale.** Every category `name` and every tip is a `{"en": …, "es": …}`
  map, the same shape as all other remote-config copy in the app. The app resolves them per
  device locale with `TemplateText.textOf` (falls back to English, then to any language
  present), so one cached payload covers a language switch without a refetch.
- `locales` — languages present anywhere in the content.
- No query parameters: every locale is always returned and the app picks the language.
- `updated_at` — when the content last changed (the Remote Config template's update time).
- `refresh_interval_hours` — **how often the content is refreshed.** One number, owned by
  the function (`LINES_REFRESH_INTERVAL_HOURS` in `functions/.env`, default 24). It drives
  the function's in-process cache TTL, its `Cache-Control: max-age`, the app's on-device
  cache TTL, and the caption under the Lines tab title ("Updated today · new lines every day").
- `source` — `remote_config` normally; `fallback` when the function could not reach Remote
  Config and served its built-in defaults (retried after 5 minutes).

The function reads the `lines_that_land_categories` parameter from the **server** Remote
Config template of its own project with the Firebase Admin SDK (runtime service account,
needs the Firebase Remote Config Viewer role). Content is still edited in the Firebase
console; the app never reads that key. Deploy and local run: `wizard-backend/functions/README.md`.

### Authoring the Remote Config value

In the Firebase console open Remote Config, switch the **Client/Server** selector at the
top of the page to **Server**, and define `lines_that_land_categories` there as a JSON
string (the old client-template copy is unused and can be deleted). `name` and each tip
may be a plain string (treated as English) or a language map; mixing is fine. Missing
Spanish falls back to English in the app, so partial translations are safe.

```json
{"categories": [
  {"id": "opening", "name": {"en": "Opening lines", "es": "Frases de apertura"},
   "tips": [
     {"en": "Is there flexibility on the price?", "es": "¿Hay flexibilidad en el precio?"},
     "What's the best you can do?"
   ]}
]}
```

## App behaviour

Structure (clean-architecture layers, reusable for any future function):

- `core/network/cloud_functions_client.dart` — `CloudFunctionsApi` (interface) and
  `CloudFunctionsClient` (Dio). `GET {functions_base_url}{path}` decoded with a `fromJson`;
  the base URL is `RemoteConfigService.getFunctionsBaseUrl()` (key `functions_base_url`,
  set per Firebase project; bundled default is the dev project). A function error body
  surfaces as `CloudFunctionException`, anything else unexpected as `StateError`. A new
  function only needs `api.get('/my_function', fromJson: MyResponse.fromJson)`.
- `features/lines_that_land/data/models/lines_that_land_response.dart` —
  `LinesThatLandResponse` / `LinesCategoryDto`, json_serializable models of the payload
  (texts as `MultilocaleText`); also the on-device cache format.
- `data/datasources/lines_that_land_api_datasource.dart` — `GET /lines_that_land` through
  `CloudFunctionsApi`.
- `data/datasources/lines_that_land_local_cache.dart` — `SharedPreferences` cache
  (`lines_that_land_cache` / `lines_that_land_fetched_at`), fresh for `refresh_interval_hours`.
- `data/mappers/lines_that_land_mapper.dart` — DTOs → entities, dropping categories
  without an id, a name or a usable line.
- `domain/entities` — `LinesThatLandFeed` (categories, locales, updatedAt, refreshInterval,
  source), `LinesThatLandCategory` / `LinesThatLandTip` with `MultilocaleText` texts, which
  the UI resolves per device locale with `TemplateText.textOf` (English fallback).

`LinesThatLandRepositoryImpl`:

1. Cache younger than `refresh_interval_hours` → used without a request.
2. Otherwise call the function and cache the response.
3. Function unreachable → stale cache if present, else a `NetworkFailure` ("Couldn't load
   lines. Check your connection and try again.") with a **Try again** button on the Lines tab.

`LinesThatLandLoaded` carries `updatedAt`, `refreshInterval` and `source`;
`LinesFreshness.describe` turns them into the caption.
