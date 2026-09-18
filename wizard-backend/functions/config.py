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
MAX_IMAGES = params.IntParam("MAX_IMAGES", default=6, description="Screenshots per request / per chat turn.")
MAX_IMAGE_BYTES = params.IntParam("MAX_IMAGE_BYTES", default=1_500_000, description="Bytes per screenshot after the app downscaled it.")
MAX_TOTAL_IMAGE_BYTES = params.IntParam("MAX_TOTAL_IMAGE_BYTES", default=6_000_000, description="Bytes of all screenshots in one request.")
MAX_TEXT_CHARS = params.IntParam("MAX_TEXT_CHARS", default=8_000, description="Listing / chat text length; longer text is truncated.")
MAX_MESSAGE_CHARS = params.IntParam("MAX_MESSAGE_CHARS", default=4_000, description="One chat message; longer text is truncated.")
MAX_MESSAGES = params.IntParam("MAX_MESSAGES", default=40, description="Newest chat turns sent to the model.")
MAX_LINES = params.IntParam("MAX_LINES", default=3, description="Lines returned per answer (the UI shows three cards).")
DEFAULT_VIBE = params.StringParam("DEFAULT_VIBE", default="friendly", description="Tone when the profile has none or an unknown one.")
DEFAULT_PUSH = params.IntParam("DEFAULT_PUSH", default=60, description="Push level (0-100) when the profile has none.")

# ── Stored screenshots (conversations) ───────────────────────────────────────
IMAGE_MAX_SIDE = params.IntParam("IMAGE_MAX_SIDE", default=1600, description="Longest side in pixels after server-side re-encoding.")
IMAGE_JPEG_QUALITY = params.IntParam("IMAGE_JPEG_QUALITY", default=85, description="JPEG quality of stored screenshots.")

# ── Conversations ────────────────────────────────────────────────────────────
STORAGE_BUCKET = params.StringParam("STORAGE_BUCKET", default="", description="Bucket for screenshots; empty = the project's default Firebase bucket.")
CONVERSATION_RETENTION_DAYS = params.IntParam("CONVERSATION_RETENTION_DAYS", default=180, description="Days after the last message until `expires_at` (Firestore TTL).")
MAX_TURNS_PER_DAY = params.IntParam("MAX_TURNS_PER_DAY", default=100, description="Per-user cap on model calls per UTC day.")
MAX_MESSAGES_PER_CONVERSATION = params.IntParam("MAX_MESSAGES_PER_CONVERSATION", default=200, description="Turns per conversation before a new one is required.")
PREVIEW_CHARS = params.IntParam("PREVIEW_CHARS", default=140, description="Length of the history-list preview text.")
TITLE_CHARS = params.IntParam("TITLE_CHARS", default=60, description="Length of the derived conversation title.")

# ── Profile ──────────────────────────────────────────────────────────────────
USERS_COLLECTION = params.StringParam(
    "USERS_COLLECTION",
    default="users",
    description="The single Firestore collection everything about a person lives under: the "
    "profile document itself plus its `conversations` and `limits` subcollections.",
)
PROFILE_MAX_STR = params.IntParam("PROFILE_MAX_STR", default=500, description="Longest stored string value.")
PROFILE_MAX_KEY = params.IntParam("PROFILE_MAX_KEY", default=64, description="Longest stored map key / id.")
PROFILE_MAX_ANSWERS = params.IntParam("PROFILE_MAX_ANSWERS", default=64, description="Onboarding answers per patch.")
PROFILE_MAX_LIST = params.IntParam("PROFILE_MAX_LIST", default=32, description="Items per stored list.")
PROFILE_MAX_HURDLES = params.IntParam("PROFILE_MAX_HURDLES", default=16, description="Hurdle ids kept.")
PROFILE_MAX_FLOW_STEPS = params.IntParam("PROFILE_MAX_FLOW_STEPS", default=40, description="Onboarding screens kept in the flow trace.")

# ── Lines that land ──────────────────────────────────────────────────────────
LINES_REFRESH_INTERVAL_HOURS = params.IntParam(
    "LINES_REFRESH_INTERVAL_HOURS",
    default=24,
    description="How often the content changes: Cache-Control max-age and the app's on-device cache.",
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
