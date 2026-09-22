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
  "profile": {
    "answers": [
      {"key": "hurdles", "value": "being_rude",
       "prompt": "Weak spot — fears sounding rude: keep every line warm and polite while still firm on price."},
      {"key": "hurdles", "value": "holding_ground",
       "prompt": "Weak spot — tends to accept the first counter: include a line that holds the position."},
      {"key": "vibe", "value": "tactical",
       "prompt": "Tone: Tactical Strategist — uses logic, comparable prices and product flaws as leverage; persistent but fair."},
      {"key": "push", "value": 80,
       "prompt": "Push level: Bold — a low anchor around 25-35% under asking, holds firm."},
      {"key": "marketplace", "value": "ebay", "prompt": "Marketplace etiquette on eBay: …"}
    ],
    "locale": "en"
  }
}
```

The profile is a **list, not a record**: one entry per *pick*, so a multi-select (`hurdles`
above) arrives as several entries sharing a key, and the order is the order the app resolved
them — onboarding screen order, which is the order the buyer block reads in. `prompt` is
optional on an entry; `value` is carried so the answer can be stored and echoed back, and
nothing in the function reads it.
→ `{"seeing": "IKEA Kallax · $180 · slight scuff", "lines": [{"intent": "opener|counter|close", "text": "…", "why": "…"}], "model": "gemini-3.8-flash"}`

Limits: ≤ 10 images, ≤ 4 MB each, ≤ 16 MB together (also across chat turns), JPEG/PNG/WebP;
the byte caps are a backstop — the app compresses to a few hundred KB per shot before upload;
`text` is kept whole, whatever its length; `images` or `text` required. The byte caps count
only what the body actually carries: a screenshot already in Cloud Storage travels as a URI
and costs nothing, while the ≤ 10 cap still applies because it bounds what the model is
asked to look at.

### `pro_deal_closer` — chat coaching

```json
{
  "messages": [{"role": "user", "text": "Kallax listed at $180", "images": [ … ]},
               {"role": "model", "text": "Open at $140."}],
  "mode": "reply",            // or "options"
  "regenerate": false,
  "profile": {
    "answers": [{"key": "vibe", "value": "friendly",
                 "prompt": "Tone: Friendly Collaborator — warm and polite, builds rapport, asks nicely…"}],
    "locale": "en"
  }
}
```
→ reply mode `{"reply": "…", "model": "…"}`; options mode `{"lines": [ … ], "model": "…"}`.
Nothing in `profile` is required and `profile` itself may be left out: an empty `answers` list
is a valid request that simply produces a prompt with no buyer block. The buyer's tone and how
hard to push are still the app's to decide and never a server default — the difference is that
the function no longer knows those answers exist, so it has nothing to demand. The newest
`MAX_MESSAGES` turns are used (200, the same as the cap on a conversation, so the model
normally sees the whole chat); screenshots are kept newest-first within the `MAX_IMAGES`
budget (10). Both are cost levers if they ever need to be: a Pro turn re-sends its whole
window, text and screenshots, to the model on every call, and each screenshot is billed
again every time.

### Screenshots: bytes once, then a URI

The app sends screenshots as base64. The `conversations` function re-encodes them, stores
them under `users/{uid}/conversations/{cid}/`, and from then on hands Gemini the object's
**`gs://` URI** (`Part.from_uri`) rather than the bytes (`Part.from_bytes`). So a screenshot
crosses the wire once, on the turn that adds it; every later turn in the same chat references
it and Vertex fetches it from the bucket. Before this, the worker downloaded every image in
the history on every turn and inlined them again.

`StoredImage` is built by the backend only and is deliberately unreachable from any request
body: a client able to name a URI could point Gemini at any object the runtime service
account can read. A body describes images by their bytes, full stop — enforced in the
`images` validators and pinned by `test_a_client_cannot_name_a_storage_uri`.

### Prompting

`features/negotiation/domain/prompts.py` builds the system prompt out of two things: the
standing rules every request gets — who the coach is, that a line is pasted verbatim by the
buyer, no placeholders, no invented facts — and the buyer block, which is nothing but the
sentences the profile's answers carried, in the order they arrived. It names no answer:
`Profile` holds `answers` and `locale` and nothing else, so tone, push, marketplace etiquette,
deal size, deal frequency and the buyer's weak spots reach the model as lines the template
wrote, not as fields this module knows about. The output language comes from `locale`: the tag
the app sends is handed to the model as the language to write in, so any language the model
knows works and there is no list on the server to extend. It must look like a BCP-47 tag
(`en`, `pt-BR`, `zh-Hant-TW`) — that value goes into the prompt, so anything else is answered
in English.

