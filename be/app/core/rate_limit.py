"""
Single shared Limiter for the whole app (see SECURITY_AUDIT.md H1/M4).
default_limits gives every route a floor once SlowAPIMiddleware is registered in main.py;
routes with their own @limiter.limit(...) decorator use that tighter limit instead - slowapi
exempts decorated routes from the middleware-level default automatically, no double-counting.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import settings

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.RATE_LIMIT_API_PER_MINUTE}/minute"],
    # ponytail: "memory://" is per-process - effective limits multiply with instance count
    # under horizontal scaling. Set REDIS_URL once deployed with more than one app process.
    storage_uri=settings.REDIS_URL or "memory://",
    # A storage outage should degrade rate limiting, not take the API down with it.
    swallow_errors=True,
)
