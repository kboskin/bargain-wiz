"""Content for the `lines_that_land` callable.

Reads the `lines_that_land_categories` parameter from this project's **server** Remote Config
template with the Firebase Admin SDK (`firebase_admin.remote_config`) and normalises every text
to a `{"en": …, "es": …}` map. The built-in defaults are registered as the template's
`default_config`, so `evaluate()` always yields content even when Remote Config is down.
"""
import asyncio
import json
import logging
from datetime import UTC, datetime
from typing import Any, Literal, Protocol

from firebase_admin import remote_config
from pydantic import BaseModel, ConfigDict

logger = logging.getLogger("lines_that_land")

PARAM_KEY = "lines_that_land_categories"
DEFAULT_LANG = "en"

# Built-in content: served while the parameter is missing/unusable or Remote Config is down.
FALLBACK_CATEGORIES: list[dict] = [
    {
        "id": "opening",
        "name": {"en": "Opening lines", "es": "Frases de apertura"},
        "tips": [
            {"en": "Is there flexibility on the price?", "es": "¿Hay flexibilidad en el precio?"},
            {"en": "What's the best you can do?", "es": "¿Cuál es lo mejor que puedes hacer?"},
            {
                "en": "I've seen similar for less—can you match that?",
                "es": "He visto algo similar por menos, ¿puedes igualarlo?",
            },
        ],
    },
    {
        "id": "followup",
        "name": {"en": "Follow-ups", "es": "Seguimientos"},
        "tips": [
            {
                "en": "I'm ready to move if we can agree on X.",
                "es": "Estoy listo para cerrar si acordamos X.",
            },
            {"en": "Can we meet in the middle?", "es": "¿Nos encontramos a mitad de camino?"},
            {
                "en": "If I take two, would that help on the price?",
                "es": "Si me llevo dos, ¿ayudaría con el precio?",
            },
        ],
    },
    {
        "id": "closing",
        "name": {"en": "Closing", "es": "Cierre"},
        "tips": [
            {"en": "That works for me. Let's do it.", "es": "Me funciona. Hagámoslo."},
            {
                "en": "I can commit today at that price.",
                "es": "Puedo comprometerme hoy a ese precio.",
            },
            {"en": "Done. When can I pick it up?", "es": "Hecho. ¿Cuándo puedo recogerlo?"},
        ],
    },
]

# After serving the fallback, retry Remote Config this soon instead of waiting a full interval.

# Template with no parameters: evaluate() then resolves everything from default_config.
_EMPTY_TEMPLATE_JSON = json.dumps({"parameters": {}, "conditions": []})


class LinesContent(BaseModel):
    """Current lines plus provenance."""

    model_config = ConfigDict(frozen=True)

    categories: list[dict]
    updated_at: datetime  # timezone-aware UTC
    source: Literal["remote_config", "fallback"]


# ── text helpers ──────────────────────────────────────────────────────────────


def normalize_text(value: object) -> dict[str, str] | None:
    """A plain string (English) or a `{lang: text}` map → trimmed `{lang: text}`; None if empty."""
    if isinstance(value, str):
        text = value.strip()
        return {DEFAULT_LANG: text} if text else None
    if isinstance(value, dict):
        out = {str(k): v.strip() for k, v in value.items() if isinstance(v, str) and v.strip()}
        return out or None
    return None


def parse_categories(decoded: object) -> list[dict]:
    """Normalise `{"categories": [{id, name, tips}]}` to multilocale texts; drops incomplete
    or empty entries."""
    items = decoded.get("categories") if isinstance(decoded, dict) else None
    out: list[dict] = []
    for item in items or []:
        if not isinstance(item, dict):
            continue
        cid = item.get("id")
        name = normalize_text(item.get("name"))
        tips_raw = item.get("tips")
        tips = [t for t in map(normalize_text, tips_raw if isinstance(tips_raw, list) else []) if t]
        if cid and name and tips:
            out.append({"id": str(cid), "name": name, "tips": tips})
    return out


def locales_of(categories: list[dict]) -> list[str]:
    """Sorted language codes present anywhere in the content."""
    langs: set[str] = set()
    for category in categories:
        langs.update(category["name"])
        for tip in category["tips"]:
            langs.update(tip)
    return sorted(langs)


# ── Remote Config ─────────────────────────────────────────────────────────────


class ServerTemplateLike(Protocol):
    """The part of `remote_config.ServerTemplate` used here (lets tests inject a fake)."""

    async def load(self) -> None: ...
    def set(self, template_data_json: str) -> None: ...
    def evaluate(self, context: dict | None = None) -> Any: ...
    def to_json(self) -> str: ...


def new_template() -> remote_config.ServerTemplate:
    """Server template for the default Firebase app, with the built-in content as default."""
    return remote_config.init_server_template(
        default_config={PARAM_KEY: json.dumps({"categories": FALLBACK_CATEGORIES}, ensure_ascii=False)}
    )


def fallback_content() -> LinesContent:
    return LinesContent(
        categories=parse_categories({"categories": FALLBACK_CATEGORIES}),
        updated_at=datetime.now(UTC),
        source="fallback",
    )


def template_updated_at(template: ServerTemplateLike) -> datetime:
    """`version.updateTime` of the loaded template, else now."""
    try:
        update_time = json.loads(template.to_json()).get("version", {}).get("updateTime")
        if update_time:
            return datetime.fromisoformat(update_time).astimezone(UTC)
    except (ValueError, AttributeError, TypeError) as exc:
        logger.debug("template version unavailable (%s)", exc)
    return datetime.now(UTC)


def read_content(template: ServerTemplateLike) -> LinesContent:
    """Evaluate the loaded template and parse PARAM_KEY; built-in defaults when unusable."""
    config = template.evaluate()
    remote = config.get_value_source(PARAM_KEY) == "remote"
    try:
        categories = parse_categories(json.loads(config.get_string(PARAM_KEY) or "null"))
    except ValueError as exc:
        logger.warning("Remote Config %s is not valid JSON (%s)", PARAM_KEY, exc)
        categories = []
    if not categories:
        if remote:
            logger.warning("Remote Config %s has no usable categories; serving defaults", PARAM_KEY)
        return fallback_content()
    if not remote:
        return LinesContent(categories=categories, updated_at=datetime.now(UTC), source="fallback")
    return LinesContent(
        categories=categories, updated_at=template_updated_at(template), source="remote_config"
    )


def load_content(template: ServerTemplateLike | None = None) -> LinesContent:
    """Load the server template and parse PARAM_KEY. Remote Config down or unusable → the
    built-in defaults, so the endpoint always answers. Called per request: the response is
    cacheable for LINES_REFRESH_INTERVAL_HOURS and the app caches on device."""
    template = template if template is not None else new_template()
    try:
        asyncio.run(template.load())
    except Exception as exc:  # noqa: BLE001 - any Remote Config failure degrades gracefully
        logger.warning("Remote Config unavailable (%s); serving built-in defaults", exc)
        template.set(_EMPTY_TEMPLATE_JSON)
    return read_content(template)
