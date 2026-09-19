# Lines that land

"Lines that land" (the Lines tab and the home bottom sheet) is served by a Google Cloud
Function, not read from Remote Config by the app and not part of the subscriptions service.

> **Client loading (2026-09-18):** nothing is fetched at app start. The tab is primed from the
> on-device copy (`LinesThatLandPrimed`, no network) and refreshes in the background only when
> it becomes visible with a stale or missing copy (`LinesThatLandOpened`); the user can pull to
> refresh (`LinesThatLandRefreshRequested`). Content on screen is never replaced by a spinner;
> a failed refresh keeps it and shows a toast. Repository: `cached()` + `refresh()`.

> **2026-09-18 — the content is generated, not authored.** A scheduled function,
> `refresh_lines`, asks Gemini for the categories every `LINES_REFRESH_INTERVAL_HOURS` using
> structured output and the same generator as the chat, then stores them in Firestore at
> `content/lines_that_land`. `GET /lines_that_land` serves that document, falling back to the
> bundled categories until the first generation lands or if one fails, so the tab always has
> content. The Remote Config key `lines_that_land_categories` is no longer read by anything;
> the model writes the lines now. `source` in the response is `generated` or `fallback`.
> The interval is used three times: it is the schedule (baked in at deploy time), the
> `Cache-Control` max-age and the `refresh_interval_hours` the app uses for its own cache and
> the "new lines every day" caption.

## Function

`lines_that_land` — plain HTTPS Firebase Cloud Function (2nd gen, Python 3.12) in
`wizard-backend/functions/`, deployed per Firebase project (dev / prod), region `us-central1`.
The app calls it with Dio:

```
GET {api_url}/lines_that_land
```

No body, no auth. `api_url` is a Remote Config key set per Firebase project
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
  "source": "generated"
}
```

- **Texts are multilocale.** Every category `name` and every tip is a `{"en": …, "es": …}`
  map, the same shape as all other remote-config copy in the app. The app resolves them per
  device locale with `TemplateText.textOf` (falls back to English, then to any language
  present), so one cached payload covers a language switch without a refetch. Every generated
  text carries every language the function asks for: the languages are the `LINES_LOCALES`
  param (`en,es` today) and they are the required properties of each text in the response
  schema Gemini is held to. The bundled fallback content is written in English and Spanish.
- `locales` — the languages the payload actually carries, which is what the app should key
  off rather than assuming `en`/`es`.
- No query parameters: every locale is always returned and the app picks the language.
- `updated_at` — when the content was generated (`generated_at` on the stored document).
- `refresh_interval_hours` — **how often the content is refreshed.** One number, owned by
  the function (`LINES_REFRESH_INTERVAL_HOURS` in `functions/.env`, default 24). It drives
  the regeneration schedule, the response's `Cache-Control: max-age`, the app's on-device
  cache TTL, and the caption under the Lines tab title ("Updated today · new lines every day").
- `source` — `generated` normally; `fallback` while no generation has landed yet, or when
  the stored document cannot be read. The app shows the content either way.

The content comes from Gemini, not from a human: `refresh_lines` regenerates it on a schedule
and the endpoint serves the stored document. There is nothing to author — no Remote Config
parameter is read any more (`lines_that_land_categories` is dead), and the lines cannot be
edited in the console. What is produced is configuration in `functions/.env`:
`LINES_CATEGORY_IDS`, `LINES_PER_CATEGORY`, `LINES_LOCALES`, and the two prompts themselves
(`LINES_SYSTEM_PROMPT`, `LINES_TASK_PROMPT`) — a prompt change is a redeploy, not a code
change. The models behind them are in
`wizard-backend/functions/features/lines_that_land/domain/`.
That pydantic `GeneratedLines` model is the response schema Gemini is constrained to, so the
payload above can only ever carry the configured ids and a full `{"en", "es"}` pair for every
text. Deploy and local run:
`wizard-backend/functions/README.md`.

## App behaviour

Structure (clean-architecture layers, reusable for any future function):

- `core/network/cloud_functions_client.dart` — `CloudFunctionsApi` (interface) and
  `CloudFunctionsClient` (Dio). `GET {api_url}{path}` decoded with a `fromJson`;
  the base URL is `RemoteConfigService.getApiUrl()` (key `api_url`,
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
