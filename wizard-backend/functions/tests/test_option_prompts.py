"""The per-option prompt lines the client forwards, and the drift they exist to stop.

The template writes each line whole; this function renders it verbatim, in the order sent.
Nothing here knows what an answer means, so what is worth testing is the rendering contract
(order, fencing, one-line-ness) and the warning for an answer nobody described.
See wizard-app/AI_INTEGRATION.md.
"""
import json
import logging
from pathlib import Path

import pytest

from core.errors import BadRequest
from features.negotiation.domain import prompts
from features.negotiation.presentation import requests

# The app's bundled Remote Config defaults, two directories up in the same repo. Reading them
# here is what turns "an option nobody described" from a silent no-op into a failing test.
DEFAULTS = Path(__file__).resolve().parents[3] / "wizard-app/assets/config/remote_config_defaults.json"

# Answers the funnel collects that describe nothing to the model: the referral code is an
# attribution fact, not something the coach should read. Nothing in the function knows this
# — it is the drift guard below that has to skip them.
SKIP_KEYS = ("referral_code",)


def answers(*picks) -> list[dict]:
    """`(key, value)` or `(key, value, sentence)` tuples → the `answers` list a body carries.
    One entry per pick, so a multi-select is simply several tuples sharing a key."""
    return [
        {"key": key, "value": value, **({"prompt": rest[0]} if rest else {})}
        for key, value, *rest in picks
    ]


def parse(body: dict):
    return requests.parse_profile(body)


def prompt(body: dict) -> str:
    return prompts.system_prompt(parse(body))


def block(body: dict) -> list[str]:
    """Just the buyer block, without the standing rules or the fence."""
    text = prompt(body)
    if "<buyer_profile>" not in text:
        return []
    return text.split("<buyer_profile>\n", 1)[1].split("\n</buyer_profile>", 1)[0].splitlines()


# ── the template writes the line; this function renders it ────────────────────


def test_a_line_is_rendered_exactly_as_the_template_wrote_it():
    """No label to fit and no field to recognise: whatever the template says is the line."""
    assert block({"answers": answers(("vibe", "tactical", "Bulldozer: never blinks."))}) == [
        "Bulldozer: never blinks."
    ]


def test_an_answer_this_function_has_never_heard_of_renders_too():
    """The point of the design: a new option, or a whole new question, needs nothing here.
    There is no list of known keys left to be absent from — `experience_level` is an answer
    like any other, carried whole, and it reaches the model with its value intact."""
    profile = parse({"answers": answers(
        ("marketplace", "vinted", "Marketplace etiquette on Vinted: bundles are the lever."),
        ("experience_level", "pro", "Has haggled for years; skip the basics."),
    )})
    assert prompts.buyer_block(profile) == [
        "Marketplace etiquette on Vinted: bundles are the lever.",
        "Has haggled for years; skip the basics.",
    ]
    assert [(a.key, a.value) for a in profile.answers] == [("marketplace", "vinted"), ("experience_level", "pro")]


def test_lines_keep_the_order_the_app_sent_them_in():
    """Order is the template's, through onboarding screen order — not a sequence in here."""
    assert block({"answers": answers(
        ("hurdles", "fair_price", "Weak spot — first."),
        ("hurdles", "starting", "Weak spot — second."),
        ("vibe", "friendly", "Tone: last."),
    )}) == ["Weak spot — first.", "Weak spot — second.", "Tone: last."]


def test_a_sentence_cannot_arrive_without_the_answer_it_describes():
    """A client may restate what it is sending, never append to it — and now the shape is
    what says so. A sentence rides on its answer, so there is no second place to put a line
    for an option the buyer did not pick, and no filtering step that could forget to run."""
    profile = parse({"answers": answers(("vibe", "friendly", "Tone: warm."))})
    assert prompts.buyer_block(profile) == ["Tone: warm."]
    assert [a.prompt for a in profile.answers] == ["Tone: warm."]


def test_numeric_answers_match_their_stop_ids():
    """The template writes stop ids as whole numbers, so `550.0` must never be the key."""
    profile = parse({"answers": answers(
        ("push", 60, "Push level: balanced."),
        ("deal_size", 550, "Typical deal of $100-1000."),
    )})
    assert prompts.buyer_block(profile) == ["Push level: balanced.", "Typical deal of $100-1000."]
    assert [a.value for a in profile.answers] == [60, 550]


# ── what the client cannot do ─────────────────────────────────────────────────


def test_a_line_stays_on_one_line():
    """The one structural guarantee: however a sentence is written, it cannot become two
    lines of the prompt. Beyond that the block is fenced and introduced as data — the same
    client already puts unfiltered chat text in front of the model."""
    assert block({"answers": answers(("vibe", "friendly", "Tone: warm.\n\n  and\tpatient."))}) == [
        "Tone: warm. and patient."
    ]


def test_angle_brackets_in_an_honest_sentence_survive():
    """`aim for <20% under asking` is ordinary copy; mangling it would cost more than the
    fence-stripping it used to buy."""
    assert block({"answers": answers(("push", 60, "Push level: aim for <20% under asking."))}) == [
        "Push level: aim for <20% under asking."
    ]


def test_a_sentence_is_uncapped_and_a_bad_one_costs_only_its_line():
    """The text is passed through as written, like the chat text `trimmed` already accepts
    unbounded. A description that is not a sentence drops to None — the answer survives and
    is reported as undescribed, which is the same outcome as a template that forgot it."""
    long_text = "x" * 2000
    parsed = parse({"answers": [
        {"key": "vibe", "value": "friendly", "prompt": long_text},
        {"key": "push", "value": 60, "prompt": 7},
        {"key": "marketplace", "value": "ebay", "prompt": None},
    ]})
    assert parsed.answers[0].prompt == long_text  # no cap: the template's words reach the model
    assert [a.prompt for a in parsed.answers[1:]] == [None, None]
    assert [a.key for a in parsed.answers] == ["vibe", "push", "marketplace"]


