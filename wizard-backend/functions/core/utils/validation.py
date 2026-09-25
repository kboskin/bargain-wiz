"""The one place a pydantic error becomes a client-facing message."""

from pydantic import BaseModel, ValidationError

from core.errors import BadRequest


class Validation:
    @staticmethod
    def describe(exc: ValidationError, limit: int = 5) -> str:
        """`field: problem; field: problem` for the first [limit] errors."""
        details = []
        for err in exc.errors()[:limit]:
            loc = ".".join(str(part) for part in err["loc"]) or "body"
            details.append(f"{loc}: {err['msg'].removeprefix('Value error, ')}")
        return "; ".join(details)

    @classmethod
    def parse[M: BaseModel](
        cls, model: type[M], data: object, error: type[Exception] = BadRequest
    ) -> M:
        """`model.model_validate(data)`, with pydantic's complaints raised as [error] — a 400
        by default."""
        try:
            return model.model_validate(data)
        except ValidationError as exc:
            raise error(cls.describe(exc)) from exc
