"""Settings: what each variable may say, how a bad value is reported, and that `.env` and the
code agree on the list."""

from datetime import UTC, datetime
from pathlib import Path

import pytest

import main
from core.ai import ModelManager
from core.ai.providers import OllamaProvider, ProviderRegistry
from core.config import (
    LinesSettings,
    ModelSettings,
    ModelSpec,
    OllamaSettings,
    RuntimeSettings,
    Settings,
    VertexSettings,
)
from core.errors import ConfigError
from support import TEST_RUNTIME, FixedClock, InMemoryLinesStore, InMemoryMetrics, call, install

FUNCTIONS = Path(__file__).resolve().parents[1]


def _env_keys(name: str) -> list[str]:
    lines = (FUNCTIONS / name).read_text(encoding="utf-8").splitlines()
    return [
        line.split("=", 1)[0].strip()
        for line in lines
        if line.strip() and not line.lstrip().startswith("#")
    ]


@pytest.mark.parametrize(
    ("raw", "provider", "name"),
    [
        ("vertex/gemini-3.8-flash", "vertex", "gemini-3.8-flash"),
        (" Ollama/qwen2.5vl:7b ", "ollama", "qwen2.5vl:7b"),  # the tag's colon is the model's
        (
            "ollama/hf.co/org/model:Q4",
            "ollama",
            "hf.co/org/model:Q4",
        ),  # only the first slash splits
    ],
)
def test_ai_model_names_the_provider_and_the_model(monkeypatch, raw, provider, name):
    monkeypatch.setenv("AI_MODEL", raw)
    spec = ModelSettings.current().spec
    assert (spec.provider, spec.name) == (provider, name)
    assert str(spec) == f"{provider}/{name}"


@pytest.mark.parametrize("raw", ["gemini-3.8-flash", "vertex/", "/gemini", ""])
def test_an_ai_model_without_a_provider_is_a_config_error_naming_the_variable(monkeypatch, raw):
    monkeypatch.setenv("AI_MODEL", raw)
    with pytest.raises(ConfigError) as raised:
        ModelSettings.current()
    assert "AI_MODEL" in str(raised.value) and "<provider>/<model>" in str(raised.value)
    assert raised.value.status == 500 and raised.value.public_message == "Unexpected error."


def test_an_unknown_provider_lists_the_known_ones(monkeypatch):
    monkeypatch.setenv("AI_MODEL", "openai/gpt-x")
    with pytest.raises(ConfigError) as raised:
        ModelManager.from_settings(ModelSettings.current(), TEST_RUNTIME, metrics=InMemoryMetrics())
    assert "openai" in str(raised.value) and "ollama, vertex" in str(raised.value)
    assert ProviderRegistry.default().names == ["ollama", "vertex"]


def test_the_manager_builds_the_provider_the_variable_names(monkeypatch):
    monkeypatch.setenv("AI_MODEL", "ollama/qwen2.5vl:7b")
    manager = ModelManager.from_settings(
        ModelSettings.current(), TEST_RUNTIME, metrics=InMemoryMetrics()
    )
    assert (manager.provider, manager.model) == ("ollama", "qwen2.5vl:7b")


def test_an_empty_temperature_means_the_models_default(monkeypatch):
    monkeypatch.setenv("AI_TEMPERATURE", "")
    assert ModelSettings.current().temperature is None
    monkeypatch.setenv("AI_TEMPERATURE", "0.4")
    assert ModelSettings.current().temperature == 0.4
    monkeypatch.setenv("AI_TEMPERATURE", "warm")
    with pytest.raises(ConfigError, match="AI_TEMPERATURE"):
        ModelSettings.current()


def test_vertex_choices_normalise_allow_empty_and_reject_the_unknown(monkeypatch):
    monkeypatch.setenv("VERTEX_THINKING_LEVEL", " Low ")
    monkeypatch.setenv("VERTEX_MEDIA_RESOLUTION", "")
    vertex = VertexSettings.current()
    assert (vertex.thinking_level, vertex.media_resolution) == ("low", None)
    monkeypatch.setenv("VERTEX_THINKING_LEVEL", "minimal")
    with pytest.raises(ConfigError) as raised:
        VertexSettings.current()
    assert "VERTEX_THINKING_LEVEL" in str(raised.value)


def test_lists_are_comma_separated_and_may_not_be_empty(monkeypatch):
    monkeypatch.setenv("LINES_LOCALES", " en, pt-BR ,")
    assert LinesSettings.current().locales == ("en", "pt-BR")
    monkeypatch.setenv("LINES_LOCALES", " , ")
    with pytest.raises(ConfigError, match="LINES_LOCALES"):
        LinesSettings.current()


def test_the_ollama_url_is_a_base_url(monkeypatch):
    monkeypatch.setenv("OLLAMA_URL", "http://127.0.0.1:11434/ ")
    ollama = OllamaSettings.current()
    assert ollama.url == "http://127.0.0.1:11434"
    assert (
        OllamaProvider("m", ModelSettings.current(), ollama=ollama).url
        == "http://127.0.0.1:11434/api/chat"
    )


def test_sections_are_frozen_values():
    spec = ModelSpec.model_validate("vertex/gemini-3.8-flash")
    with pytest.raises(ValueError):
        spec.name = "other"  # type: ignore[misc]


def test_one_variable_can_feed_two_sections():
    """REQUEST_TIMEOUT_SEC is the function's timeout and the longest a model call may take:
    one param, declared once, read by both."""
    assert ModelSettings.param("timeout_sec") is RuntimeSettings.param("timeout_sec")


def test_a_bad_model_setting_does_not_take_down_an_endpoint_that_needs_no_model(monkeypatch):
    """Sections are read when something uses them, so the public Lines endpoint keeps serving
    while the model configuration is broken."""
    monkeypatch.setenv("AI_MODEL", "not-a-spec")
    monkeypatch.setenv("VERTEX_THINKING_LEVEL", "bogus")
    clock = FixedClock(datetime(2026, 9, 25, tzinfo=UTC))
    install(monkeypatch, lines_store=InMemoryLinesStore(clock), clock=clock)
    status, body, _ = call(main.lines_that_land, "GET", "/lines_that_land")
    assert status == 200 and body["source"] == "fallback"


def test_a_bad_setting_on_the_path_is_a_bare_500(monkeypatch):
    monkeypatch.setenv("AI_MODEL", "not-a-spec")
    install(monkeypatch)
    status, body, _ = call(main.express_dealmaker, "POST", "/", {"text": "bike $300"})
    assert status == 500 and body["error"] == {"status": "INTERNAL", "message": "Unexpected error."}


def test_every_variable_is_declared_once_and_listed_in_the_env_file():
    """`.env` is where a variable's deployed value lives, so it lists exactly what the code
    reads: a key the code no longer declares, or a declaration `.env` forgot, fails here."""
    declared = Settings.variables()
    assert len(declared) == len(set(declared))
    listed = _env_keys(".env")
    assert len(listed) == len(set(listed)), "a key is listed twice in .env"
    assert set(listed) == set(declared)


def test_the_emulator_overrides_only_what_the_code_declares():
    local = FUNCTIONS / ".env.local"
    if not local.exists():
        pytest.skip(".env.local is this machine's (git-ignored)")
    assert set(_env_keys(".env.local")) <= set(Settings.variables())
