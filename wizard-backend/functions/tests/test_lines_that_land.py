"""Tests for the Lines tab: generation, storage and the endpoint that serves them."""

import asyncio
from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

import main
from core.config import LinesSettings
from core.errors import UpstreamError
from core.observability import LinesRefresh, ModelCall, StructuredLogger
from features.lines_that_land.data import store as lines_store
from features.lines_that_land.domain import content as lines_content
from features.lines_that_land.domain.content import LinesContent
from features.lines_that_land.domain.service import LinesService
from support import FixedClock, InMemoryLinesStore, InMemoryMetrics, call, install

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
CLOCK = FixedClock(NOW)


def _service(store) -> LinesService:
    return LinesService(store, clock=CLOCK, log=StructuredLogger.named("lines_that_land"))


def _generator(monkeypatch, **parts):
    """The scheduled generation as `refresh_lines` builds it, wired to [parts]."""
    return install(monkeypatch, clock=CLOCK, **parts).lines.generator


# ── the content model (what the model may answer, and what we store) ──────────


def test_texts_are_trimmed():
    category = lines_content.Category.model_validate(
        {
            "id": "opening",
            "name": {"en": "  Opening lines ", "es": "Frases de apertura\n"},
            "tips": CATS_JSON[0]["tips"],
        }
    )
    assert category.name == {"en": "Opening lines", "es": "Frases de apertura"}


@pytest.mark.parametrize(
    "unusable",
    [
        {
            "id": "opening",
            "name": {"en": " ", "es": " "},
            "tips": CATS_JSON[0]["tips"],
        },  # no text at all
        {
            "id": "opening",
            "name": "Opening lines",
            "tips": CATS_JSON[0]["tips"],
        },  # not a language map
        {"id": "opening", "name": CATS_JSON[0]["name"], "tips": []},  # no lines
    ],
)
def test_incomplete_categories_are_rejected(unusable):
    with pytest.raises(ValidationError):
        lines_content.Category.model_validate(unusable)


def test_content_in_fewer_languages_than_configured_still_reads():
    """Which languages a generation must write is enforced by the schema, not by this model:
    the bundled lines and documents written under an older `LINES_LOCALES` keep working."""
    category = lines_content.Category.model_validate(
        {"id": "opening", "name": {"en": "Opening lines"}, "tips": [{"en": "Any flex?"}]}
    )
    assert LinesContent(categories=[category], updated_at=NOW, source="generated").locales() == [
        "en"
    ]


def test_the_response_schema_pins_the_ids_and_the_languages():
    """What `GeneratedLines` declares is what Gemini is constrained to — there is no second
    schema to keep in step."""
    category = lines_content.GeneratedLines.model_json_schema()["$defs"]["Category"]["properties"]
    settings = LinesSettings.current()
    assert category["id"]["enum"] == list(settings.category_ids)
    assert category["name"]["required"] == list(settings.locales)
    assert category["tips"]["items"]["required"] == list(settings.locales)
    assert "additionalProperties" not in category["name"]


def test_what_to_generate_is_configuration(monkeypatch):
    """Every knob is read per call, so the schema Gemini gets and the task it is given follow
    `.env` — nothing is decided when this module is imported."""
    monkeypatch.setenv("LINES_CATEGORY_IDS", "opening, closing ")
    monkeypatch.setenv("LINES_PER_CATEGORY", "7")
    monkeypatch.setenv("LINES_LOCALES", "en,pt-BR")

    assert LinesSettings.current().category_ids == ("opening", "closing")
    assert LinesSettings.current().locales == ("en", "pt-BR")
    category = lines_content.GeneratedLines.model_json_schema()["$defs"]["Category"]["properties"]
    assert category["id"]["enum"] == ["opening", "closing"]
    assert category["name"]["required"] == ["en", "pt-BR"]

    prompt = _generator(monkeypatch).task_prompt()
    assert "opening, closing" in prompt and "exactly 7 lines" in prompt and "en, pt-BR" in prompt


def test_the_prompts_come_from_config(monkeypatch):
    monkeypatch.setenv(
        "LINES_TASK_PROMPT", "Write {count} categories ({categories}) in {locales}. {typo}"
    )
    assert (
        _generator(monkeypatch).task_prompt()
        == "Write 3 categories (opening, followup, closing) in en, es. {typo}"
    )


def test_the_bundled_lines_cover_every_category():
    assert [category.id for category in LinesContent.fallback_categories()] == list(
        LinesSettings.current().category_ids
    )


# ── generation ────────────────────────────────────────────────────────────────


