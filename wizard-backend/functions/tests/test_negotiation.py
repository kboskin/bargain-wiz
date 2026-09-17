"""Unit tests for request parsing, prompting and result shaping."""
import base64

import pytest

import negotiation as n

PNG = base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"0" * 100).decode()


def test_parse_profile_defaults_and_clamping():
    p = n.parse_profile({})
    assert (p.vibe, p.push, p.marketplace, p.deal_size, p.locale) == ("friendly", 60, None, None, "en")
    p = n.parse_profile({"vibe": "tactical", "push": 250, "marketplace": "facebook", "deal_size": 550, "locale": "es"})
    assert p.vibe == "tactical" and p.push == 100 and p.deal_size == 550.0 and p.language == "Spanish"
    assert n.parse_profile({"vibe": "unknown"}).vibe == "friendly"
    with pytest.raises(n.BadRequest):
        n.parse_profile({"push": "high"})


def test_parse_images_validates_type_encoding_and_size():
    imgs = n.parse_images([{"mime_type": "image/png", "data": PNG}])
    assert imgs[0].mime_type == "image/png" and imgs[0].data.startswith(b"\x89PNG")
    with pytest.raises(n.BadRequest):
        n.parse_images([{"mime_type": "image/gif", "data": PNG}])
    with pytest.raises(n.BadRequest):
        n.parse_images([{"mime_type": "image/png", "data": "not base64!!"}])
    with pytest.raises(n.BadRequest):
        n.parse_images([{"mime_type": "image/png", "data": PNG}] * (n.MAX_IMAGES + 1))
    big = base64.b64encode(b"0" * (n.MAX_IMAGE_BYTES + 1)).decode()
    with pytest.raises(n.BadRequest):
        n.parse_images([{"mime_type": "image/jpeg", "data": big}])


def test_express_request_needs_images_or_text():
    with pytest.raises(n.BadRequest):
        n.parse_express_request({})
    req = n.parse_express_request({"text": "IKEA Kallax $180", "keyword": " pickup "})
    assert req.images == [] and req.text == "IKEA Kallax $180" and req.keyword == "pickup"


def test_express_parts_put_images_first_and_mention_keyword():
    req = n.parse_express_request({"images": [{"mime_type": "image/png", "data": PNG}], "keyword": "scuff"})
    parts = n.express_parts(req)
    assert parts[0]["type"] == "image" and parts[-1]["type"] == "text"
    assert "scuff" in parts[-1]["text"] and "exactly three" in parts[-1]["text"]


def test_system_prompt_reflects_profile():
    prompt = n.system_prompt(n.Profile(vibe="no_nonsense", push=90, marketplace="ebay", deal_size=550, locale="es"))
    assert "Spanish" in prompt and "No-Nonsense" in prompt and "Hard bargainer" in prompt
    assert "eBay" in prompt and "$550" in prompt


def test_pro_request_keeps_newest_images_within_budget_and_orders_messages():
    img = {"mime_type": "image/png", "data": PNG}
    body = {
        "messages": [
            {"role": "user", "text": "Kallax $180", "images": [img] * 4},
            {"role": "wizard", "text": "Open at $140."},
            {"role": "user", "text": "They said $170", "images": [img] * 4},
        ],
        "mode": "options",
    }
    req = n.parse_pro_request(body)
    assert [m.role for m in req.messages] == ["user", "wizard", "user"]
    assert len(req.messages[2].images) == 4  # newest message keeps all its images
    assert len(req.messages[0].images) == n.MAX_IMAGES - 4  # oldest gets what is left
    parts = n.pro_parts(req)
    assert sum(1 for p in parts if p["type"] == "image") == n.MAX_IMAGES
    assert "Buyer: Kallax $180 (screenshot attached)" in parts[-1]["text"]
    assert "three ready-to-paste lines" in parts[-1]["text"]


def test_pro_request_validation():
    with pytest.raises(n.BadRequest):
        n.parse_pro_request({"messages": []})
    with pytest.raises(n.BadRequest):
        n.parse_pro_request({"messages": [{"role": "seller", "text": "x"}]})
    with pytest.raises(n.BadRequest):
        n.parse_pro_request({"messages": [{"role": "user", "text": "x"}], "mode": "essay"})
    req = n.parse_pro_request({"messages": [{"role": "user", "text": "x"}], "regenerate": True})
    assert req.mode == "reply" and req.regenerate
    assert "different angle" in n.pro_parts(req)[-1]["text"]


def test_normalize_lines_fixes_intents_and_drops_empties():
    lines = n.normalize_lines([{"text": "Hi"}, {"intent": "weird", "text": "Counter", "why": " because "}, {"text": ""}, "junk"])
    assert lines == [
        {"intent": "opener", "text": "Hi", "why": None},
        {"intent": "counter", "text": "Counter", "why": "because"},
    ]
    with pytest.raises(ValueError):
        n.express_result({"seeing": "x", "lines": []})
    assert n.reply_result({"reply": " Go lower. "}) == {"reply": "Go lower."}
    with pytest.raises(ValueError):
        n.reply_result({"reply": ""})


def test_long_free_text_is_truncated_not_rejected():
    req = n.parse_express_request({"text": "x" * (n.MAX_TEXT_CHARS + 500)})
    assert req.text is not None and len(req.text) == n.MAX_TEXT_CHARS + 1 and req.text.endswith("…")
    pro = n.parse_pro_request({"messages": [{"role": "user", "text": "y" * (n.MAX_MESSAGE_CHARS + 5)}]})
    assert len(pro.messages[0].text) == n.MAX_MESSAGE_CHARS + 1
    assert n.parse_profile({"locale": "es-419-something-long"}).locale.startswith("es-419")


def test_chat_images_share_one_byte_budget():
    big = base64.b64encode(b"0" * (n.MAX_TOTAL_IMAGE_BYTES // 2 + 1)).decode()
    # Two 3 MB+ images in different turns exceed the request-wide 6 MB budget.
    body = {"messages": [{"role": "user", "text": "a", "images": [{"mime_type": "image/jpeg", "data": big}]},
                         {"role": "user", "text": "b", "images": [{"mime_type": "image/jpeg", "data": big}]}]}
    with pytest.raises(n.BadRequest):
        n.parse_pro_request(body)


def test_transcript_line_for_image_only_turn_has_no_double_space():
    req = n.parse_pro_request({"messages": [{"role": "user", "text": "", "images": [{"mime_type": "image/png", "data": PNG}]}]})
    assert "Buyer: (screenshot attached)" in n.pro_parts(req)[-1]["text"]


def test_normalize_lines_caps_at_three():
    lines = n.normalize_lines([{"text": f"line {i}"} for i in range(6)])
    assert [line["intent"] for line in lines] == ["opener", "counter", "close"]
    assert len(lines) == n.MAX_LINES