**Where the sentences come from.** What an answer *means* to the coach is written next to the
answer, in the app's own Remote Config template — `metadata.prompt` on an option, `prompt`
on a slider stop — and the app forwards it with every request **on the answer it describes**:
each entry of `profile.answers` is one pick, `{key, value, prompt}`. So adding an option, or a
whole new question, changes the prompt with **no deploy on either side**: publish the template
and every client that has fetched it starts describing the new answer.
`UserProfileService.snapshot()` resolves the values and their sentences in one pass, which is
what makes the tone a screen shows the one actually being sent rather than the stored one.

**The template writes the whole line; the backend renders it verbatim.** There is no
server-side copy of the option list, no per-field label and no ordering sequence: `prompts.py`
keeps the standing rules, the fence, and the task each endpoint asks for, and `buyer_block()`
is `[a.prompt for a in answers if a.prompt]` plus a warning for the ones that described
nothing. The last lists of keys went with the old shape — `ANSWER_FIELDS`, `answered()`,
`option_id()` and the `SKIP_KEYS` for answers that describe nothing (the referral code) are
gone from `prompts.py`; the skip list now lives in the drift test, the only place that still
has to know one. Line order is the order the app sent, which is onboarding screen order — so
the template controls the buyer block's content *and* its shape.

An answer the client does not describe contributes nothing and is logged
(`undescribed onboarding answer field=… value=…`); a profile that describes none of itself
produces a prompt with no buyer block at all. That warning is the drift signal at runtime,
and `functions/tests/test_option_prompts.py` catches the same drift at review time by reading
the app's bundled `remote_config_defaults.json` and asserting every option it offers
describes itself — for every answer key the template writes, not a list kept on the server.

Two consequences worth knowing. Reordering onboarding screens reorders the buyer block, so a
funnel change is also a prompt change. And because the lines are whole, prompt *structure* is
now the template's too — the fence still contains it, but nothing forces a sentence into a
shape the server chose.

**Trust boundary, stated on the record.** Prompt text now originates from the client. On the
live path (`conversations`) that client holds at least an anonymous Firebase ID token and
passes App Check when it is enabled, and the only output it can steer is its own. Sentences
have their whitespace collapsed, so a sentence is one line and cannot forge a second, and a
sentence rides on the answer it describes — a client may restate what it sends and has
nowhere to put a line for an option it did not pick. That last one used to hold because the
app behaved; it now holds because of the shape of the body. Nothing else is filtered and
nothing is capped: the block is fenced and introduced as data, and the same client already
sends unbounded `text` into the user parts, so scrubbing or truncating honest copy would cost
more than it buys. When anything is present the buyer block is wrapped in
`<buyer_profile>…</buyer_profile>` and introduced as data about a person, not instructions.
The same answers live in the Firestore profile
(`PROFILE_SYNC.md`); the functions may read them from there in a later step. Lines are
written as the buyer speaking to the seller, one message each, no placeholders, no invented
facts. Output is constrained with a JSON response schema and normalised (missing intents are
assigned by position, empty lines dropped).

### Configuration (functions/.env, deployed with the function)

| Variable | Default | Meaning |
|---|---|---|
| `VERTEX_LOCATION` | `us-central1` | Vertex AI region |
| `VERTEX_MODEL` | `gemini-3.8-flash` | Model id (Gemini 2.5 Flash retires in Oct 2026) |
| `VERTEX_THINKING_LEVEL` | `low` | Gemini 3 thinking level `low` / `medium` / `high`; 3.x Flash rejects `minimal` and cannot switch thinking off, and thinking tokens bill as output. Empty = not sent (model defaults to `high`) |
| `VERTEX_TEMPERATURE` | `1.0` | Google strongly recommends the Gemini 3 default; empty = not sent |
| `VERTEX_MEDIA_RESOLUTION` | `high` | Tokens per screenshot: `low` 280, `medium` 560, `high` 1,120. Chat screenshots need `high` |

