"""Every environment variable the functions read, as typed, validated settings.

Each field says which variable it is read from (`FromEnv(params.XParam(...))`), so a setting is
declared once, with its type, its default and its description, in the section it belongs to.
Values come from `functions/.env` at deploy time, with `functions/.env.local` over it in the
emulator (https://firebase.google.com/docs/functions/config-env).

- `Section.current()` reads the environment when it is called — nothing is cached across
  requests — and validates it: a value the code cannot use is a [ConfigError] naming the
  variable, not a crash three calls later. The container reads each section once per
  invocation and hands it to what needs it; a pydantic validator, which has no constructor
  to receive one, calls `current()` itself.
- `Section.param(field)` is the Firebase param itself, for the decorators in `main.py`: the
  deploy manifest then carries `{{ params.NAME }}`, so a change in `.env` reaches the
  function's resources.
"""

from typing import Annotated, Any, ClassVar, Literal, Self

from firebase_functions import params
from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, ValidationError, model_validator

from core.errors import ConfigError
from core.utils import EnvValue, Text

Positive = Annotated[int, Field(gt=0)]
Words = Annotated[str, BeforeValidator(Text.strip), Field(min_length=1)]
Csv = Annotated[tuple[str, ...], BeforeValidator(EnvValue.csv), Field(min_length=1)]
Level = Annotated[Literal["low", "medium", "high"] | None, BeforeValidator(EnvValue.optional)]


class FromEnv:
    """Field metadata: the Firebase param a setting is read from."""

    __slots__ = ("param",)

    def __init__(self, param: Any):
        self.param = param


class Section(BaseModel):
    """One group of settings, read from the environment by [current]."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    @classmethod
    def sources(cls) -> dict[str, Any]:
        """Field name → the param it is read from."""
        return {
            name: meta.param
            for name, field in cls.model_fields.items()
            for meta in field.metadata
            if isinstance(meta, FromEnv)
        }

    @classmethod
    def param(cls, field: str) -> Any:
        return cls.sources()[field]

    @classmethod
    def current(cls) -> Self:
        """The section as the environment says right now."""
        sources = cls.sources()
        try:
            return cls.model_validate({name: param.value for name, param in sources.items()})
        except ValidationError as exc:
            problems = "; ".join(
                f"{cls._variable(e['loc'], sources)}: {e['msg']}" for e in exc.errors()[:3]
            )
            raise ConfigError(f"{cls.__name__}: {problems}") from exc

    @staticmethod
    def _variable(loc: tuple, sources: dict[str, Any]) -> str:
        """The environment variable a validation error is about, for the message."""
        field = str(loc[0]) if loc else ""
        return sources[field].name if field in sources else field


# ── function resources ───────────────────────────────────────────────────────


class RuntimeSettings(Section):
    """Applied to every function through `set_global_options`, so fixed at deploy time.
    FUNCTION_* names are reserved by the Firebase CLI's .env loader, hence these names."""

    memory_mb: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "INSTANCE_MEMORY_MB",
                default=512,
                description="Memory per instance (a valid Cloud Functions size).",
            )
        ),
    ]
    timeout_sec: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "REQUEST_TIMEOUT_SEC",
                default=60,
                description="Function timeout; also the longest a model call may take, since it cannot usefully "
                "outlive the function.",
            )
        ),
    ]
    max_instances: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "MAX_INSTANCES",
                default=20,
                description="Cap on concurrent instances (bounds the model bill).",
            )
        ),
    ]


# ── model ─────────────────────────────────────────────────────────────────────


class ModelSpec(BaseModel):
    """`<provider>/<model>`, as AI_MODEL spells it. The provider is the part before the first
    slash; the rest is that provider's own id, slashes and colons included."""

    model_config = ConfigDict(frozen=True)

    provider: str
    name: str

    @model_validator(mode="before")
    @classmethod
    def _parse(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        provider, slash, name = value.strip().partition("/")
        if not slash or not provider.strip() or not name.strip():
            raise ValueError(
                "must be <provider>/<model>, e.g. vertex/gemini-3.8-flash or ollama/qwen2.5vl:7b"
            )
        return {"provider": provider.strip().lower(), "name": name.strip()}

    def __str__(self) -> str:
        return f"{self.provider}/{self.name}"


class ModelSettings(Section):
    """Which model answers, and the generation settings every provider honours."""

    spec: Annotated[
        ModelSpec,
        FromEnv(
            params.StringParam(
                "AI_MODEL",
                default="vertex/gemini-3.8-flash",
                description="Which model answers, as <provider>/<model>: vertex/gemini-3.8-flash (Gemini on "
                "Vertex AI) or ollama/qwen2.5vl:7b (a model on this machine, for the emulator). Everything "
                "after the first slash is the provider's own model id.",
            )
        ),
    ]
    max_output_tokens: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "AI_MAX_OUTPUT_TOKENS",
                default=2048,
                description="Max output tokens per model call.",
            )
        ),
    ]
    temperature: Annotated[
        Annotated[float, Field(ge=0)] | None,
        BeforeValidator(EnvValue.optional),
        FromEnv(
            params.StringParam(
                "AI_TEMPERATURE",
                default="",
                description="Sampling temperature; empty = the model's own default. For Gemini 3 Google "
                "strongly recommends that default (1.0): lower values can loop or degrade.",
            )
        ),
    ] = None
    timeout_sec: Annotated[Positive, FromEnv(RuntimeSettings.param("timeout_sec"))]