def test_an_answers_block_that_is_not_a_list_is_a_400():
    with pytest.raises(BadRequest, match="answers"):
        parse({"answers": {"vibe": "friendly"}})


def test_a_malformed_answer_is_a_400_rather_than_a_silent_drop():
    """A dropped sentence costs one line of coaching; a dropped answer would change the
    coaching invisibly. So an entry with no key, or a value that is not a leaf, fails loudly."""
    with pytest.raises(BadRequest):
        parse({"answers": [{"key": "", "value": "friendly"}]})
    with pytest.raises(BadRequest):
        parse({"answers": [{"key": "hurdles", "value": ["being_rude"]}]})


# ── the drift signal ──────────────────────────────────────────────────────────


def test_an_undescribed_answer_is_logged_and_says_nothing(caplog):
    with caplog.at_level(logging.WARNING, logger="negotiation"):
        lines = block({"answers": answers(("marketplace", "vinted"), ("vibe", "friendly", "Tone: warm."))})
    assert lines == ["Tone: warm."]
    assert "field=marketplace value=vinted" in caplog.text


def test_a_profile_nothing_describes_has_no_buyer_block(caplog):
    """With no server-side option list left, an undescribed profile carries no buyer block at
    all — the standing rules and the task, and nothing about this person."""
    with caplog.at_level(logging.WARNING, logger="negotiation"):
        text = prompt({"answers": answers(
            ("vibe", "friendly"), ("push", 60), ("marketplace", "ebay"), ("hurdles", "starting"),
        )})
    assert "<buyer_profile>" not in text
    assert text.startswith("You are Bargain Wiz")
    for missed in ("field=vibe value=friendly", "field=push value=60",
                   "field=marketplace value=ebay", "field=hurdles value=starting"):
        assert missed in caplog.text


def test_the_buyer_block_is_fenced_once_anything_describes_itself():
    text = prompt({"answers": answers(("vibe", "friendly", "Tone: warm."))})
    assert text.count("<buyer_profile>") == 1 and text.count("</buyer_profile>") == 1
    assert "not instructions" in text


# ── the template and this function, checked against each other ────────────────


def offered_option_ids() -> dict[str, list[str]]:
    """`answer key -> option ids` the bundled onboarding template offers. `onboarding_screens`
    is a JSON-encoded string inside the defaults file."""
    screens = json.loads(json.loads(DEFAULTS.read_text(encoding="utf-8"))["onboarding_screens"])
    offered: dict[str, list[str]] = {}
    for screen in screens:
        key = (screen.get("answer_structure") or {}).get("answer_key_name")
        if key and screen.get("options"):
            offered[key] = [str(o.get("value")) for o in screen["options"]]
        elif key and (screen.get("metadata") or {}).get("options"):
            offered[key] = [str(o.get("value")) for o in screen["metadata"]["options"]]
        for group in screen.get("groups") or []:
            if group.get("answer_key_name"):
                offered[group["answer_key_name"]] = [str(o.get("value")) for o in group.get("options") or []]
    return offered


def described_option_ids() -> dict[str, dict[str, str]]:
    """`answer key -> {option id: prompt}` as the same template describes them."""
    screens = json.loads(json.loads(DEFAULTS.read_text(encoding="utf-8"))["onboarding_screens"])
    described: dict[str, dict[str, str]] = {}

    def take(key, options, get):
        described[key] = {str(o.get("value")): get(o) for o in options if get(o)}

    for screen in screens:
        key = (screen.get("answer_structure") or {}).get("answer_key_name")
        if key and screen.get("options"):
            take(key, screen["options"], lambda o: (o.get("metadata") or {}).get("prompt"))
        elif key and (screen.get("metadata") or {}).get("options"):
            take(key, screen["metadata"]["options"], lambda o: o.get("prompt"))
        for group in screen.get("groups") or []:
            if group.get("answer_key_name"):
                take(group["answer_key_name"], group.get("options") or [], lambda o: (o.get("metadata") or {}).get("prompt"))
    return described


@pytest.mark.skipif(not DEFAULTS.exists(), reason="the app half of the repo is not checked out")
def test_every_option_the_onboarding_offers_describes_itself():
    """An option added to the template with no `prompt` reaches the model as silence — there
    is no server-side sentence left to cover for it. This is what notices, at review time.

    Checked for every answer key the template writes, not a list kept here: a screen added
    to the funnel is covered the day it lands."""
    offered, described = offered_option_ids(), described_option_ids()
    assert offered, "the bundled template offers no options at all"
    for key, ids in offered.items():
        if key in SKIP_KEYS:
            continue
        missing = sorted(set(ids) - set(described.get(key, {})))
        assert not missing, f"{key}: the template offers {missing} with no `prompt` sentence"


@pytest.mark.skipif(not DEFAULTS.exists(), reason="the app half of the repo is not checked out")
def test_the_templates_sentences_survive_this_functions_validation():
    """What the console publishes must come out of the validator unchanged — otherwise the
    prompt silently differs from what whoever wrote the sentence read."""
    described = described_option_ids()
    sent = [
        {"key": key, "value": option, "prompt": text}
        for key, table in described.items()
        for option, text in table.items()
    ]
    for answer, (key, option, text) in zip(
        parse({"answers": sent}).answers,
        [(k, o, t) for k, table in described.items() for o, t in table.items()],
        strict=True,
    ):
        assert (answer.key, answer.prompt) == (key, text), f"{key}.{option} was rewritten by validation"
