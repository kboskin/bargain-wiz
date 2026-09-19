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

PROFILE = {"vibe": "friendly", "push": 60}

# The app's bundled Remote Config defaults, two directories up in the same repo. Reading them
# here is what turns "an option nobody described" from a silent no-op into a failing test.
DEFAULTS = Path(__file__).resolve().parents[3] / "wizard-app/assets/config/remote_config_defaults.json"


def parse(body: dict):
    return requests.parse_profile({**PROFILE, **body})


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
    assert block({"vibe": "tactical", "prompt": {"vibe": {"tactical": "Bulldozer: never blinks."}}}) == [
        "Bulldozer: never blinks."
    ]


def test_an_answer_this_function_has_never_heard_of_renders_too():
    """The point of the design: a new option, or a whole new question, needs nothing here.
    `experience_level` is not a Profile field at all — `extra="ignore"` drops the answer, but
    its line is not keyed by a field this function knows, so it still reaches the model."""
    lines = block({
        "marketplace": "vinted",
        "experience_level": "pro",
        "prompt": {
            "marketplace": {"vinted": "Marketplace etiquette on Vinted: bundles are the lever."},
            "experience_level": {"pro": "Has haggled for years; skip the basics."},
        },
    })
    assert "Marketplace etiquette on Vinted: bundles are the lever." in lines
    assert "Has haggled for years; skip the basics." in lines


def test_lines_keep_the_order_the_app_sent_them_in():
    """Order is the template's, through onboarding screen order — not a sequence in here."""
    assert block({
        "vibe": "friendly",
        "hurdles": ["fair_price", "starting"],
        "prompt": {
            "hurdles": {"fair_price": "Weak spot — first.", "starting": "Weak spot — second."},
            "vibe": {"friendly": "Tone: last."},
        },
    }) == ["Weak spot — first.", "Weak spot — second.", "Tone: last."]


def test_a_line_only_counts_for_the_answer_actually_sent():
    """A client may restate what it is sending, not append to it."""
    lines = block({"vibe": "friendly", "prompt": {"vibe": {"friendly": "Tone: warm."}}})
    assert lines == ["Tone: warm."]
    # A line for an option the buyer did not pick is dropped by the app, and would be
    # rendered here — so the guard that matters is the app's; what this pins is that the
    # sentence rendered is the one keyed by the id sent.
    assert "Tone: warm." in prompt({"vibe": "friendly", "prompt": {"vibe": {"friendly": "Tone: warm."}}})


def test_numeric_answers_match_their_stop_ids():
    """The template writes stop ids as whole numbers, so `550.0` must never be the key."""
    lines = block({
        "push": 60, "deal_size": 550,
        "prompt": {"push": {"60": "Push level: balanced."}, "deal_size": {"550": "Typical deal of $100-1000."}},
    })
    assert lines == ["Push level: balanced.", "Typical deal of $100-1000."]


# ── what the client cannot do ─────────────────────────────────────────────────


def test_a_line_stays_on_one_line():
    """The one structural guarantee: however a sentence is written, it cannot become two
    lines of the prompt. Beyond that the block is fenced and introduced as data — the same
    client already puts unfiltered chat text in front of the model."""
    assert block({"prompt": {"vibe": {"friendly": "Tone: warm.\n\n  and\tpatient."}}}) == [
        "Tone: warm. and patient."
    ]


def test_angle_brackets_in_an_honest_sentence_survive():
    """`aim for <20% under asking` is ordinary copy; mangling it would cost more than the
    fence-stripping it used to buy."""
    assert block({"prompt": {"push": {"60": "Push level: aim for <20% under asking."}}}) == [
        "Push level: aim for <20% under asking."
    ]


def test_rubbish_is_dropped_rather_than_rejected():
    """One malformed entry costs that line and nothing else; the text itself is passed
    through as written, like the chat text `trimmed` already accepts unbounded."""
    long_text = "x" * 2000
    parsed = parse({"prompt": {"vibe": {"friendly": long_text, "tactical": 7, "quiet_closer": None}, "hurdles": "nope"}})
    assert parsed.prompt["vibe"]["friendly"] == long_text  # no cap: the template's words reach the model
    assert set(parsed.prompt["vibe"]) == {"friendly"}
    assert "hurdles" not in parsed.prompt


def test_a_prompt_block_that_is_not_a_map_is_a_400():
    with pytest.raises(BadRequest, match="prompt"):
        parse({"prompt": ["starting"]})


# ── the drift signal ──────────────────────────────────────────────────────────


def test_an_undescribed_answer_is_logged_and_says_nothing(caplog):
    with caplog.at_level(logging.WARNING, logger="negotiation"):
        lines = block({"marketplace": "vinted", "prompt": {"vibe": {"friendly": "Tone: warm."}}})
    assert lines == ["Tone: warm."]
    assert "field=marketplace value=vinted" in caplog.text


def test_a_profile_nothing_describes_has_no_buyer_block(caplog):
    """With no server-side option list left, an undescribed profile carries no buyer block at
    all — the standing rules and the task, and nothing about this person."""
    with caplog.at_level(logging.WARNING, logger="negotiation"):
        text = prompt({"vibe": "friendly", "push": 60, "marketplace": "ebay", "hurdles": ["starting"]})
    assert "<buyer_profile>" not in text
    assert text.startswith("You are Bargain Wiz")
    for missed in ("field=vibe value=friendly", "field=push value=60",
                   "field=marketplace value=ebay", "field=hurdles value=starting"):
        assert missed in caplog.text


def test_the_buyer_block_is_fenced_once_anything_describes_itself():
    text = prompt({"prompt": {"vibe": {"friendly": "Tone: warm."}}})
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
        if key in prompts.SKIP_KEYS:
            continue
        missing = sorted(set(ids) - set(described.get(key, {})))
        assert not missing, f"{key}: the template offers {missing} with no `prompt` sentence"


@pytest.mark.skipif(not DEFAULTS.exists(), reason="the app half of the repo is not checked out")
def test_the_templates_sentences_survive_this_functions_validation():
    """What the console publishes must come out of the validator unchanged — otherwise the
    prompt silently differs from what whoever wrote the sentence read."""
    described = described_option_ids()
    parsed = parse({"prompt": described}).prompt
    for key, table in described.items():
        for option, text in table.items():
            assert parsed[key][option] == text, f"{key}.{option} was rewritten by validation"
