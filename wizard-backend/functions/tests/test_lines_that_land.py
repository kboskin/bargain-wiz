"""Tests for the Lines tab: generation, storage and the endpoint that serves them."""
import json
from datetime import UTC, datetime

import pytest
from flask import Flask, request
from pydantic import ValidationError

import main
from core import config
from core.errors import UpstreamError
from features.lines_that_land.data import store as lines_store
from features.lines_that_land.domain import content as lines_content
from features.lines_that_land.domain import generation

CATS_JSON = [
    {
        "id": "opening",
        "name": {"en": "Opening lines", "es": "Frases de apertura"},
        "tips": [
            {"en": "Any flex on price?", "es": "¿Hay margen en el precio?"},
            {"en": "What's the best you can do?", "es": "¿Cuál es lo mejor que puedes hacer?"},
        ],
    }
]
CATS = [lines_content.Category.model_validate(category) for category in CATS_JSON]
NOW = datetime(2026, 9, 18, 10, tzinfo=UTC)


# ── the content model (what the model may answer, and what we store) ──────────


def test_texts_are_trimmed():
    category = lines_content.Category.model_validate(
        {"id": "opening", "name": {"en": "  Opening lines ", "es": "Frases de apertura\n"}, "tips": CATS_JSON[0]["tips"]}
    )
    assert category.name == {"en": "Opening lines", "es": "Frases de apertura"}


@pytest.mark.parametrize(
    "unusable",
    [
        {"id": "opening", "name": {"en": " ", "es": " "}, "tips": CATS_JSON[0]["tips"]},  # no text at all
        {"id": "opening", "name": "Opening lines", "tips": CATS_JSON[0]["tips"]},  # not a language map
        {"id": "opening", "name": CATS_JSON[0]["name"], "tips": []},  # no lines
    ],
)
def test_incomplete_categories_are_rejected(unusable):
    with pytest.raises(ValidationError):
        lines_content.Category.model_validate(unusable)


def test_content_in_fewer_languages_than_configured_still_reads():
    """Which languages a generation must write is enforced by the schema, not by this model:
    the bundled lines and documents written under an older `LINES_LOCALES` keep working."""
    category = lines_content.Category.model_validate({"id": "opening", "name": {"en": "Opening lines"}, "tips": [{"en": "Any flex?"}]})
    assert lines_content.locales_of([category]) == ["en"]


def test_the_response_schema_pins_the_ids_and_the_languages():
    """What `GeneratedLines` declares is what Gemini is constrained to — there is no second
    schema to keep in step."""
    category = lines_content.GeneratedLines.model_json_schema()["$defs"]["Category"]["properties"]
    assert category["id"]["enum"] == list(lines_content.category_ids())
    assert category["name"]["required"] == list(lines_content.locales())
    assert category["tips"]["items"]["required"] == list(lines_content.locales())
    assert "additionalProperties" not in category["name"]


def test_what_to_generate_is_configuration(monkeypatch):
    """Every knob is read per call, so the schema Gemini gets and the task it is given follow
    `.env` — nothing is decided when this module is imported."""
    monkeypatch.setenv("LINES_CATEGORY_IDS", "opening, closing ")
    monkeypatch.setenv("LINES_PER_CATEGORY", "7")
    monkeypatch.setenv("LINES_LOCALES", "en,pt-BR")

    assert lines_content.category_ids() == ("opening", "closing")
    assert lines_content.locales() == ("en", "pt-BR")
    category = lines_content.GeneratedLines.model_json_schema()["$defs"]["Category"]["properties"]
    assert category["id"]["enum"] == ["opening", "closing"]
    assert category["name"]["required"] == ["en", "pt-BR"]

    prompt = generation.task_prompt()
    assert "opening, closing" in prompt and "exactly 7 lines" in prompt and "en, pt-BR" in prompt


def test_the_prompts_come_from_config(monkeypatch):
    monkeypatch.setenv("LINES_TASK_PROMPT", "Write {count} categories ({categories}) in {locales}. {typo}")
    assert generation.task_prompt() == "Write 3 categories (opening, followup, closing) in en, es. {typo}"


def test_the_bundled_lines_cover_every_category():
    assert [category.id for category in lines_content.FALLBACK_CATEGORIES] == list(lines_content.category_ids())


# ── generation ────────────────────────────────────────────────────────────────


class FakeGenerator:
    """Stands in for Gemini: records the call and returns a queued result."""

    model = "fake-gemini"

    def __init__(self, result=None, error=None):
        self.result, self.error, self.calls = result, error, []

    def generate(self, *, system, parts, response_model):
        self.calls.append({"system": system, "parts": parts, "response_model": response_model})
        if self.error:
            raise self.error
        return self.result


