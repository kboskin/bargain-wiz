"""Request parsing, prompting and result shaping for the AI negotiation functions.

Pure Python (no SDK imports) so the behaviour is unit-testable; `main.py` wires it to a
`JsonGenerator`. Shared by `express_dealmaker` (screenshots → lines) and
`pro_deal_closer` (chat coaching → reply / lines).
"""
import base64
import binascii
from dataclasses import dataclass, field

SUPPORTED_MIME = {"image/jpeg", "image/png", "image/webp"}
MAX_IMAGES = 6
MAX_IMAGE_BYTES = 1_500_000
MAX_TOTAL_IMAGE_BYTES = 6_000_000
MAX_TEXT_CHARS = 8_000
MAX_MESSAGE_CHARS = 4_000
MAX_MESSAGES = 40
INTENTS = ("opener", "counter", "close")
MAX_LINES = 3  # the UI shows three cards; anything past that is noise
DEFAULT_VIBE = "friendly"
DEFAULT_PUSH = 60

LANGUAGES = {"en": "English", "es": "Spanish"}

# Tone presets — ids match onboarding `negotiation_vibe` / WizCatalog.
VIBES = {
    "friendly": "Friendly Collaborator: warm and polite, builds rapport, asks nicely, "
    "still anchors below the asking price.",
    "no_nonsense": "No-Nonsense Buyer: direct and brief, values time over small talk, "
    "states numbers plainly, no apologies.",
    "tactical": "Tactical Strategist: uses logic, comparable prices and product flaws as "
    "leverage; persistent but fair.",
    "quiet_closer": "Quiet Closer: subtle, low-pressure and non-confrontational, yet always "
    "moves the deal towards a close.",
}

MARKETPLACES = {
    "ebay": "eBay: written offers/messages, buyer protection, shipping cost is a lever.",
    "amazon": "Amazon third-party seller: formal messages, little price room; focus on "
    "bundles, shipping, condition or partial refunds.",
    "facebook": "Facebook Marketplace: casual chat, local pickup, cash; speed and certainty win.",
    "olx": "OLX: local classifieds chat, pickup, haggling is expected.",
    "craigslist": "Craigslist: email/text, cash on pickup, safety first, haggling is expected.",
}


class BadRequest(ValueError):
    """Client error → 400."""


@dataclass(frozen=True)
class Image:
    mime_type: str
    data: bytes


@dataclass(frozen=True)
class Profile:
    vibe: str = DEFAULT_VIBE
    push: int = DEFAULT_PUSH
    marketplace: str | None = None
    deal_size: float | None = None
    locale: str = "en"

    @property
    def language(self) -> str:
        return LANGUAGES.get(self.locale.split("-")[0].lower(), "English")


@dataclass(frozen=True)
class ExpressRequest:
    profile: Profile
    images: list[Image]
    text: str | None
    keyword: str | None


@dataclass(frozen=True)
class ChatMessage:
    role: str  # "user" | "wizard"
    text: str
    images: list[Image] = field(default_factory=list)


@dataclass(frozen=True)
class ProRequest:
    profile: Profile
    messages: list[ChatMessage]
    mode: str  # "reply" | "options"
    regenerate: bool = False


# ── parsing ───────────────────────────────────────────────────────────────────


def _text(value, max_chars: int, name: str) -> str | None:
    """Trimmed string or None. Over-long text is truncated rather than rejected: a buyer
    pasting a long chat should not get an error for it."""
    if value is None:
        return None
    if not isinstance(value, str):
        raise BadRequest(f'"{name}" must be a string')
    text = value.strip()
    if len(text) > max_chars:
        text = text[:max_chars].rstrip() + "…"
    return text or None


def parse_profile(body: dict) -> Profile:
    vibe = _text(body.get("vibe"), 40, "vibe") or DEFAULT_VIBE
    if vibe not in VIBES:
        vibe = DEFAULT_VIBE
    push = body.get("push", DEFAULT_PUSH)
    if not isinstance(push, (int, float)) or isinstance(push, bool):
        raise BadRequest('"push" must be a number between 0 and 100')
    push = int(min(100, max(0, push)))
    deal_size = body.get("deal_size")
    if deal_size is not None and (not isinstance(deal_size, (int, float)) or isinstance(deal_size, bool)):
        raise BadRequest('"deal_size" must be a number')
    return Profile(
        vibe=vibe,
        push=push,
        marketplace=_text(body.get("marketplace"), 40, "marketplace"),
        deal_size=float(deal_size) if deal_size is not None else None,
        locale=_text(body.get("locale"), 10, "locale") or "en",
    )


