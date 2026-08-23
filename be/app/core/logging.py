import functools
import inspect
import logging
import sys
import time
from logging.handlers import RotatingFileHandler
from pathlib import Path

import structlog


def configure_logging(
    log_level: str,
    log_dir: str,
    log_file_name: str,
    max_bytes: int,
    backup_count: int,
    pretty_console: bool = False,
) -> None:
    """
    Configure structlog + stdlib logging.

    In development (`pretty_console=True`) the console gets a human-readable,
    colored renderer so a developer can follow request/pipeline flow live in the
    terminal. The log file always gets newline-delimited JSON so it stays greppable
    and toolable. Both sinks share the same processor chain, so every log line -
    HTTP request, DB call, background task step, AI call, etc. - carries the same
    structured fields (timestamp, level, logger name, event, and any bound context).
    """
    log_path = Path(log_dir)
    log_path.mkdir(parents=True, exist_ok=True)

    # Windows consoles default to a legacy codepage (e.g. cp1252), which mangles
    # the non-ASCII characters (em dashes, arrows) used throughout our log messages.
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except (ValueError, OSError):
            pass

    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    console_renderer = (
        structlog.dev.ConsoleRenderer(colors=True)
        if pretty_console
        else structlog.processors.JSONRenderer(sort_keys=True)
    )
    console_formatter = structlog.stdlib.ProcessorFormatter(
        processor=console_renderer,
        foreign_pre_chain=shared_processors,
    )
    file_formatter = structlog.stdlib.ProcessorFormatter(
        processor=structlog.processors.JSONRenderer(sort_keys=True),
        foreign_pre_chain=shared_processors,
    )

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.setLevel(log_level.upper())

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(console_formatter)
    root_logger.addHandler(console_handler)

    file_handler = RotatingFileHandler(
        log_path / log_file_name,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8",
    )
    file_handler.setFormatter(file_formatter)
    root_logger.addHandler(file_handler)

    structlog.configure(
        processors=shared_processors + [structlog.stdlib.ProcessorFormatter.wrap_for_formatter],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )


def log_call(_func=None, *, level: str = "debug", include_args: tuple[str, ...] = ()):
    """
    Trace a function's execution for local dev/debugging: logs when it starts,
    when it completes (with duration_ms), and - at ERROR level - when it raises.

    Only argument names explicitly listed in `include_args` are logged (as an
    allowlist), so this is safe to drop onto functions that handle passwords,
    tokens, OTPs, or PHI without risking leaking sensitive values into logs.

    Usage:
        @log_call
        async def do_thing(x): ...

        @log_call(include_args=("record_id",), level="info")
        async def process_record(record_id: str): ...
    """

    def decorator(func):
        func_logger = structlog.get_logger(func.__module__)
        qualname = func.__qualname__

        def _safe_context(args, kwargs) -> dict:
            if not include_args:
                return {}
            try:
                bound = inspect.signature(func).bind_partial(*args, **kwargs)
                bound.apply_defaults()
                return {
                    name: bound.arguments[name]
                    for name in include_args
                    if name in bound.arguments
                }
            except TypeError:
                return {}

        if inspect.iscoroutinefunction(func):

            @functools.wraps(func)
            async def async_wrapper(*args, **kwargs):
                ctx = _safe_context(args, kwargs)
                getattr(func_logger, level)(f"{qualname} started", **ctx)
                start = time.perf_counter()
                try:
                    result = await func(*args, **kwargs)
                except Exception as exc:
                    func_logger.error(
                        f"{qualname} failed",
                        duration_ms=round((time.perf_counter() - start) * 1000, 2),
                        error=str(exc),
                        exc_info=True,
                    )
                    raise
                getattr(func_logger, level)(
                    f"{qualname} completed",
                    duration_ms=round((time.perf_counter() - start) * 1000, 2),
                )
                return result

            return async_wrapper

        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            ctx = _safe_context(args, kwargs)
            getattr(func_logger, level)(f"{qualname} started", **ctx)
            start = time.perf_counter()
            try:
                result = func(*args, **kwargs)
            except Exception as exc:
                func_logger.error(
                    f"{qualname} failed",
                    duration_ms=round((time.perf_counter() - start) * 1000, 2),
                    error=str(exc),
                    exc_info=True,
                )
                raise
            getattr(func_logger, level)(
                f"{qualname} completed",
                duration_ms=round((time.perf_counter() - start) * 1000, 2),
            )
            return result

        return sync_wrapper

    if _func is not None:
        return decorator(_func)
    return decorator
