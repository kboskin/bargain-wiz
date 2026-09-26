# Lines that land

"Lines that land" (the Lines tab and the home bottom sheet) is served by a Google Cloud
Function, not read from Remote Config by the app.

## Function

`lines_that_land` — plain HTTPS Firebase Cloud Function (2nd gen, Python 3.12) in
`wizard-backend/functions/`, deployed per Firebase project (dev / prod), region `us-central1`.
The app calls it with Dio:

```
GET {api_url}/lines_that_land
```

No body, no auth: the content is public. `{api_url}` is the app's base URL (`AGENTS.md`); its
bundled default is the local emulator's, and the `local` flavor ignores the key. Errors:
`AI_INTEGRATION.md` "Errors".

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
  the regeneration schedule (fixed at deploy time), the response's `Cache-Control: max-age`, the app's on-device
  cache TTL, and the caption under the Lines tab title ("Updated today · new lines every day").
- `source` — `generated` normally; `fallback` while no generation has landed yet, or when
  the stored document cannot be read. The app shows the content either way.

The content comes from Gemini, not from a human: `refresh_lines` regenerates it on a
schedule with the same model as the chat, stores it in Firestore at
`content/lines_that_land`, and the endpoint serves that document. There is nothing to author —
no Remote Config parameter is read, and the lines cannot be edited in the console. What is
produced is configuration in `functions/.env`:
`LINES_CATEGORY_IDS`, `LINES_PER_CATEGORY`, `LINES_LOCALES`, and the two prompts themselves
(`LINES_SYSTEM_PROMPT`, `LINES_TASK_PROMPT`) — a prompt change is a redeploy, not a code
change. The models behind them are in
`wizard-backend/functions/features/lines_that_land/domain/`.
That pydantic `GeneratedLines` model is the response schema Gemini is constrained to, so the
payload above can only ever carry the configured ids and a full `{"en", "es"}` pair for every
text. Model, deploy and local run: `wizard-backend/AGENTS.md`.

## App behaviour

Nothing is fetched at app start. The tab is primed from the on-device copy
(`LinesThatLandPrimed`, no network) and refreshes in the background only when it becomes
visible with a stale or missing copy (`LinesThatLandOpened`); the user can pull to refresh
(`LinesThatLandRefreshRequested`). Content on screen is never replaced by a spinner; a failed
refresh keeps it and shows a toast.

The slice is `features/lines_that_land/` in the usual layers. What the file names do not
say: the json_serializable response model (`LinesThatLandResponse`) is also the on-device
cache format, kept in `SharedPreferences` (`lines_that_land_cache` /
`lines_that_land_fetched_at`); the mapper drops categories without an id, a name or a usable
line; and texts stay `MultilocaleText` all the way to the UI.

`LinesThatLandRepositoryImpl`: `cached()` is what the tab renders at once, `refresh()` calls
the function; `getFeed()` combines them:

1. Cache younger than `refresh_interval_hours` → used without a request.
2. Otherwise call the function and cache the response.
3. Function unreachable → stale cache if present, else a `NetworkFailure` ("Couldn't load
   lines. Check your connection and try again.") with a **Try again** button on the Lines tab.

`LinesFreshness.describe` turns the loaded state's `updatedAt` and `refreshInterval` into the
caption.