Every call logs one line, `gemini usage model=… prompt_tokens=… cached_tokens=… output_tokens=…
thought_tokens=… total_tokens=…`, at INFO. `cached_tokens` is Vertex's implicit prompt caching
(on by default for Gemini 2.5+; 3.x Flash needs a prompt of at least 4,096 tokens and an
identical prefix, which is why the screenshots go before the transcript in `pro_parts`).
`thought_tokens` is the number to watch: it is billed as output and Google publishes no
figure for `low`. Build the cost dashboard from these lines before trusting any estimate.

Requirements on the project: Vertex AI API enabled; the function's runtime service account
needs **Vertex AI User** (`roles/aiplatform.user`). A stored screenshot is handed to Gemini
as a `gs://` URI (below), so the object must be readable by whichever principal Vertex
fetches it as — see `functions/README.md` for the one thing to confirm on the first real
run. Memory 512 MB, timeout 60 s.

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
- `features/shared/data/models/ai/ai_api_models.dart` — json_serializable image, chat-message
  and response models for both functions; the buyer profile a request nests under `profile`
  is `ConversationProfile` in `features/conversation/data/models/conversation_api_models.dart`,
  built straight from one `ProfileSnapshot`.
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
see `PROFILE_SYNC.md`. An unanswered screen contributes its configured default. A deal's own
answers — its `overrides`, `CONVERSATIONS.md` — win over the
stored ones for that request; `locale` is the device's. `snapshot()` does both halves of that
resolution in one pass and returns a `ProfileSnapshot`: `fields`, the `{key: value}` map
`payload()` hands to `PATCH /profile`, and `answers`, the ordered list of
`ProfileAnswer(key, value, prompt)` an AI request carries — one per pick, each with the
`metadata.prompt` sentence behind the option actually being sent, so the two can never
describe different options.

## Subscriptions without a backend

The FastAPI subscriptions service (Postgres, receipt verification, webhooks) is removed. The
entitlement is what the store SDK reports: `in_app_purchase` purchase/restore events → product
id → tier via `subscription_config`, kept in memory and in `SharedPreferences`
(`subscription_status`) so the tier is known offline and at cold start. The repository
initialises the store provider itself so the purchase stream is always wired. **Restore
Purchases** re-reads the store and drops the entitlement only when the store reports no active
purchase, so a lapsed subscription falls back to free. Feature
gating (`FeatureGatePolicy`, fixed in code) and the paywall copy tell the user what the plan includes.

**The offer (2026-09-21):** one paid tier, `premium`, which unlocks Express Dealmaker and
Pro Deal Closer; `free` keeps Lines that land, History and Profile. The plan is sold as two
store products, monthly (`com.bargain.wiz.premium.monthly`, $19.99, preselected, "Best
value") and weekly (`com.bargain.wiz.premium.weekly`, $6.99), with **no free trial**
(`trial_days: 0`, no explainer steps, no timeline). Each `subscription_config` product carries
an `id` ("monthly" / "weekly") and the `paywall_config` option with the same `id` buys it, so
the paywall resolves prices and product ids per option, not per tier. The store price is shown
with the option's `price_suffix` ("$19.99" + "/mo") so the billing period is always next to
the amount. Prices in `price_label` are only the offline fallback; the stores' regional
price tiers are the source of truth.

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
| **Multimodal only (current)** — send downscaled screenshots to Gemini Flash | 1,120 tokens per screenshot at `high` resolution on Gemini 3 (about $0.001 each at 2026 rates); a few cents per 10 reads | Best: sees bubble sides (who said what), prices, badges, photos, strikethroughs | none |
| **On-device OCR (Google ML Kit Text Recognition v2)**, send text only | Free on device; text-only prompt is a few hundred tokens | Loses layout and who-said-what in chats; fine for listings; needs Latin script pack for es/en | medium: plugin, permission-free, ~1 day |
| **Hybrid** — OCR on device, send text plus screenshots only when OCR confidence is low or the user asks | Lowest average cost | Near multimodal on listings, weaker on chats | medium+ |

Recommendation: keep multimodal for now. Flash image input is cheap, chats are the core
use case and their meaning depends on layout, and the encoder already keeps images small.
The contract is ready for OCR: `express_dealmaker` accepts `text` alongside or instead of
`images`, so adding ML Kit later is an app-only change. Revisit when request volume makes
image tokens a visible line item.