def parse_images(raw, *, max_images: int = MAX_IMAGES, already_used: int = 0) -> list[Image]:
    """`[{"mime_type": "image/jpeg", "data": "<base64>"}]` → decoded images, size-checked.
    [already_used] bytes count towards the request-wide total (chat with several turns)."""
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise BadRequest('"images" must be a list')
    if len(raw) > max_images:
        raise BadRequest(f"At most {max_images} images per request")
    images: list[Image] = []
    total = already_used
    for item in raw:
        if not isinstance(item, dict):
            raise BadRequest("Each image must be an object with mime_type and data")
        mime = str(item.get("mime_type", "")).lower()
        if mime not in SUPPORTED_MIME:
            raise BadRequest(f"Unsupported image type {mime!r}; use JPEG, PNG or WebP")
        try:
            data = base64.b64decode(item.get("data", ""), validate=True)
        except (binascii.Error, TypeError, ValueError) as exc:
            raise BadRequest("Image data must be base64") from exc
        if not data:
            raise BadRequest("Image data is empty")
        if len(data) > MAX_IMAGE_BYTES:
            raise BadRequest(f"Each image must be under {MAX_IMAGE_BYTES // 1000} KB; downscale before sending")
        total += len(data)
        if total > MAX_TOTAL_IMAGE_BYTES:
            raise BadRequest(f"Images together must be under {MAX_TOTAL_IMAGE_BYTES // 1_000_000} MB")
        images.append(Image(mime_type=mime, data=data))
    return images


def parse_express_request(body: dict) -> ExpressRequest:
    images = parse_images(body.get("images"))
    text = _text(body.get("text"), MAX_TEXT_CHARS, "text")
    if not images and not text:
        raise BadRequest('Provide "images" (screenshots) or "text" (listing / chat text)')
    return ExpressRequest(
        profile=parse_profile(body),
        images=images,
        text=text,
        keyword=_text(body.get("keyword"), 120, "keyword"),
    )


def parse_pro_request(body: dict) -> ProRequest:
    raw_messages = body.get("messages")
    if not isinstance(raw_messages, list) or not raw_messages:
        raise BadRequest('"messages" must be a non-empty list')
    if len(raw_messages) > MAX_MESSAGES:
        raw_messages = raw_messages[-MAX_MESSAGES:]
    messages: list[ChatMessage] = []
    image_budget = MAX_IMAGES
    image_bytes = 0
    # Newest attachments matter most: walk backwards so the budget favours them.
    for item in reversed(raw_messages):
        if not isinstance(item, dict):
            raise BadRequest("Each message must be an object")
        role = str(item.get("role", "user")).lower()
        if role not in ("user", "wizard"):
            raise BadRequest('Message "role" must be "user" or "wizard"')
        text = _text(item.get("text"), MAX_MESSAGE_CHARS, "messages[].text") or ""
        images = (
            parse_images(item.get("images"), max_images=MAX_IMAGES, already_used=image_bytes)
            if image_budget > 0
            else []
        )
        images = images[:image_budget]
        image_budget -= len(images)
        image_bytes += sum(len(img.data) for img in images)
        if not text and not images:
            continue
        messages.append(ChatMessage(role=role, text=text, images=images))
    messages.reverse()
    if not messages:
        raise BadRequest("Messages have no text or images")
    mode = _text(body.get("mode"), 20, "mode") or "reply"
    if mode not in ("reply", "options"):
        raise BadRequest('"mode" must be "reply" or "options"')
    return ProRequest(
        profile=parse_profile(body),
        messages=messages,
        mode=mode,
        regenerate=bool(body.get("regenerate", False)),
    )


# ── prompting ─────────────────────────────────────────────────────────────────


