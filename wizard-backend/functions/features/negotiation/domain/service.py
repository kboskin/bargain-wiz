"""The three asks, shared by the stateless endpoints and the conversation worker."""

from core.ai import Generated, ModelManager

from .answers import ExpressAnswer, OptionsAnswer, ReplyAnswer
from .models import ExpressRequest, ProRequest
from .prompts import PromptBuilder


class NegotiationService:
    """Request → prompt → one model call → a validated answer, with the model that wrote it
    and the call's token usage."""

    def __init__(self, model: ModelManager, prompts: PromptBuilder):
        self._model = model
        self._prompts = prompts

    async def express(self, request: ExpressRequest) -> Generated[ExpressAnswer]:
        return await self._model.generate(
            self._prompts.express(request), ExpressAnswer, operation="express"
        )

    async def reply(self, request: ProRequest) -> Generated[ReplyAnswer]:
        return await self._model.generate(
            self._prompts.pro(request), ReplyAnswer, operation="reply"
        )

    async def options(self, request: ProRequest) -> Generated[OptionsAnswer]:
        return await self._model.generate(
            self._prompts.pro(request), OptionsAnswer, operation="options"
        )

    async def pro(self, request: ProRequest) -> Generated[ReplyAnswer] | Generated[OptionsAnswer]:
        return await (self.options(request) if request.mode == "options" else self.reply(request))
