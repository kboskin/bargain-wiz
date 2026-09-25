"""Shared fixtures.

No model is ever faked. A test that needs an answer asks the local model through the real
Ollama provider ([local_model]); it is skipped, with the command that fixes it, when Ollama or
the model is not there. A test about a failing model points the same provider at a closed port
([unreachable_model]), which needs nothing running at all. Every other test asks no model.
"""

import json
import os
import urllib.request

import pytest

# The multimodal model the model tests use; any tag that accepts images works.
TEST_AI_MODEL = os.environ.get("TEST_AI_MODEL", "ollama/qwen2.5vl:7b")
OLLAMA_URL = os.environ.get("TEST_OLLAMA_URL", "http://127.0.0.1:11434")


@pytest.fixture(autouse=True)
def _local_model_by_default(monkeypatch):
    """Nothing in a test may reach Vertex: every container is built for the local model, and
    building an Ollama provider does no I/O, so tests that ask nothing pay nothing for it."""
    monkeypatch.setenv("AI_MODEL", TEST_AI_MODEL)
    monkeypatch.setenv("OLLAMA_URL", OLLAMA_URL)
    monkeypatch.setenv("REQUEST_TIMEOUT_SEC", "300")


def _pulled_models() -> set[str] | None:
    try:
        with urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=3) as response:
            return {model["name"] for model in json.loads(response.read()).get("models", [])}
    except OSError:
        return None


@pytest.fixture
def ollama_server() -> str:
    """A running Ollama server (any models)."""
    if _pulled_models() is None:
        pytest.skip(f"needs Ollama running at {OLLAMA_URL} (`ollama serve`)")
    return OLLAMA_URL


@pytest.fixture
def local_model(ollama_server) -> str:
    """The local model the test talks to, as its model id (what documents record as `model`)."""
    provider, _, name = TEST_AI_MODEL.partition("/")
    if provider != "ollama":
        pytest.skip(f"TEST_AI_MODEL must be an ollama/… model (got {TEST_AI_MODEL})")
    pulled = _pulled_models() or set()
    if name not in pulled and f"{name}:latest" not in pulled:
        pytest.skip(f"needs the local model {name} (`ollama pull {name}`)")
    return name


@pytest.fixture
def unreachable_model(monkeypatch) -> None:
    """The real Ollama provider aimed at a port nothing listens on: every call fails fast with
    the error an outage produces."""
    monkeypatch.setenv("AI_MODEL", "ollama/unreachable:test")
    monkeypatch.setenv("OLLAMA_URL", "http://127.0.0.1:9")
