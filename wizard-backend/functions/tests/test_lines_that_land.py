"""Tests for the lines_that_land callable and its content service."""
import json
from datetime import UTC, datetime

import pytest
from flask import Flask, request

import lines_that_land_service as svc
import main

CATS = [
    {
        "id": "opening",
        "name": {"en": "Opening lines", "es": "Frases de apertura"},
        "tips": [{"en": "Any flex on price?", "es": "¿Hay margen en el precio?"}, {"en": "English only"}],
    }
]
UPDATE_TIME = "2026-09-12T10:00:00.123456Z"
UPDATED = datetime(2026, 9, 12, 10, 0, 0, 123456, tzinfo=UTC)


class Clock:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


class FakeConfig:
    def __init__(self, value: str, source: str):
        self._value, self._source = value, source

    def get_string(self, key):
        assert key == svc.PARAM_KEY
        return self._value

    def get_value_source(self, key):
        return self._source


class FakeTemplate:
    """Mimics remote_config.ServerTemplate: async load(), set(), evaluate(), to_json()."""

    def __init__(self, remote_value=None, fail_load=False):
        self.remote_value = remote_value  # str | None: None = parameter absent remotely
        self.fail_load = fail_load
        self.loads = 0
        self._loaded = False
        self._emptied = False

    async def load(self):
        self.loads += 1
        if self.fail_load:
            raise RuntimeError("remote config down")
        self._loaded = True

    def set(self, template_data_json):
        self._emptied = True

    def evaluate(self, context=None):
        if not (self._loaded or self._emptied):
            raise ValueError("No Remote Config Server template in cache.")
        if self._loaded and self.remote_value is not None:
            return FakeConfig(self.remote_value, "remote")
        return FakeConfig(json.dumps({"categories": svc.FALLBACK_CATEGORIES}), "default")

    def to_json(self):
        return json.dumps({"parameters": {}, "conditions": [], "version": {"updateTime": UPDATE_TIME}})


def remote_json(categories):
    return json.dumps({"categories": categories}, ensure_ascii=False)


# ── text helpers ──────────────────────────────────────────────────────────────


def test_parse_categories_normalises_strings_and_drops_empty_entries():
    cats = svc.parse_categories(
        {
            "categories": [
                {"id": "opening", "name": "Opening lines", "tips": [" Plain string "]},
                {"id": "empty", "name": "No tips", "tips": ["  "]},
                "junk",
            ]
        }
    )
    assert cats == [{"id": "opening", "name": {"en": "Opening lines"}, "tips": [{"en": "Plain string"}]}]


def test_multilocale_content_is_kept():
    cats = svc.parse_categories({"categories": CATS})
    assert cats[0]["name"] == {"en": "Opening lines", "es": "Frases de apertura"}
    assert svc.locales_of(cats) == ["en", "es"]


def test_fallback_content_is_fully_translated_to_spanish():
    for category in svc.FALLBACK_CATEGORIES:
        assert set(category["name"]) == {"en", "es"}
        for tip in category["tips"]:
            assert set(tip) == {"en", "es"}, tip
    assert svc.locales_of(svc.FALLBACK_CATEGORIES) == ["en", "es"]


# ── Remote Config reading ─────────────────────────────────────────────────────


def test_read_content_uses_the_remote_parameter_and_template_update_time():
    template = FakeTemplate(remote_value=remote_json(CATS))
    import asyncio

    asyncio.run(template.load())
    content = svc.read_content(template)
    assert content.source == "remote_config"
    assert content.categories == CATS
    assert content.updated_at == UPDATED


def test_read_content_falls_back_when_the_remote_value_is_unusable():
    for bad in ("not json", remote_json([]), remote_json([{"id": "x", "name": "y", "tips": []}])):
        template = FakeTemplate(remote_value=bad)
        import asyncio

        asyncio.run(template.load())
        content = svc.read_content(template)
        assert content.source == "fallback"
        assert [c["id"] for c in content.categories] == ["opening", "followup", "closing"]


def test_service_caches_until_the_interval_elapses():
    clock, template = Clock(), FakeTemplate(remote_value=remote_json(CATS))
    service = svc.LinesThatLandService(24, template=template, clock=clock)
    first = service.get()
    clock.t += 24 * 3600 - 1
    assert service.get() is first
    assert template.loads == 1
    clock.t += 2
    service.get()
    assert template.loads == 2


def test_service_serves_defaults_when_remote_config_is_down_and_retries_soon():
    clock, template = Clock(), FakeTemplate(remote_value=remote_json(CATS), fail_load=True)
    service = svc.LinesThatLandService(24, template=template, clock=clock)
    content = service.get()
    assert content.source == "fallback"
    assert [c["id"] for c in content.categories] == ["opening", "followup", "closing"]
    clock.t += svc.FALLBACK_RETRY_SECONDS + 1
    template.fail_load = False
    assert service.get().source == "remote_config"
    assert template.loads == 2


def test_service_keeps_previous_content_when_a_refresh_fails():
    clock, template = Clock(), FakeTemplate(remote_value=remote_json(CATS))
    service = svc.LinesThatLandService(1, template=template, clock=clock)
    good = service.get()
    template.fail_load = True
    clock.t += 3601
    assert service.get() is good


# ── HTTP function ─────────────────────────────────────────────────────────────


@pytest.fixture
def remote_service(monkeypatch):
    service = svc.LinesThatLandService(24, template=FakeTemplate(remote_value=remote_json(CATS)))
    monkeypatch.setattr(main, "_service", service)
    return service


def _get(method="GET"):
    app = Flask(__name__)
    with app.test_request_context("/lines_that_land", method=method):
        res = main.lines_that_land(request)
    return res.status_code, json.loads(res.get_data(as_text=True)), res.headers


def test_get_returns_multilocale_payload_and_cache_headers(remote_service):
    status, body, headers = _get()
    assert status == 200
    assert body["categories"] == CATS  # every locale, always
    assert body["locales"] == ["en", "es"]
    assert body["refresh_interval_hours"] == 24
    assert body["source"] == "remote_config"
    assert body["updated_at"] == "2026-09-12T10:00:00Z"
    assert headers["Cache-Control"] == "public, max-age=86400, s-maxage=86400"
    assert headers["Last-Modified"] == "Sat, 12 Sep 2026 10:00:00 GMT"
    assert headers["Content-Type"].startswith("application/json")


def test_non_get_methods_are_rejected(remote_service):
    status, body, _ = _get(method="POST")
    assert status == 405
    assert body["error"]["status"] == "METHOD_NOT_ALLOWED"
