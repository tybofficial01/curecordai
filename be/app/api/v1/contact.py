import structlog
from fastapi import APIRouter, Request, status
from pydantic import BaseModel, EmailStr, Field

from app.core.errors import ApiError, ErrorCode
from app.core.rate_limit import limiter
from app.services.twilio_service import twilio_service

logger = structlog.get_logger()

router = APIRouter(prefix="/contact", tags=["contact"])


class ContactMessageRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    email: EmailStr
    message: str = Field(..., min_length=1, max_length=5000)


class ContactMessageResponse(BaseModel):
    message: str


@router.post("", response_model=ContactMessageResponse, summary="Submit the public contact form")
@limiter.limit("5/hour")
async def submit_contact_message(request: Request, body: ContactMessageRequest):
    sent = await twilio_service.send_contact_message(body.name, body.email, body.message)
    if not sent:
        raise ApiError(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not send your message right now. Please try again shortly.",
            error_code=ErrorCode.CONTACT_MESSAGE_FAILED,
        )
    return ContactMessageResponse(message="Thanks for reaching out - we'll get back to you soon.")
