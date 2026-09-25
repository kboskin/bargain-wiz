"""The negotiation feature, wired for one invocation."""

from functools import cached_property

from core.services import CoreServices

from .domain.prompts import PromptBuilder
from .domain.service import NegotiationService
from .presentation.controller import NegotiationController


class NegotiationModule:
    def __init__(self, core: CoreServices):
        self._core = core

    @cached_property
    def prompts(self) -> PromptBuilder:
        return PromptBuilder(self._core.logger("negotiation"))

    @cached_property
    def service(self) -> NegotiationService:
        return NegotiationService(self._core.model, self.prompts)

    @cached_property
    def controller(self) -> NegotiationController:
        return NegotiationController(
            self.service, self._core.authenticator, self._core.logger("negotiation")
        )
