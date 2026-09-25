"""The profile feature, wired for one invocation."""

from functools import cached_property

from core.services import CoreServices

from .data.store import FirestoreProfileStore
from .domain.ports import ProfileStore
from .domain.service import ProfileService
from .presentation.controller import ProfileController


class ProfileModule:
    def __init__(self, core: CoreServices, *, store: ProfileStore | None = None):
        self._core = core
        self._store = store

    @cached_property
    def store(self) -> ProfileStore:
        return self._store or FirestoreProfileStore(self._core.firestore.client)

    @cached_property
    def service(self) -> ProfileService:
        return ProfileService(self.store, self._core.logger("profile"))

    @cached_property
    def controller(self) -> ProfileController:
        return ProfileController(self.service, self._core.authenticator)
