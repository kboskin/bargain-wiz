"""What the Lines tab shows, and the schema Gemini is held to when it writes it.

[GeneratedLines] is the response schema the generation is constrained to, the validation of
what comes back, the shape stored in Firestore and the shape served — one declaration, no
normalisation step. [current] is what the endpoint asks for: the stored content when there is
some, else [FALLBACK_CATEGORIES], so the tab always has something to show.

Which categories and which languages a generation must produce are configuration
([category_ids], [locales]). They reach Gemini as part of the response schema, which the SDK
builds per call — so a change in `.env` changes what the model may answer, while content
stored or bundled under an older setting still reads back.
"""
import logging
from datetime import UTC, datetime
from typing import Annotated, Literal, Protocol

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field

from core import config

logger = logging.getLogger("lines_that_land")


def category_ids() -> tuple[str, ...]:
    """The categories one generation must produce, in the order the app renders them."""
    return _csv(config.LINES_CATEGORY_IDS.value)


def locales() -> tuple[str, ...]:
    """The languages every generated text must carry."""
    return _csv(config.LINES_LOCALES.value)


def _csv(value: str) -> tuple[str, ...]:
    return tuple(part.strip() for part in value.split(",") if part.strip())


# ── the shape of the content (and the response schema Gemini is held to) ──────


def _texts(value: object) -> dict[str, str]:
    """`{tag: text}`, trimmed. Which tags must be there is the schema's job (see below), so a
    text that arrives with fewer — bundled content, a document from an older setting — is kept
    rather than rejected."""
    if not isinstance(value, dict):
        raise ValueError("must be a map of language tag to text")
    texts = {str(tag): text.strip() for tag, text in value.items() if isinstance(text, str) and text.strip()}
    if not texts:
        raise ValueError("must have a text in at least one language")
    return texts


LocaleText = Annotated[dict[str, str], BeforeValidator(_texts)]


def _as_locale_text(schema: dict) -> None:
    """Turn a `{tag: text}` map into the object Gemini has to fill: one required string per
    configured language. Written when the schema is built (once per call, by the SDK), which
    is what lets the languages live in `.env`."""
    tags = list(locales())
    schema.pop("additionalProperties", None)
    schema["type"] = "object"
    schema["properties"] = {
        tag: {
            "type": "string",
            "description": f"The text in the language of the BCP-47 tag {tag}, as a native "
            "speaker would write it — not a word-for-word translation of another language.",
        }
        for tag in tags
    }
    schema["required"] = tags


# Docstrings and `Field(description=…)` below travel to Gemini as the response schema, so they
# are prompt as much as documentation.
class Category(BaseModel):
    """One card in the Lines tab: a named group of ready-to-paste lines."""

    model_config = ConfigDict(frozen=True)

    id: str = Field(
        min_length=1,
        json_schema_extra=lambda schema: schema.update(enum=list(category_ids())),
        description="Which category this is.",
    )
    name: LocaleText = Field(
        json_schema_extra=_as_locale_text,
        description="The category title, two or three words.",
    )
    tips: list[LocaleText] = Field(
        min_length=1,
        json_schema_extra=lambda schema: _as_locale_text(schema["items"]),
        description="The lines of this category, each one complete message the buyer can send as it is.",
    )


class GeneratedLines(BaseModel):
    """One generation: the whole content of the tab."""

    categories: list[Category] = Field(
        min_length=1, description="One entry per category, in the order the task asks for."
    )


class LinesContent(BaseModel):
    """Current lines plus provenance."""

    model_config = ConfigDict(frozen=True)

    categories: list[Category]
    updated_at: datetime  # timezone-aware UTC; when the content was generated
    source: Literal["generated", "fallback"]


def categories_json(categories: list[Category]) -> list[dict]:
    """Plain JSON: what the endpoint sends and what Firestore stores."""
    return [category.model_dump() for category in categories]


def locales_of(categories: list[Category]) -> list[str]:
    """The languages this content actually has — [locales] for a generation, but the bundled
    fallback keeps the two it was written in whatever the config says."""
    return sorted({tag for category in categories for text in (category.name, *category.tips) for tag in text})


# Built-in content: served until the first generation lands, and whenever one fails.
FALLBACK_CATEGORIES: tuple[Category, ...] = (
    Category(
        id="opening",
        name={"en": "Opening lines", "es": "Frases de apertura"},
        tips=[
            {"en": "Is there flexibility on the price?", "es": "¿Hay flexibilidad en el precio?"},
            {"en": "What's the best you can do?", "es": "¿Cuál es lo mejor que puedes hacer?"},
            {
                "en": "I've seen similar for less—can you match that?",
                "es": "He visto algo similar por menos, ¿puedes igualarlo?",
            },
        ],
    ),
    Category(
        id="followup",
        name={"en": "Follow-ups", "es": "Seguimientos"},
        tips=[
            {"en": "I'm ready to move if we can agree on X.", "es": "Estoy listo para cerrar si acordamos X."},
            {"en": "Can we meet in the middle?", "es": "¿Nos encontramos a mitad de camino?"},
            {"en": "If I take two, would that help on the price?", "es": "Si me llevo dos, ¿ayudaría con el precio?"},
        ],
    ),
    Category(
        id="closing",
        name={"en": "Closing", "es": "Cierre"},
        tips=[
            {"en": "That works for me. Let's do it.", "es": "Me funciona. Hagámoslo."},
            {"en": "I can commit today at that price.", "es": "Puedo comprometerme hoy a ese precio."},
            {"en": "Done. When can I pick it up?", "es": "Hecho. ¿Cuándo puedo recogerlo?"},
        ],
    ),
)


class LinesStore(Protocol):
    def read(self) -> LinesContent | None:
        """The stored content, or None before the first generation."""

    def write(self, categories: list[Category], *, model: str) -> LinesContent:
        """Replace the stored content and return what a reader would now see."""


def fallback_content() -> LinesContent:
    """The bundled lines, used until a generation lands."""
    return LinesContent(categories=list(FALLBACK_CATEGORIES), updated_at=datetime.now(UTC), source="fallback")


def current(store: LinesStore) -> LinesContent:
    """What the endpoint serves: the generated content when there is some, else the bundled one."""
    try:
        stored = store.read()
    except Exception as exc:  # noqa: BLE001 - the tab must never fail on a storage hiccup
        logger.warning("could not read the stored lines (%s); serving the bundled ones", exc)
        stored = None
    return stored or fallback_content()
