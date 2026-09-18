"""Request parsing, prompting and result shaping for the AI negotiation functions.

Pure Python (no SDK imports) so the behaviour is unit-testable; `main.py` wires it to a
`JsonGenerator`. Shared by `express_dealmaker` (screenshots → lines) and
`pro_deal_closer` (chat coaching → reply / lines).
"""
import base64
import binascii
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

import config
from errors import BadRequest, UpstreamError
from validation import clip_text, number_or_none, validate_model

SUPPORTED_MIME = {"image/jpeg", "image/png", "image/webp"}
INTENTS = ("opener", "counter", "close")

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


def default_vibe() -> str:
    """Configured default tone, or the first known one when the configured id is unknown."""
    value = config.DEFAULT_VIBE.value.strip().lower()
    return value if value in VIBES else next(iter(VIBES))

# Onboarding "main_hurdle" ids → what the coach should compensate for.
HURDLES = {
    "starting": "hesitates to open a negotiation: make the opener easy and confident to send.",
    "counter_offers": "gets ignored after offering: make messages concrete and hard to ignore "
    "(a number, a time, a next step).",
    "being_rude": "fears sounding rude: keep every line warm and polite while still firm on price.",
    "holding_ground": "tends to accept the first counter: include a line that holds the position.",
    "fair_price": "is unsure what a fair price is: anchor with concrete comparables or condition.",
}

DEALS_PER_MONTH = {
    "0_2": "an occasional buyer (a couple of deals a month): explain briefly why a line works.",
    "3_5": "a regular buyer (several deals a month).",
    "6_plus": "a frequent buyer (many deals a month): be efficient, skip basics.",
}

MARKETPLACES = {
    "ebay": "eBay: written offers/messages, buyer protection, shipping cost is a lever.",
    "amazon": "Amazon third-party seller: formal messages, little price room; focus on "
    "bundles, shipping, condition or partial refunds.",
    "facebook": "Facebook Marketplace: casual chat, local pickup, cash; speed and certainty win.",
    "olx": "OLX: local classifieds chat, pickup, haggling is expected.",
    "craigslist": "Craigslist: email/text, cash on pickup, safety first, haggling is expected.",
}


# ── models ────────────────────────────────────────────────────────────────────