def test_generation_asks_for_the_rendered_categories():
    generator = FakeGenerator(lines_content.GeneratedLines(categories=CATS))

    categories = generation.generate_categories(generator)

    assert categories == CATS
    call = generator.calls[0]
    assert call["response_model"] is lines_content.GeneratedLines
    assert "BUYER" in call["system"]
    assert str(config.LINES_PER_CATEGORY.value) in call["parts"][0]["text"]


def test_an_answer_without_usable_lines_cannot_validate():
    for unusable in ({"categories": []}, {"categories": [{"id": "x", "name": "y", "tips": []}]}, {}):
        with pytest.raises(ValidationError):
            lines_content.GeneratedLines.model_validate(unusable)


def test_generation_failures_reach_the_caller():
    with pytest.raises(UpstreamError):
        generation.generate_categories(FakeGenerator(error=UpstreamError("quota")))


# ── storage ───────────────────────────────────────────────────────────────────


def test_the_endpoint_serves_the_bundled_lines_until_a_generation_lands():
    store = lines_store.InMemoryLinesStore(clock=lambda: NOW)

    content = lines_content.current(store)
    assert content.source == "fallback"
    assert [c.id for c in content.categories] == ["opening", "followup", "closing"]

    store.write(CATS, model="fake-gemini")

    content = lines_content.current(store)
    assert content.source == "generated"
    assert content.categories == CATS
    assert content.updated_at == NOW


def test_a_storage_failure_still_serves_content():
    class Broken:
        def read(self):
            raise RuntimeError("firestore down")

        def write(self, categories, *, model):
            raise RuntimeError("firestore down")

    assert lines_content.current(Broken()).source == "fallback"


class FakeFirestore:
    """Just enough of the Admin SDK to stand in for `content/lines_that_land`."""

    def __init__(self, data=None):
        self.data = data

    def collection(self, name):
        assert name == "content"
        return self

    def document(self, name):
        assert name == "lines_that_land"
        return self

    @property
    def exists(self):
        return self.data is not None

    def get(self):
        return self

    def to_dict(self):
        return self.data

    def set(self, data):
        self.data = data


def test_the_stored_document_round_trips_through_the_content_model():
    firestore = FakeFirestore()
    store = lines_store.FirestoreLinesStore(client=firestore, clock=lambda: NOW)

    store.write(CATS, model="fake-gemini")

    assert firestore.data == {
        "categories": CATS_JSON,
        "locales": ["en", "es"],
        "generated_at": NOW,
        "model": "fake-gemini",
    }
    stored = store.read()
    assert stored.categories == CATS
    assert stored.updated_at == NOW
    assert stored.source == "generated"


def test_a_stored_document_that_no_longer_fits_falls_back():
    """The read validates with the model that wrote it, so a document from an older shape is
    treated like no content at all rather than reaching the app."""
    older_shape = {"categories": [{"id": "opening", "name": "Opening lines", "tips": ["Any flex?"]}]}
    store = lines_store.FirestoreLinesStore(client=FakeFirestore(older_shape), clock=lambda: NOW)

    assert lines_content.current(store).source == "fallback"


# ── HTTP function ─────────────────────────────────────────────────────────────


@pytest.fixture
def served(monkeypatch):
    """The endpoint reads the generated document."""
    store = lines_store.InMemoryLinesStore(clock=lambda: NOW)
    store.write(CATS, model="fake-gemini")
    monkeypatch.setattr(main, "FirestoreLinesStore", lambda: store)
    return store


def _get(method="GET"):
    with Flask(__name__).test_request_context("/lines_that_land", method=method):
        res = main.lines_that_land(request)
    return res.status_code, json.loads(res.get_data(as_text=True)), res.headers


def test_get_returns_multilocale_payload_and_cache_headers(served):
    status, body, headers = _get()
    assert status == 200
    assert body["categories"] == CATS_JSON  # every locale, always
    assert body["locales"] == ["en", "es"]
    assert body["refresh_interval_hours"] == 24
    assert body["source"] == "generated"
    assert body["updated_at"] == "2026-09-18T10:00:00Z"
    assert headers["Cache-Control"] == "public, max-age=86400, s-maxage=86400"
    assert headers["Last-Modified"] == "Fri, 18 Sep 2026 10:00:00 GMT"
    assert headers["Content-Type"].startswith("application/json")


def test_non_get_methods_are_rejected(served):
    status, body, _ = _get(method="POST")
    assert status == 405
    assert body["error"]["status"] == "METHOD_NOT_ALLOWED"
