"""What the Lines tab shows, and the schema the model is held to when it writes it.

[GeneratedLines] is the response schema the generation is constrained to, the validation of
what comes back, the shape stored in Firestore and the shape served — one declaration, no
normalisation step. When nothing has been generated yet, the tab shows
[LinesContent.fallback], so it always has something to show.

Which categories and which languages a generation must produce are configuration
(`LinesSettings`). They reach the model as part of the response schema, which is built per
call — so a change in `.env` changes what the model may answer, while content stored or
bundled under an older setting still reads back.
"""

from datetime import datetime
from typing import Annotated, Literal, Self

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field

from core.config import LinesSettings


class LocaleTexts:
    """A text in several languages: `{BCP-47 tag: text}`."""

    @staticmethod
    def clean(value: object) -> dict[str, str]:
        """Trimmed. Which tags must be there is the schema's job ([schema]), so a text that
        arrives with fewer — bundled content, a document from an older setting — is kept
        rather than rejected."""
        if not isinstance(value, dict):
            raise ValueError("must be a map of language tag to text")
        texts = {
            str(tag): text.strip()
            for tag, text in value.items()
            if isinstance(text, str) and text.strip()
        }
        if not texts:
            raise ValueError("must have a text in at least one language")
        return texts

    @staticmethod
    def schema(schema: dict) -> None:
        """Turn a `{tag: text}` map into the object the model has to fill: one required string
        per configured language. Written when the schema is built (once per call), which is
        what lets the languages live in `.env`."""
        tags = list(LinesSettings.current().locales)
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

    @staticmethod
    def schema_of_items(schema: dict) -> None:
        LocaleTexts.schema(schema["items"])

    @staticmethod
    def schema_of_ids(schema: dict) -> None:
        schema.update(enum=list(LinesSettings.current().category_ids))


LocaleText = Annotated[dict[str, str], BeforeValidator(LocaleTexts.clean)]


# Docstrings and `Field(description=…)` below travel to the model as the response schema, so
# they are prompt as much as documentation.
class Category(BaseModel):
    """One card in the Lines tab: a named group of ready-to-paste lines."""

    model_config = ConfigDict(frozen=True)

    id: str = Field(
        min_length=1,
        json_schema_extra=LocaleTexts.schema_of_ids,
        description="Which category this is.",
    )
    name: LocaleText = Field(
        json_schema_extra=LocaleTexts.schema, description="The category title, two or three words."
    )
    tips: list[LocaleText] = Field(
        min_length=1,
        json_schema_extra=LocaleTexts.schema_of_items,
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

    def categories_json(self) -> list[dict]:
        """Plain JSON: what the endpoint sends and what Firestore stores."""
        return [category.model_dump() for category in self.categories]

    def locales(self) -> list[str]:
        """The languages this content actually has — LINES_LOCALES for a generation, but the
        bundled fallback keeps the two it was written in whatever the config says."""
        return sorted(
            {
                tag
                for category in self.categories
                for text in (category.name, *category.tips)
                for tag in text
            }
        )

    @classmethod
    def fallback(cls, now: datetime) -> Self:
        """The bundled lines: served until the first generation lands, and whenever one fails."""
        return cls(categories=cls.fallback_categories(), updated_at=now, source="fallback")

    @staticmethod
    def fallback_categories() -> list[Category]:
        return [
            Category(
                id="opening",
                name={"en": "Opening lines", "es": "Frases de apertura"},
                tips=[
                    {
                        "en": "Is there flexibility on the price?",
                        "es": "¿Hay flexibilidad en el precio?",
                    },
                    {
                        "en": "What's the best you can do?",
                        "es": "¿Cuál es lo mejor que puedes hacer?",
                    },
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
                    {
                        "en": "I'm ready to move today if we can agree on a price.",
                        "es": "Estoy listo para cerrar hoy si acordamos un precio.",
                    },
                    {
                        "en": "Can we meet in the middle?",
                        "es": "¿Nos encontramos a mitad de camino?",
                    },
                    {
                        "en": "If I take two, would that help on the price?",
                        "es": "Si me llevo dos, ¿ayudaría con el precio?",
                    },
                ],
            ),
            Category(
                id="closing",
                name={"en": "Closing", "es": "Cierre"},
                tips=[
                    {"en": "That works for me. Let's do it.", "es": "Me funciona. Hagámoslo."},
                    {
                        "en": "I can commit today at that price.",
                        "es": "Puedo comprometerme hoy a ese precio.",
                    },
                    {"en": "Done. When can I pick it up?", "es": "Hecho. ¿Cuándo puedo recogerlo?"},
                ],
            ),
        ]
