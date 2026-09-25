"""What an answer must look like, as pydantic models.

Each model is three things at once: the response schema the model is constrained to, the
validation of what comes back, and the shape the app reads — the body of the stateless
endpoints, and the `lines` / `express` fields of a conversation document.

Parsing forgives what a model can drift on and the app would not care about: a line with no
text is dropped, a missing or unknown intent is assigned by position (opener, counter, close)
and at most MAX_LINES are kept. What cannot be repaired — no usable line, an empty reply —
fails validation, which the model manager reports as an [InvalidModelAnswer] (502).
"""

from typing import Annotated, ClassVar, Literal

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, field_serializer

from core.config import RequestLimits
from core.utils import Text


class Line(BaseModel):
    """One message the buyer pastes to the seller, and why it works."""

    model_config = ConfigDict(frozen=True)

    INTENTS: ClassVar[tuple[str, ...]] = ("opener", "counter", "close")

    intent: Literal["opener", "counter", "close"]
    text: str
    why: str = ""

    @field_serializer("why")
    def _why(self, why: str) -> str | None:
        return why or None

    @classmethod
    def normalize_all(cls, raw: object) -> list[dict]:
        """Up to MAX_LINES non-empty lines, each with an intent (by position when missing)."""
        limit = RequestLimits.current().max_lines
        out: list[dict] = []
        for item in raw if isinstance(raw, list) else []:
            if len(out) >= limit:
                break
            if isinstance(item, Line):
                item = item.model_dump()
            if not isinstance(item, dict):
                continue
            text = str(item.get("text") or "").strip()
            if not text:
                continue
            intent = str(item.get("intent") or "").strip().lower()
            if intent not in cls.INTENTS:
                intent = cls.INTENTS[min(len(out), len(cls.INTENTS) - 1)]
            out.append({"intent": intent, "text": text, "why": str(item.get("why") or "").strip()})
        return out


Lines = Annotated[list[Line], BeforeValidator(Line.normalize_all), Field(min_length=1)]


class ExpressAnswer(BaseModel):
    """An Express deal: one line on what the screenshots show, and three lines to send."""

    model_config = ConfigDict(frozen=True)

    seeing: Annotated[str, BeforeValidator(Text.strip)]
    lines: Lines


class ReplyAnswer(BaseModel):
    """The wizard's reply in a Pro chat."""

    model_config = ConfigDict(frozen=True)

    reply: Annotated[str, BeforeValidator(Text.strip), Field(min_length=1)]


class OptionsAnswer(BaseModel):
    """Three lines the buyer can send right now, for a Pro chat."""

    model_config = ConfigDict(frozen=True)

    lines: Lines