class Image(BaseModel):
    """`{"mime_type": "image/jpeg", "data": "<base64>"}` → decoded, size-checked bytes."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    mime_type: str
    data: bytes

    @field_validator("mime_type", mode="before")
    @classmethod
    def _mime(cls, value: object) -> str:
        mime = str(value or "").lower()
        if mime not in SUPPORTED_MIME:
            raise ValueError(f"unsupported image type {mime!r}; use JPEG, PNG or WebP")
        return mime

    @field_validator("data", mode="before")
    @classmethod
    def _decode(cls, value: object) -> bytes:
        if isinstance(value, bytes):
            data = value
        elif isinstance(value, str):
            try:
                data = base64.b64decode(value, validate=True)
            except (binascii.Error, ValueError) as exc:
                raise ValueError("image data must be base64") from exc
        else:
            raise ValueError("image data must be base64")
        if not data:
            raise ValueError("image data is empty")
        if len(data) > config.MAX_IMAGE_BYTES.value:
            raise ValueError(f"each image must be under {config.MAX_IMAGE_BYTES.value // 1000} KB; downscale before sending")
        return data


class Profile(BaseModel):
    """Buyer profile from onboarding, sent with every AI request (see PROFILE_SYNC.md).
    Unknown values fall back to defaults; only wrong types are rejected."""

    model_config = ConfigDict(extra="ignore")

    vibe: str = Field(default_factory=lambda: default_vibe())
    push: int = Field(default_factory=lambda: config.DEFAULT_PUSH.value)
    marketplace: str | None = None
    deal_size: float | None = None
    locale: str = "en"
    hurdles: tuple[str, ...] = ()
    deals_per_month: str | None = None

    @field_validator("vibe", mode="before")
    @classmethod
    def _vibe(cls, value: object) -> str:
        text = (clip_text(value, 40) or default_vibe()).lower()
        return text if text in VIBES else default_vibe()

    @field_validator("push", mode="before")
    @classmethod
    def _push(cls, value: object) -> int:
        number = number_or_none(value)
        return config.DEFAULT_PUSH.value if number is None else int(min(100, max(0, number)))

    @field_validator("deal_size", mode="before")
    @classmethod
    def _deal_size(cls, value: object) -> float | None:
        return number_or_none(value)

    @field_validator("marketplace", "deals_per_month", mode="before")
    @classmethod
    def _short_text(cls, value: object) -> str | None:
        return clip_text(value, 40)

    @field_validator("locale", mode="before")
    @classmethod
    def _locale(cls, value: object) -> str:
        return clip_text(value, 10) or "en"

    @field_validator("hurdles", mode="before")
    @classmethod
    def _hurdles(cls, value: object) -> tuple[str, ...]:
        if value is None:
            return ()
        if not isinstance(value, list | tuple):
            raise ValueError("must be a list of ids")
        return tuple(h.strip().lower() for h in value if isinstance(h, str) and h.strip())[:8]

    @property
    def language(self) -> str:
        return LANGUAGES.get(self.locale.split("-")[0].lower(), "English")


def _profile_of(model: Profile) -> Profile:
    return Profile(**{name: getattr(model, name) for name in Profile.model_fields})


class ExpressRequest(Profile):
    """`express_dealmaker` body: screenshots and/or text plus the buyer profile."""

    images: list[Image] = []
    text: str | None = None
    keyword: str | None = None

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list")
        if len(value) > config.MAX_IMAGES.value:
            raise ValueError(f"at most {config.MAX_IMAGES.value} images per request")
        return value

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str | None:
        return clip_text(value, config.MAX_TEXT_CHARS.value)

    @field_validator("keyword", mode="before")
    @classmethod
    def _keyword(cls, value: object) -> str | None:
        return clip_text(value, 120)

    @model_validator(mode="after")
    def _has_material(self) -> "ExpressRequest":
        if sum(len(image.data) for image in self.images) > config.MAX_TOTAL_IMAGE_BYTES.value:
            raise ValueError(f"images together must be under {config.MAX_TOTAL_IMAGE_BYTES.value // 1_000_000} MB")
        if not self.images and not self.text:
            raise ValueError('provide "images" (screenshots) or "text" (listing / chat text)')
        return self

    @property
    def profile(self) -> Profile:
        return _profile_of(self)


class ChatMessage(BaseModel):
    model_config = ConfigDict(extra="ignore")

    role: Literal["user", "wizard"] = "user"
    text: str = ""
    images: list[Image] = []

    @field_validator("role", mode="before")
    @classmethod
    def _role(cls, value: object) -> object:
        return "user" if value is None else str(value).lower()

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str:
        return clip_text(value, config.MAX_MESSAGE_CHARS.value) or ""

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list")
        if len(value) > config.MAX_IMAGES.value:
            raise ValueError(f"at most {config.MAX_IMAGES.value} images per message")
        return value


class ProRequest(Profile):
    """`pro_deal_closer` body: the chat so far plus the buyer profile."""

    messages: list[ChatMessage]
    mode: Literal["reply", "options"] = "reply"
    regenerate: bool = False

    @field_validator("messages", mode="before")
    @classmethod
    def _messages(cls, value: object) -> list:
        if not isinstance(value, list) or not value:
            raise ValueError("must be a non-empty list")
        return value[-config.MAX_MESSAGES.value:]

    @field_validator("mode", mode="before")
    @classmethod
    def _mode(cls, value: object) -> object:
        return "reply" if value is None else str(value).lower()

    @model_validator(mode="after")
    def _apply_image_budget(self) -> "ProRequest":
        """Newest attachments matter most: walk backwards so the budget favours them, and
        drop turns that end up with neither text nor images."""
        budget, total = config.MAX_IMAGES.value, 0
        kept: list[ChatMessage] = []
        for message in reversed(self.messages):
            images = message.images[:budget]
            budget -= len(images)
            total += sum(len(image.data) for image in images)
            if total > config.MAX_TOTAL_IMAGE_BYTES.value:
                raise ValueError(f"images together must be under {config.MAX_TOTAL_IMAGE_BYTES.value // 1_000_000} MB")
            if not message.text and not images:
                continue
            kept.append(message.model_copy(update={"images": images}))
        if not kept:
            raise ValueError("messages have no text or images")
        kept.reverse()
        self.messages = kept
        return self

    @property
    def profile(self) -> Profile:
        return _profile_of(self)


# ── parsing (body dict → model; pydantic errors → BadRequest) ──────────────────


def parse_profile(body: dict) -> Profile:
    return validate_model(Profile, body, BadRequest)


def parse_images(raw, *, max_images: int = config.MAX_IMAGES.value) -> list[Image]:
    """`[{"mime_type": …, "data": …}]` → decoded images, size-checked as a set."""
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise BadRequest('"images" must be a list')
    if len(raw) > max_images:
        raise BadRequest(f"At most {max_images} images per request")
    images = [validate_model(Image, item, BadRequest) for item in raw]
    if sum(len(image.data) for image in images) > config.MAX_TOTAL_IMAGE_BYTES.value:
        raise BadRequest(f"Images together must be under {config.MAX_TOTAL_IMAGE_BYTES.value // 1_000_000} MB")
    return images


def parse_express_request(body: dict) -> ExpressRequest:
    return validate_model(ExpressRequest, body, BadRequest)


def parse_pro_request(body: dict) -> ProRequest:
    return validate_model(ProRequest, body, BadRequest)


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
        f"Tone: {VIBES.get(profile.vibe, VIBES[default_vibe()])}",
        f"Push level: {push_guidance(profile.push)}",
    ]
    if marketplace:
        lines.append(f"Marketplace etiquette: {marketplace}")
    if profile.deal_size:
        lines.append(f"The buyer's typical deal is around ${profile.deal_size:,.0f}; keep numbers proportionate.")
    frequency = DEALS_PER_MONTH.get(profile.deals_per_month or "")
    if frequency:
        lines.append(f"The buyer is {frequency}")
    known = [HURDLES[h] for h in profile.hurdles if h in HURDLES]
    if known:
        lines.append("Known weak spots of this buyer, compensate for them: " + " ".join(known))
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
