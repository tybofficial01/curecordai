from typing import Annotated

import structlog
from fastapi import Depends, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.errors import ApiError, ErrorCode
from app.core.security import decode_access_token
from app.database import get_db
from app.models.auth import User, UserSession
from app.core.security import hash_token

logger = structlog.get_logger()

bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)] = None,
    db: AsyncSession = Depends(get_db),
) -> User:
    if not credentials:
        logger.debug("Auth rejected - no bearer credentials on request", path=request.url.path)
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            error_code=ErrorCode.NOT_AUTHENTICATED,
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    try:
        payload = decode_access_token(token)
    except ValueError:
        logger.debug("Auth rejected - token decode failed", path=request.url.path)
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            error_code=ErrorCode.TOKEN_INVALID,
        )

    user_id = payload.get("sub")
    if not user_id:
        logger.debug("Auth rejected - token payload missing sub claim", path=request.url.path)
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
            error_code=ErrorCode.TOKEN_PAYLOAD_INVALID,
        )

    # Verify session is still active - eager-load the user in the same query
    # instead of a second round trip via db.get(User, ...)
    token_hash = hash_token(token)
    session = await db.scalar(
        select(UserSession)
        .options(joinedload(UserSession.user))
        .where(
            UserSession.session_token_hash == token_hash,
            UserSession.is_active == True,  # noqa: E712
        )
    )
    if not session:
        logger.debug("Auth rejected - session revoked or not found", user_id=user_id, path=request.url.path)
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session revoked or expired",
            error_code=ErrorCode.SESSION_INVALID,
        )

    user = session.user
    if not user or not user.is_active or user.is_deleted:
        logger.debug("Auth rejected - user not found or deactivated", user_id=user_id, path=request.url.path)
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or deactivated",
            error_code=ErrorCode.SESSION_USER_UNAVAILABLE,
        )

    # Expose actor info for audit middleware
    request.state.user_id = user.id
    request.state.user_role = payload.get("role")

    logger.debug("Auth resolved", user_id=str(user.id), role=payload.get("role"), path=request.url.path)
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
DB = Annotated[AsyncSession, Depends(get_db)]


def require_role(*roles: str):
    """Dependency factory for role-based access control."""
    async def _check(
        current_user: CurrentUser,
        db: DB,
    ) -> User:
        from datetime import datetime, timezone
        from app.models.rbac import UserRole, Role

        now = datetime.now(timezone.utc)
        result = await db.execute(
            select(UserRole)
            .join(Role, UserRole.role_id == Role.id)
            .where(
                UserRole.user_id == current_user.id,
                UserRole.is_active == True,  # noqa: E712
                Role.name.in_(roles),
            )
        )
        user_role = result.scalar_one_or_none()

        if not user_role:
            logger.debug(
                "Role check failed - user lacks required role",
                user_id=str(current_user.id),
                required_roles=roles,
            )
            raise ApiError(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires role: {' or '.join(roles)}",
                error_code=ErrorCode.ROLE_REQUIRED,
            )

        # Check time-limited role hasn't expired
        if user_role.valid_until and user_role.valid_until < now:
            logger.debug(
                "Role check failed - role expired",
                user_id=str(current_user.id),
                role_id=str(user_role.role_id),
                valid_until=user_role.valid_until.isoformat(),
            )
            raise ApiError(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Role access has expired",
                error_code=ErrorCode.ROLE_EXPIRED,
            )

        logger.debug("Role check passed", user_id=str(current_user.id), required_roles=roles)
        return current_user

    return _check
