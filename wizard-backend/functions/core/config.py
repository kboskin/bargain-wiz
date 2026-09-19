"""Runtime configuration.

Every tunable is an environment variable, deployed from `.env` through Firebase params
(https://firebase.google.com/docs/functions/config-env); the defaults below only apply when a
variable is unset. Read values at call time (`config.MAX_IMAGES.value`), never at import.
"""
from firebase_functions import params

# ── Vertex AI ────────────────────────────────────────────────────────────────
VERTEX_LOCATION = params.StringParam("VERTEX_LOCATION", default="us-central1", description="Vertex AI region for Gemini calls.")
VERTEX_MODEL = params.StringParam("VERTEX_MODEL", default="gemini-2.5-flash", description="Gemini model id.")
VERTEX_THINKING_BUDGET = params.IntParam(
    "VERTEX_THINKING_BUDGET",
    default=0,
    description="Thinking token budget for Gemini 2.5 models (0 = off; -1 = do not send the setting).",
)
VERTEX_TEMPERATURE = params.StringParam("VERTEX_TEMPERATURE", default="0.7", description="Sampling temperature (float).")
VERTEX_MAX_OUTPUT_TOKENS = params.IntParam("VERTEX_MAX_OUTPUT_TOKENS", default=2048, description="Max output tokens per call.")

# ── Request limits (AI functions and conversations) ───────────────────────────
# The app downscales every screenshot before upload, so the byte caps here are a
# ceiling against a client that doesn't, not the size we expect.
MAX_IMAGES = params.IntParam("MAX_IMAGES", default=10, description="Screenshots per request / per chat turn.")
MAX_IMAGE_BYTES = params.IntParam("MAX_IMAGE_BYTES", default=4_000_000, description="Bytes per screenshot; the app sends ~0.3 MB.")
MAX_TOTAL_IMAGE_BYTES = params.IntParam("MAX_TOTAL_IMAGE_BYTES", default=16_000_000, description="Bytes of all screenshots in one request (base64 inflates this by a third).")
MAX_MESSAGES = params.IntParam(
    "MAX_MESSAGES",
    default=200,
    description="Newest chat turns sent to the model. Matches MAX_MESSAGES_PER_CONVERSATION, so the "
    "model sees the whole chat; lower it only to cut token cost.",
)
MAX_LINES = params.IntParam("MAX_LINES", default=3, description="Lines returned per answer (the UI shows three cards).")

# ── Stored screenshots (conversations) ───────────────────────────────────────
IMAGE_MAX_SIDE = params.IntParam("IMAGE_MAX_SIDE", default=1600, description="Longest side in pixels after server-side re-encoding.")
IMAGE_JPEG_QUALITY = params.IntParam("IMAGE_JPEG_QUALITY", default=85, description="JPEG quality of stored screenshots.")

# ── Conversations ────────────────────────────────────────────────────────────
STORAGE_BUCKET = params.StringParam("STORAGE_BUCKET", default="", description="Bucket for screenshots; empty = the project's default Firebase bucket.")
MAX_MESSAGES_PER_CONVERSATION = params.IntParam("MAX_MESSAGES_PER_CONVERSATION", default=200, description="Turns per conversation before a new one is required.")
PREVIEW_CHARS = params.IntParam("PREVIEW_CHARS", default=140, description="Length of the history-list preview text.")
TITLE_CHARS = params.IntParam("TITLE_CHARS", default=60, description="Length of the derived conversation title.")

# ── Generation queue (Cloud Tasks: the rate limiter, project-wide not per user) ─
QUEUE_MAX_DISPATCHES_PER_SECOND = params.IntParam(
    "QUEUE_MAX_DISPATCHES_PER_SECOND", default=10, description="Model calls started per second across the project."
)
QUEUE_MAX_CONCURRENT_DISPATCHES = params.IntParam(
    "QUEUE_MAX_CONCURRENT_DISPATCHES", default=20, description="Model calls running at once across the project."
)
QUEUE_MAX_ATTEMPTS = params.IntParam(
    "QUEUE_MAX_ATTEMPTS", default=3, description="Attempts per generation before the turn is marked failed."
)

# ── Lines that land ──────────────────────────────────────────────────────────
LINES_REFRESH_INTERVAL_HOURS = params.IntParam(
    "LINES_REFRESH_INTERVAL_HOURS",
    default=24,
    description="How often `refresh_lines` regenerates the Lines tab content; also the "
    "Cache-Control max-age and the app's on-device cache TTL.",
)
LINES_CATEGORY_IDS = params.StringParam(
    "LINES_CATEGORY_IDS",
    default="opening,followup,closing",
    description="Comma-separated ids of the categories a generation must produce, in the order "
    "the app renders them. They reach Gemini as the enum of the response schema, so nothing "
    "else can come back; changing them means revisiting the task prompt and the bundled "
    "fallback content in lines_that_land_service.py.",
)
LINES_PER_CATEGORY = params.IntParam(
    "LINES_PER_CATEGORY", default=5, description="Lines the model writes per category."
)
LINES_LOCALES = params.StringParam(
    "LINES_LOCALES",
    default="en,es",
    description="Comma-separated BCP-47 tags every generated text must carry. They become the "
    "required properties of each text in the response schema, so the model writes all of them "
    "or the generation fails. The bundled fallback content is written in en and es whatever "
    "this says, and the endpoint reports the languages the content actually has.",
)
LINES_SYSTEM_PROMPT = params.StringParam(
    "LINES_SYSTEM_PROMPT",
    default="You write ready-to-paste lines for a BUYER negotiating on peer-to-peer marketplaces "
    "(Facebook Marketplace, eBay, Craigslist, OLX). Every line is one message the buyer sends "
    "the seller: short, natural, specific, never rude, never a template with placeholders.",
    description="Who the model is while it writes the Lines tab.",
)
LINES_TASK_PROMPT = params.StringParam(
    "LINES_TASK_PROMPT",
    default="Produce exactly {count} categories with these ids and nothing else: {categories} — "
    "the opening message, the follow-up when the seller hesitates or goes quiet, and the line "
    "that closes the deal. Name each category in two or three words. Give each category exactly "
    "{lines_per_category} lines, all different in tactic: they should cover price anchoring, "
    "bundling or pickup convenience, naming a flaw, walking away politely, and agreeing quickly. "
    "No line mentions a specific item, brand or price. Write every text in all of these "
    "languages: {locales}.",
    description="What one generation must produce. Filled in at call time: {categories}, "
    "{count}, {lines_per_category}, {locales} — the values of the params above, so the prompt "
    "and the response schema cannot disagree. An unknown placeholder is left as written rather "
    "than failing the run.",
)

# ── Security ─────────────────────────────────────────────────────────────────
REQUIRE_APP_CHECK = params.BoolParam(
    "REQUIRE_APP_CHECK",
    default=False,
    description="Reject requests without a valid X-Firebase-AppCheck token (turn on once the app ships App Check).",
)

# ── Function resources (applied to every function through set_global_options).
# Note: FUNCTION_* names are reserved by the Firebase CLI's .env loader, hence these names.
INSTANCE_MEMORY_MB = params.IntParam("INSTANCE_MEMORY_MB", default=512, description="Memory per instance (a valid Cloud Functions size).")
REQUEST_TIMEOUT_SEC = params.IntParam("REQUEST_TIMEOUT_SEC", default=60, description="Request timeout (the model calls need most of it).")
MAX_INSTANCES = params.IntParam("MAX_INSTANCES", default=20, description="Cap on concurrent instances (bounds the Gemini bill).")
