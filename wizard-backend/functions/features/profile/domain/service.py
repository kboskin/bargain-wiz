"""The caller's profile document: read it, and merge a PATCH into it.

One document per person at `users/{uid}`, the same document that parents that person's
`conversations` — everything about a user lives under one path. The document id is always
the Firebase Auth uid: every install signs in anonymously before it can reach this endpoint,
so there is no signed-out document to key by and no second identifier to reconcile. The
client sends no identity of its own; the ID token is the identity. Contract:
wizard-app/PROFILE_SYNC.md.
"""

from typing import ClassVar

from core.auth.firebase import AuthInfo
from core.errors import NotFound
from core.firestore import FieldOp
from core.observability import StructuredLogger
from core.utils import Validation

from .patches import ProfilePatchBody
from .ports import ProfileStore


class ProfileService:
    # `(section, field)` pairs a client fills once and may never re-set. A referral code
    # credits whoever brought this person in: re-entering it would re-attribute an install that
    # is already credited, so a later PATCH carrying one is dropped. The Profile screen hides
    # the field (`ProfileFields.lockedKeys`); this is what makes it true for an older or
    # tampered client. An explicit null still deletes — forgetting a code has to stay possible.
    WRITE_ONCE: ClassVar[tuple[tuple[str, str], ...]] = (("referral", "code"),)

    def __init__(self, store: ProfileStore, log: StructuredLogger):
        self._store = store
        self._log = log

    async def read(self, auth: AuthInfo) -> dict:
        doc = await self._store.get(auth.uid)
        if doc is None:
            raise NotFound("No profile yet")
        return doc

    async def patch(self, auth: AuthInfo, body: dict) -> dict:
        """Merge the validated body into `users/{uid}`, creating it on the first call; returns
        the resulting document."""
        request = Validation.parse(ProfilePatchBody, body)
        if unknown := ProfilePatchBody.unknown_sections(body):
            self._log.info("ignoring unknown profile sections", sections=unknown)
        current = await self._store.get(auth.uid)
        patch = self.drop_write_once(request.to_patch(auth), current)
        if current is None:
            patch["created_at"] = FieldOp.SERVER_TIME
        await self._store.merge(auth.uid, patch)
        self._log.info("profile patched", uid=auth.uid, sections=sorted(body))
        return await self._store.get(auth.uid) or {}

    def drop_write_once(self, patch: dict, current: dict | None) -> dict:
        """Strips the [WRITE_ONCE] fields `current` already records, so the first value given
        stands. The section goes with the field: what is left of it (`entered_at`) is the stamp
        the server wrote for that first value."""
        for section, field in self.WRITE_ONCE:
            incoming = patch.get(section)
            if (
                not isinstance(incoming, dict)
                or incoming.get(field, FieldOp.DELETE) is FieldOp.DELETE
            ):
                continue  # nothing set, or an explicit delete
            stored = (current or {}).get(section)
            if isinstance(stored, dict) and stored.get(field):
                self._log.info(
                    "ignoring a write-once field that is already set", section=section, field=field
                )
                patch.pop(section)
        return patch
