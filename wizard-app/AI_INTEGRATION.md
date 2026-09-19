# AI integration (Vertex AI) — Express Dealmaker and Pro Deal Closer

> **2026-09-17:** the app now sends Express and Pro turns through the `conversations`
> function (backend-owned history in Firestore, screenshots in Cloud Storage, see
> `CONVERSATIONS.md`). The stateless `express_dealmaker` / `pro_deal_closer` endpoints below
> stay deployed for direct calls and tests; request bodies and the prompting rules are shared.

Both AI features call Gemini on **Vertex AI** through two plain HTTPS Cloud Functions in
`wizard-backend/functions/` (Python 3.12, 2nd gen). The app never holds a model key; prompts,
model choice and limits live in the functions. Simple-first: no server-side entitlement
check yet, no persistence of requests, in-memory image preparation on the device.

## Functions

Both are `POST` with a JSON body and answer JSON. Errors are
`{"error": {"status": "INVALID_ARGUMENT" | "UNAUTHENTICATED" | "UPSTREAM_ERROR" | "INTERNAL" | "METHOD_NOT_ALLOWED", "message": "…"}}`
with the matching HTTP status (400 / 401 / 502 / 500 / 405). An `Authorization: Bearer <Firebase ID token>`
header is optional: signed-out users may call (the app allows skipping sign-in); a token that
is present but invalid is rejected.

### `express_dealmaker` — screenshots → lines

```json
{
  "images": [{"mime_type": "image/jpeg", "data": "<base64>"}],
  "text": "optional listing/chat text (typed, or OCR'd on device)",
  "keyword": "scuff",
  "locale": "en", "vibe": "tactical", "push": 80, "marketplace": "ebay", "deal_size": 550,
  "deals_per_month": "3_5", "hurdles": ["being_rude", "holding_ground"]
}
```
→ `{"seeing": "IKEA Kallax · $180 · slight scuff", "lines": [{"intent": "opener|counter|close", "text": "…", "why": "…"}], "model": "gemini-2.5-flash"}`

Limits: ≤ 10 images, ≤ 4 MB each, ≤ 16 MB together (also across chat turns), JPEG/PNG/WebP;
the byte caps are a backstop — the app compresses to a few hundred KB per shot before upload;
`text` is kept whole, whatever its length; `images` or `text` required.

### `pro_deal_closer` — chat coaching

```json
{
  "messages": [{"role": "user", "text": "Kallax listed at $180", "images": [ … ]},
               {"role": "wizard", "text": "Open at $140."}],
  "mode": "reply",            // or "options"
  "regenerate": false,
  "locale": "en", "vibe": "friendly", "push": 60, "marketplace": "facebook", "deal_size": 550
}
```
→ reply mode `{"reply": "…", "model": "…"}`; options mode `{"lines": [ … ], "model": "…"}`.
`vibe` and `push` are required: the buyer's tone and how hard to push are the app's to decide,
never a server default. The newest `MAX_MESSAGES` turns are used (200, the same as the cap on a
conversation, so the model normally sees the whole chat); screenshots are kept newest-first
within the 6-image budget.

### Prompting

`features/negotiation/domain/prompts.py` builds the system prompt from the buyer profile: tone from `vibe`
(the four onboarding presets), anchor aggressiveness from `push` (0–100, five bands),
marketplace etiquette, typical deal size, deal frequency (`deals_per_month`), the buyer's
known weak spots (`hurdles`, the money-leak ids, turned into coaching hints),
and the output language from `locale`: the tag the app sends is handed to the model as the
language to write in, so any language the model knows works and there is no list on the server
to extend. It must look like a BCP-47 tag (`en`, `pt-BR`, `zh-Hant-TW`) — that value goes into
the prompt, so anything else is answered in English. The same fields live in the Firestore profile
(`PROFILE_SYNC.md`); the functions may read them from there in a later step. Lines are
written as the buyer speaking to the seller, one message each, no placeholders, no invented
facts. Output is constrained with a JSON response schema and normalised (missing intents are
assigned by position, empty lines dropped).

### Configuration (functions/.env, deployed with the function)

| Variable | Default | Meaning |
|---|---|---|
| `VERTEX_LOCATION` | `us-central1` | Vertex AI region |
| `VERTEX_MODEL` | `gemini-2.5-flash` | Model id; swap to a newer Flash when available |
| `VERTEX_THINKING_BUDGET` | `0` | Gemini 2.5 thinking tokens; 0 = off (fastest, cheapest), -1 = do not send (models without thinking) |

