"""What the Firestore-backed stores share: one invocation's async client, and how the domain's
documents and patches become what the SDK writes.

The domain writes two kinds of thing. A [FirestoreDocument] is a pydantic model of a whole
new document. A [Patch] is a merge: a dict whose values may be plain data, pydantic models
(an image ref, a token count, the lines of an answer) or a [FieldOp] marker, because a merge
has to be able to say "remove this field" and "stamp the server time". [FirestorePatch] turns
either into plain data. The Firestore stores then swap the markers for the SDK's sentinels,
and the in-memory stores the tests use apply them with a clock, so a write means the same
thing in a test and in the cloud.
"""

from enum import Enum
from functools import cached_property
from typing import Any

from pydantic import BaseModel

from core.errors import ConfigError

type Patch = dict[str, Any]


class FieldOp(Enum):
    DELETE = "delete"
    SERVER_TIME = "server_time"


class FirestoreDocument(BaseModel):
    """A new document, written whole. A field left at None is not written at all, so a
    document holds only what it has (a user turn has no `revision`, a Pro chat no
    `keyword`)."""

    def fields(self) -> dict[str, Any]:
        return self.model_dump(exclude_none=True)


class FirestorePatch:
    @classmethod
    def plain(cls, value: Any) -> Any:
        """Documents and models → dicts, recursively, with the [FieldOp] markers kept. A model
        inside a patch is a value and is written as it is, None fields included, so a merge
        that re-writes it cannot keep a stale field from the value it replaces."""
        if isinstance(value, FirestoreDocument):
            return value.fields()
        if isinstance(value, BaseModel):
            return value.model_dump()
        if isinstance(value, dict):
            return {k: cls.plain(v) for k, v in value.items()}
        if isinstance(value, list):
            return [cls.plain(v) for v in value]
        return value

    @classmethod
    def to_sdk(cls, value: Any) -> Any:
        """A document or a patch → what the SDK writes, markers → Firestore sentinels."""
        # Imported on first use: the Firestore client adds ~0.3 s to a cold start, and the
        # stateless AI functions never touch Firestore.
        from google.cloud import firestore

        return cls._translate(
            cls.plain(value),
            {
                FieldOp.DELETE: firestore.DELETE_FIELD,
                FieldOp.SERVER_TIME: firestore.SERVER_TIMESTAMP,
            },
        )

    @classmethod
    def _translate(cls, value: Any, sentinels: dict[FieldOp, Any]) -> Any:
        if isinstance(value, FieldOp):
            return sentinels[value]
        if isinstance(value, dict):
            return {k: cls._translate(v, sentinels) for k, v in value.items()}
        if isinstance(value, list):
            return [cls._translate(v, sentinels) for v in value]
        return value


class FirestoreConnection:
    """One invocation's async Firestore client, made on first use and closed with the
    invocation ([aclose]).

    Not the Admin SDK's `firestore_async.client()`: that one is cached per process, and its
    gRPC channel belongs to the event loop of the first call. Every invocation runs on a loop
    of its own (`asyncio.run` in `main.py`), so the second request would find that loop
    closed. A client per invocation costs one channel setup per request; the credentials are
    the default app's, so the access token is still fetched once per instance. Under the
    emulator the SDK reads FIRESTORE_EMULATOR_HOST and connects there instead."""

    @cached_property
    def client(self) -> Any:
        # Imported on first use, like every Firestore import: ~0.3 s of cold start.
        import firebase_admin
        from google.cloud import firestore

        app = firebase_admin.get_app()
        if not app.project_id:
            raise ConfigError("Firestore needs a project id: set GOOGLE_CLOUD_PROJECT")
        return firestore.AsyncClient(
            credentials=app.credential.get_credential(), project=app.project_id
        )

    async def aclose(self) -> None:
        """Close the gRPC channel, if a call opened one, before the event loop ends. The
        client has no `close()` of its own; its API client exists once a call has been made."""
        if "client" not in self.__dict__:
            return
        api = self.client._firestore_api_internal
        if api is not None:
            await api.transport.close()
