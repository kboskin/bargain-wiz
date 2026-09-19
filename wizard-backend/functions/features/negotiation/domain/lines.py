"""What an answer must look like and what we keep of it.

The response schemas are hand-written JSON schema (not a pydantic model like the Lines tab
uses) because these three shapes are also what the app reads back verbatim.
"""
from core import config
from core.errors import UpstreamError

INTENTS = ("opener", "counter", "close")

LINES_SCHEMA = {
    "type": "array",
    "items": {
        "type": "object",
        "properties": {
            "intent": {"type": "string", "enum": list(INTENTS)},
            "text": {"type": "string"},
            "why": {"type": "string"},
        },
        "required": ["intent", "text"],
    },
}

EXPRESS_SCHEMA = {
    "type": "object",
    "properties": {"seeing": {"type": "string"}, "lines": LINES_SCHEMA},
    "required": ["seeing", "lines"],
}

REPLY_SCHEMA = {"type": "object", "properties": {"reply": {"type": "string"}}, "required": ["reply"]}

OPTIONS_SCHEMA = {"type": "object", "properties": {"lines": LINES_SCHEMA}, "required": ["lines"]}


# ── result shaping ────────────────────────────────────────────────────────────


def normalize_lines(raw) -> list[dict]:
    """Keep up to config.MAX_LINES.value non-empty lines; fix missing/unknown intents by position
    (opener, counter, close)."""
    out: list[dict] = []
    for item in raw if isinstance(raw, list) else []:
        if len(out) >= config.MAX_LINES.value:
            break
        if not isinstance(item, dict):
            continue
        text = str(item.get("text") or "").strip()
        if not text:
            continue
        intent = str(item.get("intent") or "").strip().lower()
        if intent not in INTENTS:
            intent = INTENTS[min(len(out), len(INTENTS) - 1)]
        why = str(item.get("why") or "").strip()
        out.append({"intent": intent, "text": text, "why": why or None})
    return out


def express_result(raw: dict) -> dict:
    lines = normalize_lines(raw.get("lines"))
    if not lines:
        raise UpstreamError("model returned no lines")
    return {"seeing": str(raw.get("seeing") or "").strip(), "lines": lines}


def reply_result(raw: dict) -> dict:
    reply = str(raw.get("reply") or "").strip()
    if not reply:
        raise UpstreamError("model returned an empty reply")
    return {"reply": reply}


def options_result(raw: dict) -> dict:
    lines = normalize_lines(raw.get("lines"))
    if not lines:
        raise UpstreamError("model returned no lines")
    return {"lines": lines}
