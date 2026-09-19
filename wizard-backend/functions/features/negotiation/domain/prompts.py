"""The system prompt and the user parts sent to Gemini, built from the buyer profile.

The tables below are the coaching knowledge: each onboarding answer the app collects maps to
one sentence the model reads. An id we do not know contributes nothing rather than failing.
"""
from .models import ExpressRequest, Image, Profile, ProRequest

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
        (
            f"Write every user-facing text — the lines the buyer pastes included — in the "
            f"language of the BCP-47 locale tag {profile.locale}."
        ),
        (
            "Lines you write are pasted verbatim by the buyer into the chat with the seller: write them "
            "as the buyer speaking to the seller, one message each, one or two sentences, natural and "
            "specific. No emojis unless the seller used them. Never use placeholders like [price]; use "
            "concrete numbers derived from the material. Never invent facts that are not in the material; "
            "if the price is unknown, negotiate on terms (pickup, bundle, condition, shipping) instead."
        ),
        f"Tone: {VIBES.get(profile.vibe) or next(iter(VIBES.values()))}",
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
