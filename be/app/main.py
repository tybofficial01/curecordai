import asyncio
import uuid
from contextlib import asynccontextmanager
import time

import structlog
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.v1.router import api_router
from app.config import settings
from app.core.errors import ApiError, api_error_handler
from app.core.rate_limit import limiter
from app.database import engine
from app.core.logging import configure_logging
from app.middleware.audit import audit_middleware
from app.tasks.medication_reminder_worker import run_medication_reminder_worker
from app.tasks.whatsapp_reconciliation_worker import run_whatsapp_reconciliation_worker

# Upload bytes never transit this API (S3 direct-PUT via presigned URL) - this only bounds
# ordinary JSON/form request bodies. ponytail: Content-Length header check only, doesn't
# catch a chunked-encoding request lying about its length; a reverse proxy (see
# SECURITY_AUDIT.md H5) should enforce this more strictly once one is deployed.
_MAX_JSON_BODY_BYTES = 2 * 1024 * 1024

configure_logging(
    log_level=settings.LOG_LEVEL,
    log_dir=settings.LOG_DIR,
    log_file_name=settings.LOG_FILE_NAME,
    max_bytes=settings.LOG_MAX_BYTES,
    backup_count=settings.LOG_BACKUP_COUNT,
    pretty_console=not settings.is_production,
)

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting CurecordAI API", version=settings.APP_VERSION, env=settings.APP_ENV)
    stop_event = asyncio.Event()
    worker_task = asyncio.create_task(run_medication_reminder_worker(stop_event))
    wa_reconciliation_task = asyncio.create_task(run_whatsapp_reconciliation_worker(stop_event))
    yield
    stop_event.set()
    await worker_task
    await wa_reconciliation_task
    await engine.dispose()
    logger.info("CurecordAI API shut down")


app = FastAPI(
    title="CurecordAI API",
    version=settings.APP_VERSION,
    description="Production-grade personal health record platform API",
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
    lifespan=lifespan,
)

# ── Rate limiting ─────────────────────────────────────────────────
# default_limits (set on the shared `limiter` in core/rate_limit.py) give every route a floor;
# routes with their own @limiter.limit(...) decorator use that tighter limit instead.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
# ApiError is an HTTPException subclass; Starlette resolves handlers by MRO, so this one
# wins for ApiError while every plain HTTPException keeps FastAPI's default handler.
app.add_exception_handler(ApiError, api_error_handler)
app.add_middleware(SlowAPIMiddleware)


# ── Request body size cap (protects JSON/form endpoints - uploads bypass the API) ──
@app.middleware("http")
async def body_size_limit_middleware(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > _MAX_JSON_BODY_BYTES:
        return JSONResponse(status_code=413, content={"detail": "Request body too large"})
    return await call_next(request)


# ── CORS ──────────────────────────────────────────────────────────
_cors_kwargs: dict = dict(
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID", "X-Device-Type"],
    expose_headers=["X-Request-ID"],
)
if settings.APP_ENV == "development":
    # Flutter dev server uses a random port every run - match any localhost port
    _cors_kwargs["allow_origin_regex"] = r"http://localhost(:\d+)?"
else:
    _cors_kwargs["allow_origins"] = settings.allowed_origins

app.add_middleware(CORSMiddleware, **_cors_kwargs)


# ── Audit middleware (HIPAA §164.312(b)) - must be innermost so request.state is set ──
app.middleware("http")(audit_middleware)


# ── Request ID middleware ─────────────────────────────────────────
@app.middleware("http")
async def request_observability_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
    request.state.request_id = request_id
    start_time = time.perf_counter()

    try:
        response = await call_next(request)
    except Exception:
        logger.exception(
            "HTTP request failed",
            request_id=request_id,
            method=request.method,
            path=request.url.path,
            client_ip=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
        )
        raise

    duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
    user_id = getattr(request.state, "user_id", None)
    logger.info(
        "HTTP request completed",
        request_id=request_id,
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_ms=duration_ms,
        client_ip=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
        user_id=str(user_id) if user_id else None,
        user_role=getattr(request.state, "user_role", None),
    )
    response.headers["X-Request-ID"] = request_id
    return response


# ── Security headers - outermost middleware, applied to every response including
# rejections from the layers above (rate limit, body size, CORS) ──────────────────
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
    # style-src allows the inline <style> block in the doctor-view template (sharing.py);
    # frame-ancestors is the modern equivalent of X-Frame-Options and covers the actual
    # clickjacking concern on that PHI-bearing public page.
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'"
    )
    return response


# ── Global exception handler ──────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception", path=request.url.path, error=str(exc), exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "An internal error occurred. Please try again later."},
    )


# ── Routes ───────────────────────────────────────────────────────
app.include_router(api_router, prefix="/api/v1")


@app.get("/health", tags=["health"])
@limiter.exempt
async def health_check():
    return {"status": "healthy", "version": settings.APP_VERSION}
