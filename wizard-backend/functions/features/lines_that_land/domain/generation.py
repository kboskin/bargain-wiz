"""Asking Gemini for a fresh set of lines.

Run by the `refresh_lines` schedule. Both prompts are params (`LINES_SYSTEM_PROMPT`,
`LINES_TASK_PROMPT` in `.env`), read per call; the task prompt is filled in with the same
values that build the response schema, so it cannot ask for something the schema forbids.
[content.GeneratedLines] says what shape the answer must come back in and the generator
validates it — nothing here parses.
"""
from core import config
from core.ai.vertex import JsonGenerator

from .content import Category, GeneratedLines, category_ids, locales


class _Placeholders(dict):
    """A placeholder nobody fills is left as written: a typo in `.env` shows up in the prompt
    instead of failing the scheduled run."""

    def __missing__(self, key: str) -> str:
        return "{" + key + "}"


def task_prompt() -> str:
    """`LINES_TASK_PROMPT` with the categories, the line count and the languages filled in."""
    ids = category_ids()
    return config.LINES_TASK_PROMPT.value.format_map(
        _Placeholders(
            categories=", ".join(ids),
            count=len(ids),
            lines_per_category=config.LINES_PER_CATEGORY.value,
            locales=", ".join(locales()),
        )
    )


def generate_categories(generator: JsonGenerator) -> list[Category]:
    """One model call → the categories to store. The answer is constrained to [GeneratedLines]
    and validated against it, so anything unusable surfaces as an [UpstreamError] (vertex.py)."""
    generated = generator.generate(
        system=config.LINES_SYSTEM_PROMPT.value,
        parts=[{"type": "text", "text": task_prompt()}],
        response_model=GeneratedLines,
    )
    return generated.categories
