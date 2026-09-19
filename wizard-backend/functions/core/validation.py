"""Small validation helpers shared by the pydantic models."""
from pydantic import ValidationError

from core.errors import BadRequest


def validate_model(model_cls, data, error_cls: type[Exception] = BadRequest):
    """`model_cls.model_validate(data)`, turning pydantic errors into a client-facing
    [error_cls] with a compact "field: problem; field: problem" message."""
    try:
        return model_cls.model_validate(data)
    except ValidationError as exc:
        details = []
        for err in exc.errors()[:5]:
            loc = ".".join(str(part) for part in err["loc"]) or "body"
            details.append(f"{loc}: {err['msg'].removeprefix('Value error, ')}")
        raise error_cls("; ".join(details)) from exc


def clip_text(value: object, max_chars: int, *, ellipsis: bool = True) -> str | None:
    """Trimmed string or None. Over-long text is truncated (with "…" when [ellipsis]) rather
    than rejected: a buyer pasting a long chat should not get an error for it. Non-strings
    raise ValueError, which pydantic reports as a validation error."""
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError("must be a string")
    text = value.strip()
    if len(text) > max_chars:
        text = text[:max_chars].rstrip() + "…" if ellipsis else text[:max_chars]
    return text or None


def trimmed(value: object) -> str | None:
    """Whitespace-trimmed string or None. No length limit: what the buyer pasted is the
    material to work from, and the model's context is far larger than anything typed."""
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError("must be a string")
    return value.strip() or None


def number_or_none(value: object) -> float | None:
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, int | float):
        raise ValueError("must be a number")
    return float(value)