def push_guidance(push: int) -> str:
    if push <= 20:
        return "Easygoing: a small ask (about 5-10% under asking) and happy to meet halfway."
    if push <= 40:
        return "Gentle: a polite nudge, one counter at most, around 10-15% under asking."
    if push <= 60:
        return "Balanced: a fair anchor around 15-25% under asking, ready to walk away."
    if push <= 80:
        return "Bold: a low anchor around 25-35% under asking, holds firm."
    return "Hard bargainer: the lowest credible price (35%+ under asking) or no deal."


def system_prompt(profile: Profile) -> str:
    marketplace = MARKETPLACES.get(profile.marketplace or "", "")
    lines = [
        "You are Bargain Wiz, a negotiation coach for a BUYER on peer-to-peer marketplaces.",
        f"Write every user-facing text in {profile.language}.",
        (
            "Lines you write are pasted verbatim by the buyer into the chat with the seller: write them "
            "as the buyer speaking to the seller, one message each, one or two sentences, natural and "
            "specific. No emojis unless the seller used them. Never use placeholders like [price]; use "
            "concrete numbers derived from the material. Never invent facts that are not in the material; "
            "if the price is unknown, negotiate on terms (pickup, bundle, condition, shipping) instead."
        ),
        f"Tone: {VIBES.get(profile.vibe, VIBES[DEFAULT_VIBE])}",
        f"Push level: {push_guidance(profile.push)}",
    ]
    if marketplace:
        lines.append(f"Marketplace etiquette: {marketplace}")
    if profile.deal_size:
        lines.append(f"The buyer's typical deal is around ${profile.deal_size:,.0f}; keep numbers proportionate.")
    return "\n".join(lines)


def _image_parts(images: list[Image]) -> list[dict]:
    return [{"type": "image", "mime_type": img.mime_type, "data": img.data} for img in images]


def express_parts(request: ExpressRequest) -> list[dict]:
    parts = _image_parts(request.images)
    instructions = ["Material: screenshots of a marketplace listing and/or the chat with the seller."]
    if request.text:
        instructions.append(f"Text provided by the buyer (listing or chat, possibly OCR):\n{request.text}")
    if request.keyword:
        instructions.append(f"The buyer wants to focus on: {request.keyword}")
    instructions.append(
        "Task: 1) In one short line, state what you see (item, asking price, condition, seller signals). "
        "2) Write exactly three ready-to-paste lines: an opener, a counter for after the seller pushes "
        "back, and a close. For each, explain in one sentence why it works."
    )
    parts.append({"type": "text", "text": "\n\n".join(instructions)})
    return parts


def pro_parts(request: ProRequest) -> list[dict]:
    transcript = []
    images: list[Image] = []
    for message in request.messages:
        speaker = "Wizard" if message.role == "wizard" else "Buyer"
        note = "(screenshot attached)" if message.images else ""
        transcript.append(" ".join(part for part in (f"{speaker}:", message.text, note) if part))
        images.extend(message.images)
    parts = _image_parts(images)
    text = ["Conversation so far between the buyer (the person you coach) and you, the Wizard:", "\n".join(transcript)]
    if request.mode == "options":
        text.append(
            "Task: write exactly three ready-to-paste lines the buyer can send the seller right now: "
            "an opener, a counter, and a close, each with a one-sentence why."
        )
    else:
        text.append(
            "Task: reply to the buyer's latest message as their coach in two to four sentences: concrete, "
            "specific to this deal, in your tone. If the buyer needs a message for the seller, include it "
            "in quotation marks."
        )
        if request.regenerate:
            text.append("The buyer asked for a redo: take a different angle than a typical answer would.")
    parts.append({"type": "text", "text": "\n\n".join(text)})
    return parts


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
    """Keep up to MAX_LINES non-empty lines; fix missing/unknown intents by position
    (opener, counter, close)."""
    out: list[dict] = []
    for item in raw if isinstance(raw, list) else []:
        if len(out) >= MAX_LINES:
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
        raise ValueError("model returned no lines")
    return {"seeing": str(raw.get("seeing") or "").strip(), "lines": lines}


def reply_result(raw: dict) -> dict:
    reply = str(raw.get("reply") or "").strip()
    if not reply:
        raise ValueError("model returned an empty reply")
    return {"reply": reply}


def options_result(raw: dict) -> dict:
    lines = normalize_lines(raw.get("lines"))
    if not lines:
        raise ValueError("model returned no lines")
    return {"lines": lines}