class VertexSettings(Section):
    """Gemini on Vertex AI (provider `vertex`). The runtime service account needs
    roles/aiplatform.user."""

    location: Annotated[
        Words,
        FromEnv(
            params.StringParam(
                "VERTEX_LOCATION",
                default="us-central1",
                description="Vertex AI region for Gemini calls.",
            )
        ),
    ]
    thinking_level: Annotated[
        Level,
        FromEnv(
            params.StringParam(
                "VERTEX_THINKING_LEVEL",
                default="low",
                description="Gemini 3 thinking level: low | medium | high. Thinking cannot be switched off on "
                "3.x Flash (3.8 rejects `minimal`) and its tokens bill as output, so `low` is the cost floor. "
                "Empty = do not send (the model then defaults to high).",
            )
        ),
    ] = None
    media_resolution: Annotated[
        Level,
        FromEnv(
            params.StringParam(
                "VERTEX_MEDIA_RESOLUTION",
                default="high",
                description="Tokens Gemini 3 spends per screenshot: low 280, medium 560, high 1120. Chat "
                "screenshots need high to read the bubbles. Empty = the model's default (high).",
            )
        ),
    ] = None


class OllamaSettings(Section):
    """A model on this machine (provider `ollama`), for the emulator and the tests."""

    url: Annotated[
        str,
        BeforeValidator(EnvValue.base_url),
        Field(min_length=1),
        FromEnv(
            params.StringParam(
                "OLLAMA_URL",
                default="http://127.0.0.1:11434",
                description="Ollama server for ollama/… models.",
            )
        ),
    ]
    context_tokens: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "OLLAMA_CONTEXT_TOKENS",
                default=32768,
                description="Context window per call (num_ctx). Ollama's default is far smaller and it drops "
                "the start of a longer prompt without an error, the system prompt first; each screenshot "
                "costs one to two thousand tokens.",
            )
        ),
    ]


# ── requests and storage ─────────────────────────────────────────────────────


class RequestLimits(Section):
    """What one request may carry, and how much of a chat reaches the model. The app downscales
    every screenshot before upload, so the byte caps are a ceiling against a client that
    doesn't, not the size we expect."""

    max_images: Annotated[
        int,
        Field(ge=0),
        FromEnv(
            params.IntParam(
                "MAX_IMAGES",
                default=10,
                description="Screenshots per request / per chat turn.",
            )
        ),
    ]
    max_image_bytes: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "MAX_IMAGE_BYTES",
                default=4_000_000,
                description="Bytes per screenshot; the app sends ~0.3 MB.",
            )
        ),
    ]
    max_total_image_bytes: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "MAX_TOTAL_IMAGE_BYTES",
                default=16_000_000,
                description="Bytes of all screenshots in one request (base64 inflates this by a third).",
            )
        ),
    ]
    max_messages: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "MAX_MESSAGES",
                default=200,
                description="Newest chat turns sent to the model. Matches MAX_MESSAGES_PER_CONVERSATION, so the "
                "model sees the whole chat; lower it only to cut token cost.",
            )
        ),
    ]
    max_lines: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "MAX_LINES",
                default=3,
                description="Lines returned per answer (the UI shows three cards).",
            )
        ),
    ]


class ImageSettings(Section):
    """How screenshots are re-encoded and where they are kept."""

    max_side: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "IMAGE_MAX_SIDE",
                default=1600,
                description="Longest side in pixels after server-side re-encoding.",
            )
        ),
    ]
    jpeg_quality: Annotated[
        int,
        Field(ge=1, le=100),
        FromEnv(
            params.IntParam(
                "IMAGE_JPEG_QUALITY",
                default=85,
                description="JPEG quality of stored screenshots.",
            )
        ),
    ]
    bucket: Annotated[
        str | None,
        BeforeValidator(EnvValue.optional_text),
        FromEnv(
            params.StringParam(
                "STORAGE_BUCKET",
                default="",
                description="Bucket for screenshots; empty = the project's default Firebase bucket.",
            )
        ),
    ] = None


class ConversationSettings(Section):
    """Backend-owned conversations: the chat cap and the history-list texts."""

    max_messages: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "MAX_MESSAGES_PER_CONVERSATION",
                default=200,
                description="Turns per conversation before a new one is required.",
            )
        ),
    ]
    preview_chars: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "PREVIEW_CHARS",
                default=140,
                description="Length of the history-list preview text.",
            )
        ),
    ]
    title_chars: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "TITLE_CHARS",
                default=60,
                description="Length of the derived conversation title.",
            )
        ),
    ]


