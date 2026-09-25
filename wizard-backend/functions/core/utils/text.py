"""Text normalisation for what clients send and what the history list shows."""


class Text:
    ELLIPSIS = "…"

    @staticmethod
    def trim(value: object) -> str | None:
        """Whitespace-trimmed string or None. No length limit: what the buyer pasted is the
        material to work from, and the model's context is far larger than anything typed.
        Non-strings raise ValueError, which pydantic reports as a validation error."""
        if value is None:
            return None
        if not isinstance(value, str):
            raise ValueError("must be a string")
        return value.strip() or None

    @classmethod
    def clip(cls, value: object, max_chars: int, *, ellipsis: bool = True) -> str | None:
        """Trimmed string or None, truncated to [max_chars] (with "…" when [ellipsis]) rather
        than rejected: a buyer pasting a long chat should not get an error for it."""
        text = cls.trim(value)
        if text is not None and len(text) > max_chars:
            text = text[:max_chars].rstrip() + cls.ELLIPSIS if ellipsis else text[:max_chars]
        return text

    @classmethod
    def clip_words(cls, text: str, max_chars: int) -> str:
        """Whitespace collapsed and cut at a word boundary to at most [max_chars], plus "…"."""
        text = " ".join(text.split())
        if len(text) <= max_chars:
            return text
        cut = text[:max_chars].rsplit(" ", 1)[0].rstrip(" ,.;:-–—")
        return (cut or text[:max_chars]) + cls.ELLIPSIS

    @staticmethod
    def strip(value: object) -> object:
        """A string stripped of surrounding whitespace; anything else unchanged (for pydantic
        `BeforeValidator`s, so the type check still reports a non-string)."""
        return value.strip() if isinstance(value, str) else value