def test_generation_asks_for_the_rendered_categories(monkeypatch):
    monkeypatch.setenv("LINES_PER_CATEGORY", "4")
    prompt = _generator(monkeypatch).prompt()
    assert "BUYER" in prompt.system
    assert prompt.images == [] and "exactly 4 lines" in prompt.texts[0]


def test_an_answer_without_usable_lines_cannot_validate():
    for unusable in (
        {"categories": []},
        {"categories": [{"id": "x", "name": "y", "tips": []}]},
        {},
    ):
        with pytest.raises(ValidationError):
            lines_content.GeneratedLines.model_validate(unusable)


@pytest.mark.usefixtures("unreachable_model")
def test_a_failed_generation_reaches_the_caller_and_keeps_the_stored_lines(monkeypatch):
    store = InMemoryLinesStore(CLOCK)
    store.seed(CATS)
    metrics = InMemoryMetrics()

    with pytest.raises(UpstreamError):
        asyncio.run(_generator(monkeypatch, lines_store=store, metrics=metrics).refresh())

    assert store.content.categories == CATS
    assert [(m.outcome, m.categories) for m in metrics.of(LinesRefresh)] == [("call_failed", 0)]


def test_the_local_model_writes_the_whole_tab(monkeypatch, local_model):
    # Kept small so the test is quick: two categories, two lines each, two languages.
    monkeypatch.setenv("LINES_CATEGORY_IDS", "opening,closing")
    monkeypatch.setenv("LINES_PER_CATEGORY", "2")
    store = InMemoryLinesStore(CLOCK)
    metrics = InMemoryMetrics()

    content = asyncio.run(_generator(monkeypatch, lines_store=store, metrics=metrics).refresh())

    assert content.source == "generated" and store.content == content
    assert {category.id for category in content.categories} <= {"opening", "closing"}
    for category in content.categories:
        assert set(category.name) == {"en", "es"}
        assert all(set(tip) == {"en", "es"} for tip in category.tips)
    [refresh] = metrics.of(LinesRefresh)
    assert refresh.outcome == "ok" and refresh.categories == len(content.categories)
    assert metrics.of(ModelCall)[0].operation == "lines"


# ── storage ───────────────────────────────────────────────────────────────────


def test_the_endpoint_serves_the_bundled_lines_until_a_generation_lands():
    store = InMemoryLinesStore(CLOCK)

    content = asyncio.run(_service(store).current())
    assert content.source == "fallback"
    assert [c.id for c in content.categories] == ["opening", "followup", "closing"]

    store.seed(CATS)

    content = asyncio.run(_service(store).current())
    assert content.source == "generated"
    assert content.categories == CATS
    assert content.updated_at == NOW


def test_a_storage_failure_still_serves_content():
    class Broken:
        async def read(self):
            raise RuntimeError("firestore down")

        async def write(self, categories, *, model):
            raise RuntimeError("firestore down")

    assert asyncio.run(_service(Broken()).current()).source == "fallback"


class FakeFirestore:
    """Just enough of the async Firestore client to stand in for `content/lines_that_land`."""

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

    async def get(self):
        return self

    def to_dict(self):
        return self.data

    async def set(self, data):
        self.data = data


def test_the_stored_document_round_trips_through_the_content_model():
    firestore = FakeFirestore()
    store = lines_store.FirestoreLinesStore(firestore, CLOCK)

    asyncio.run(store.write(CATS, model="qwen2.5vl:7b"))

    assert firestore.data == {
        "categories": CATS_JSON,
        "locales": ["en", "es"],
        "generated_at": NOW,
        "model": "qwen2.5vl:7b",
    }
    stored = asyncio.run(store.read())
    assert stored.categories == CATS
    assert stored.updated_at == NOW
    assert stored.source == "generated"


def test_a_stored_document_that_no_longer_fits_falls_back():
    """The read validates with the model that wrote it, so a document from an older shape is
    treated like no content at all rather than reaching the app."""
    older_shape = {
        "categories": [{"id": "opening", "name": "Opening lines", "tips": ["Any flex?"]}]
    }
    store = lines_store.FirestoreLinesStore(FakeFirestore(older_shape), CLOCK)

    assert asyncio.run(_service(store).current()).source == "fallback"


# ── HTTP function ─────────────────────────────────────────────────────────────


@pytest.fixture
def served(monkeypatch):
    """The endpoint reads the generated document."""
    store = InMemoryLinesStore(CLOCK)
    store.seed(CATS)
    install(monkeypatch, lines_store=store, clock=CLOCK)
    return store


def _get(method="GET"):
    return call(main.lines_that_land, method, "/lines_that_land")


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
