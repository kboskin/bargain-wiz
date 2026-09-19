"""Request body → model, with pydantic's complaints turned into a 400."""
from core import config
from core.errors import BadRequest
from core.validation import validate_model

from ..domain.models import ExpressRequest, Image, Profile, ProRequest


def parse_profile(body: dict) -> Profile:
    return validate_model(Profile, body, BadRequest)


def parse_images(raw, *, max_images: int | None = None) -> list[Image]:
    """`[{"mime_type": …, "data": …}]` → decoded images, size-checked as a set."""
    max_images = config.MAX_IMAGES.value if max_images is None else max_images
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise BadRequest('"images" must be a list')
    if len(raw) > max_images:
        raise BadRequest(f"At most {max_images} images per request")
    images = [validate_model(Image, item, BadRequest) for item in raw]
    if sum(len(image.data) for image in images) > config.MAX_TOTAL_IMAGE_BYTES.value:
        raise BadRequest(f"Images together must be under {config.MAX_TOTAL_IMAGE_BYTES.value // 1_000_000} MB")
    return images


def parse_express_request(body: dict) -> ExpressRequest:
    return validate_model(ExpressRequest, body, BadRequest)


def parse_pro_request(body: dict) -> ProRequest:
    return validate_model(ProRequest, body, BadRequest)