Requirements on the project: Vertex AI API enabled; the function's runtime service account
needs **Vertex AI User** (`roles/aiplatform.user`). Memory 512 MB, timeout 60 s.

## App structure

- `core/network/cloud_functions_client.dart` — `CloudFunctionsApi.get` / `.post` against the
  remotely configured `api_url`; attaches the Firebase ID token when signed in;
  error bodies → `CloudFunctionException`.
- `core/utils/screenshot_encoder.dart` — the upload pipeline: native JPEG compression
  (flutter_image_compress) to a 720 px shorter side at q80, EXIF rotation applied then
  stripped, re-run with less quality and then a smaller side until the image is under
  `AttachmentLimits.maxImageBytes`. ~150–400 KB per screenshot, so staying inside the
  function's caps is the client's job and they never surface as an error. The gallery picker
  still asks the OS for JPEG (`maxWidth`/`imageQuality`).
- `features/shared/data/models/ai/ai_api_models.dart` — json_serializable request/response
  models for both functions.
- `features/express_dealmaker/data/datasources/cloud_express_dealmaker_remote_datasource.dart`
  — "upload" prepares the image in memory under an id; `getDealReply` posts all prepared
  images + profile + keyword. The existing repository, mapper, cubit and UI are unchanged.
- `features/pro_deal_closer/data/datasources/cloud_pro_deal_closer_remote_datasource.dart` —
  sends the chat history (attachments encoded once, cached by path) in `reply` or `options` mode.
- `--dart-define=MOCK_AI=true` keeps the canned mock data sources for UI work without a
  deployed backend (`AppConfig.useMockAi`).

Profile values come from `UserProfileService`, which copies the answers the onboarding screens
collect (`vibe`, `push`, `marketplace`, `deal_size`, `deals_per_month`, `hurdles`) straight out
of local storage under the keys remote config gave them — the app has no mapping of its own,
see `PROFILE_SYNC.md`. An unanswered screen contributes its configured default. The caller's
explicit vibe (tone chip) overrides the stored one for that request; `locale` is the device's.

## Subscriptions without a backend

The FastAPI subscriptions service (Postgres, receipt verification, webhooks) is removed. The
entitlement is what the store SDK reports: `in_app_purchase` purchase/restore events → product
id → tier via `subscription_config`, kept in memory and in `SharedPreferences`
(`subscription_status`) so the tier is known offline and at cold start. The repository
initialises the store provider itself so the purchase stream is always wired. **Restore
Purchases** re-reads the store and drops the entitlement only when the store reports no active
purchase, so a lapsed subscription falls back to free. Feature
gating (`FeatureGatePolicy`, fixed in code) and the paywall copy tell the user what each tier includes.

On iOS the plugin uses StoreKit 2 by default (`in_app_purchase_storekit` ≥ 0.4), so Restore
reports only *current* entitlements and an expired subscription is not re-granted; purchase
conversion in `IAPPaymentProvider` uses the platform-neutral fields for that reason (a cast to
`AppStorePurchaseDetails` would throw on StoreKit 2 transactions).

Trade-off: no server-side verification, so a tampered device can unlock tiers and the AI
functions do not check entitlement. Acceptable for the MVP; the upgrade path is App Check on
the functions plus receipt verification behind `PaymentProvider`, without touching callers.

## On-device OCR — options considered

Goal: cut multimodal cost by sending text instead of screenshots when possible.

| Option | Cost | Quality | Effort |
|---|---|---|---|
| **Multimodal only (current)** — send downscaled screenshots to Gemini Flash | ~260 tokens per image on Flash; cents per 1000 requests at list price | Best: sees bubble sides (who said what), prices, badges, photos, strikethroughs | none |
| **On-device OCR (Google ML Kit Text Recognition v2)**, send text only | Free on device; text-only prompt is a few hundred tokens | Loses layout and who-said-what in chats; fine for listings; needs Latin script pack for es/en | medium: plugin, permission-free, ~1 day |
| **Hybrid** — OCR on device, send text plus screenshots only when OCR confidence is low or the user asks | Lowest average cost | Near multimodal on listings, weaker on chats | medium+ |

Recommendation: keep multimodal for now. Flash image input is cheap, chats are the core
use case and their meaning depends on layout, and the encoder already keeps images small.
The contract is ready for OCR: `express_dealmaker` accepts `text` alongside or instead of
`images`, so adding ML Kit later is an app-only change. Revisit when request volume makes
image tokens a visible line item.
