"""`express_dealmaker` and `pro_deal_closer`: stateless, one request → one answer."""

from firebase_functions import https_fn

from core.auth.firebase import Authenticator
from core.http.endpoint import JsonHttp
from core.observability import StructuredLogger
from core.utils import Validation

from ..domain.models import ExpressRequest, ProRequest
from ..domain.service import NegotiationService


class NegotiationController:
    """The HTTP side: an ID token is optional (logged when present, rejected when invalid)."""

    def __init__(
        self, service: NegotiationService, authenticator: Authenticator, log: StructuredLogger
    ):
        self._service = service
        self._auth = authenticator
        self._log = log

    async def express(self, req: https_fn.Request) -> dict:
        """{images|text, keyword?, profile} → {"seeing", "lines": [{intent, text, why}], "model"}."""
        auth = await self._auth.optional(req)
        request = Validation.parse(ExpressRequest, JsonHttp.body(req))
        generated = await self._service.express(request)
        self._log.info(
            "express answered",
            uid=auth.uid if auth else None,
            images=len(request.images),
            text=bool(request.text),
            prompts=request.profile.described,
        )
        return {**generated.answer.model_dump(), "model": generated.model}

    async def pro(self, req: https_fn.Request) -> dict:
        """{messages: [{role, text, images?}], mode: reply|options, regenerate?, profile}
        → reply mode {"reply", "model"}; options mode {"lines", "model"}."""
        auth = await self._auth.optional(req)
        request = Validation.parse(ProRequest, JsonHttp.body(req))
        generated = await self._service.pro(request)
        self._log.info(
            "pro answered",
            uid=auth.uid if auth else None,
            mode=request.mode,
            messages=len(request.messages),
            prompts=request.profile.described,
        )
        return {**generated.answer.model_dump(), "model": generated.model}
