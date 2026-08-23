"""
Canonical family-member scoping rule, used everywhere patient data is queried (records,
clinical entities, AI chat context/retrieval). A missing/omitted family_member_id always
means "the account owner's own data" - never "no filter" - so a family member's records
can never bleed into the owner's view, or vice versa, regardless of which endpoint asks.
"""
import uuid

from fastapi import status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError, ErrorCode


def family_scope(model, family_member_id: uuid.UUID | None):
    """Returns a SQLAlchemy filter condition: exact-match scoping, self vs. one specific member."""
    if family_member_id is None:
        return model.family_member_id.is_(None)
    return model.family_member_id == family_member_id


async def validate_family_member_ownership(
    db: AsyncSession, owner_id: uuid.UUID, family_member_id: uuid.UUID | None
) -> None:
    """
    Raises 404 if family_member_id is set but doesn't belong to owner_id. Call this wherever
    a client-supplied family_member_id is used to CREATE a row - reads are already safe (every
    query ANDs user_id == current_user.id), but without this check a client can attach a new
    row to an arbitrary/foreign family_member_id at write time.
    """
    if family_member_id is None:
        return
    from app.models.family import FamilyMember

    exists = await db.scalar(
        select(FamilyMember.id).where(
            FamilyMember.id == family_member_id,
            FamilyMember.owner_user_id == owner_id,
            FamilyMember.is_deleted == False,  # noqa: E712
        )
    )
    if not exists:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Family member not found",
            error_code=ErrorCode.FAMILY_MEMBER_NOT_FOUND,
        )
