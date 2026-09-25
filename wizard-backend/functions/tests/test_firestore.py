"""The Firestore plumbing every store shares: how documents and patches become SDK data, and
the invocation's async client. Nothing here reaches a server: the client is aimed at a closed
emulator port, and a channel is opened without a call being made."""

import asyncio
import types

import firebase_admin
import pytest
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

from core.ai import TokenUsage
from core.errors import ConfigError
from core.firestore import FieldOp, FirestoreConnection, FirestorePatch
from features.conversations.data.store import FirestoreConversationStore
from features.conversations.domain.documents import (
    ConversationDocuments,
    ExpressRecord,
    ImageRef,
)
from features.negotiation.domain.answers import Line

# ── documents and patches ─────────────────────────────────────────────────────


def test_a_new_document_writes_only_what_it_has_and_stamps_the_server_time():
    ref = ImageRef(path="users/u1/conversations/c1/a.jpg", width=800, height=600, bytes=91_000)

    data = FirestorePatch.to_sdk(ConversationDocuments.user_message("Kallax $180", [ref]))

    assert data == {
        "role": "user",
        "text": "Kallax $180",
        "status": "done",
        "images": [
            {
                "path": "users/u1/conversations/c1/a.jpg",
                "mime_type": "image/jpeg",
                "width": 800,
                "height": 600,
                "bytes": 91_000,
            }
        ],
        "created_at": firestore.SERVER_TIMESTAMP,
    }  # no seq, reply_id, revision or updated_at: the user turn has none yet


def test_a_patch_carries_models_as_values_and_markers_as_sentinels():
    record = ExpressRecord(seeing="A shelf", lines=[Line(intent="opener", text="Hi")])

    data = FirestorePatch.to_sdk(
        {
            "usage": TokenUsage(prompt_tokens=10, output_tokens=2),
            "express": record,
            "error": FieldOp.DELETE,
            "updated_at": FieldOp.SERVER_TIME,
        }
    )

    assert data["usage"] == {
        "prompt_tokens": 10,
        "cached_tokens": 0,
        "output_tokens": 2,
        "thought_tokens": 0,
    }
    # a value is written whole, None included, so a merge cannot keep a stale keyword
    assert data["express"]["keyword"] is None and data["express"]["images"] == []
    assert data["express"]["lines"] == [{"intent": "opener", "text": "Hi", "why": None}]
    assert data["error"] is firestore.DELETE_FIELD
    assert data["updated_at"] is firestore.SERVER_TIMESTAMP


# ── the invocation's client ───────────────────────────────────────────────────


@pytest.fixture
def offline(monkeypatch):
    """The default app with a project and anonymous credentials, and Firestore aimed at a
    closed emulator port: a client can be built and a channel opened, and nothing connects."""
    monkeypatch.setenv("FIRESTORE_EMULATOR_HOST", "127.0.0.1:9")
    credential = types.SimpleNamespace(get_credential=AnonymousCredentials)
    app = types.SimpleNamespace(project_id="demo-project", credential=credential)
    monkeypatch.setattr(firebase_admin, "get_app", lambda: app)
    return app


def test_the_connection_closes_the_channel_its_invocation_opened(offline):
    async def invocation():
        connection = FirestoreConnection()
        store = FirestoreConversationStore(connection.client)
        assert len(store.new_id()) == 20  # made locally: no channel yet
        assert connection.client._firestore_api_internal is None
        channel = connection.client._firestore_api.transport.grpc_channel  # a first call's work
        await connection.aclose()
        with pytest.raises(Exception, match="Channel is closed"):
            await channel.unary_unary("/google.firestore.v1.Firestore/GetDocument")(b"")

    asyncio.run(invocation())


def test_an_invocation_that_never_touches_firestore_builds_no_client(offline):
    connection = FirestoreConnection()

    asyncio.run(connection.aclose())

    assert "client" not in connection.__dict__


def test_a_client_needs_a_project(offline):
    offline.project_id = None
    with pytest.raises(ConfigError, match="project id"):
        _ = FirestoreConnection().client