class QueueSettings(Section):
    """The `generate` task queue: the rate limiter (project-wide, not per user) and the retry
    policy. The rates are the queue's own settings, fixed at deploy time; both ceilings sit
    above what MAX_INSTANCES can serve, so they bound a burst rather than the steady rate.
    `max_attempts` also tells the worker which attempt is its last."""

    max_attempts: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "QUEUE_MAX_ATTEMPTS",
                default=3,
                description="Attempts per generation before the turn is marked failed.",
            )
        ),
    ]
    max_dispatches_per_second: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "QUEUE_MAX_DISPATCHES_PER_SECOND",
                default=100,
                description="Model calls started per second across the project.",
            )
        ),
    ]
    max_concurrent_dispatches: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "QUEUE_MAX_CONCURRENT_DISPATCHES",
                default=1000,
                description="Model calls outstanding at once across the project.",
            )
        ),
    ]


class LinesSettings(Section):
    """What the Lines tab generation must produce, and how it is asked for."""

    refresh_interval_hours: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "LINES_REFRESH_INTERVAL_HOURS",
                default=24,
                description="How often `refresh_lines` regenerates the Lines tab content; also the "
                "Cache-Control max-age and the app's on-device cache TTL. Fixed at deploy time.",
            )
        ),
    ]
    category_ids: Annotated[
        Csv,
        FromEnv(
            params.StringParam(
                "LINES_CATEGORY_IDS",
                default="opening,followup,closing",
                description="Comma-separated ids of the categories a generation must produce, in the order "
                "the app renders them. They reach the model as the enum of the response schema, so nothing "
                "else can come back; changing them means revisiting the task prompt and the bundled "
                "fallback content in features/lines_that_land/domain/content.py.",
            )
        ),
    ]
    per_category: Annotated[
        Positive,
        FromEnv(
            params.IntParam(
                "LINES_PER_CATEGORY",
                default=5,
                description="Lines the model writes per category.",
            )
        ),
    ]
    locales: Annotated[
        Csv,
        FromEnv(
            params.StringParam(
                "LINES_LOCALES",
                default="en,es",
                description="Comma-separated BCP-47 tags every generated text must carry. They become the "
                "required properties of each text in the response schema, so the model writes all of them "
                "or the generation fails. The bundled fallback content is written in en and es whatever "
                "this says, and the endpoint reports the languages the content actually has.",
            )
        ),
    ]
    system_prompt: Annotated[
        Words,
        FromEnv(
            params.StringParam(
                "LINES_SYSTEM_PROMPT",
                default="You write ready-to-paste lines for a BUYER negotiating on peer-to-peer marketplaces "
                "(Facebook Marketplace, eBay, Craigslist, OLX). Every line is one message the buyer sends "
                "the seller: short, natural, specific, never rude, never a template with placeholders.",
                description="Who the model is while it writes the Lines tab.",
            )
        ),
    ]
    task_prompt: Annotated[
        Words,
        FromEnv(
            params.StringParam(
                "LINES_TASK_PROMPT",
                default="Produce exactly {count} categories with these ids and nothing else: {categories} — "
                "the opening message, the follow-up when the seller hesitates or goes quiet, and the line "
                "that closes the deal. Name each category in two or three words. Give each category exactly "
                "{lines_per_category} lines, all different in tactic: they should cover price anchoring, "
                "bundling or pickup convenience, naming a flaw, walking away politely, and agreeing quickly. "
                "No line mentions a specific item, brand or price. Write every text in all of these "
                "languages: {locales}.",
                description="What one generation must produce. Filled in at call time: {categories}, "
                "{count}, {lines_per_category}, {locales} — the values of the settings above, so the prompt "
                "and the response schema cannot disagree. An unknown placeholder is left as written rather "
                "than failing the run.",
            )
        ),
    ]


class SecuritySettings(Section):
    require_app_check: Annotated[
        bool,
        FromEnv(
            params.BoolParam(
                "REQUIRE_APP_CHECK",
                default=False,
                description="Reject requests without a valid X-Firebase-AppCheck token (turn on once the app ships App Check).",
            )
        ),
    ]


class Settings:
    """Every section, for tooling that wants the whole list (tests, docs)."""

    SECTIONS: ClassVar[tuple[type[Section], ...]] = (
        RuntimeSettings,
        ModelSettings,
        VertexSettings,
        OllamaSettings,
        RequestLimits,
        ImageSettings,
        ConversationSettings,
        QueueSettings,
        LinesSettings,
        SecuritySettings,
    )

    @classmethod
    def variables(cls) -> list[str]:
        """Every environment variable, once (a param shared by two sections counts once)."""
        return list(
            dict.fromkeys(
                param.name for section in cls.SECTIONS for param in section.sources().values()
            )
        )
