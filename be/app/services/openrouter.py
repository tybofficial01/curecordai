"""
OpenRouter API client.
Model is configured per use-case via env vars: AI_EXTRACTION_MODEL, AI_SUMMARY_MODEL, AI_CHAT_MODEL
All prompts live in prompts.py - do not inline prompt strings here.

Cost tracking: every request asks OpenRouter for usage accounting (`usage: {"include": true}`),
which returns exact per-request USD cost alongside token counts, and forwards it to
app.services.llm_cost_tracker.track_llm_usage() - a fire-and-forget call that never blocks or
risks the LLM call itself. Callers identify each request with a `feature` label (and, where
known, `user_id`/`family_member_id`) so cost can be broken down by call site and by patient.
"""
import json
import re
import time
import uuid
from typing import AsyncGenerator

import httpx
import structlog

from app.config import settings
from app.core.enums import Language
from app.services.llm_cost_tracker import track_llm_usage
from app.services.prompts import (
    analysis_system,
    ANALYSIS_USER,
    EXTRACTION_IMAGE_SYSTEM,
    EXTRACTION_IMAGE_USER,
    EXTRACTION_TEXT_SYSTEM,
    EXTRACTION_TEXT_USER,
    HEALTH_OVERVIEW_USER,
    SUMMARY_USER,
    ai_disclaimer,
    health_overview_system,
    summary_system,
)

logger = structlog.get_logger()

_HEADERS = {
    "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
    "HTTP-Referer": "https://curecordai.com",
    "X-Title": "CurecordAI",
    "Content-Type": "application/json",
}


def _strip_json_fences(content: str) -> str:
    """Strip markdown code fences that models sometimes wrap JSON in."""
    if "```json" in content:
        return content.split("```json")[1].split("```")[0].strip()
    if "```" in content:
        return content.split("```")[1].split("```")[0].strip()
    return content.strip()


_THINK_BLOCK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
_STRAY_THINK_TAG_RE = re.compile(r"</?think>", re.IGNORECASE)


def _strip_thinking(content: str) -> str:
    """
    Some reasoning models (e.g. Qwen3 family) inline their chain-of-thought into `content`
    as a <think>...</think> block instead of OpenRouter's separate `reasoning` field. Observed
    in practice to sometimes leave only a stray closing `</think>` behind (no matching open tag)
    when OpenRouter's own normalization partially strips it - so both the well-formed block and
    any leftover orphaned tag need removing before the text ever reaches the patient.
    """
    content = _THINK_BLOCK_RE.sub("", content)
    content = _STRAY_THINK_TAG_RE.sub("", content)
    return content.strip()


async def chat_completion(
    messages: list[dict],
    model: str,
    max_tokens: int = 1000,
    temperature: float = 0.2,
    feature: str = "unspecified",
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> dict:
    """Non-streaming completion. Returns the response dict with content + usage."""
    logger.debug("chat_completion started", model=model, message_count=len(messages), max_tokens=max_tokens)
    if not settings.OPENROUTER_API_KEY:
        logger.warning("OpenRouter API key not configured - returning stub response", model=model)
        return {
            "content": "[AI unavailable - OPENROUTER_API_KEY not configured]",
            "model": model,
            "prompt_tokens": 0,
            "completion_tokens": 0,
        }

    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "reasoning": {"enabled": False},
        "usage": {"include": True},
    }

    start = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                f"{settings.OPENROUTER_BASE_URL}/chat/completions",
                headers=_HEADERS,
                json=payload,
            )
            if resp.is_error:
                logger.error(
                    "OpenRouter API error",
                    status_code=resp.status_code,
                    model=model,
                    body=resp.text,
                )
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        track_llm_usage(
            feature=feature,
            model=model,
            user_id=user_id,
            family_member_id=family_member_id,
            status="error",
            error_message=str(exc),
            duration_ms=(time.perf_counter() - start) * 1000,
        )
        raise

    choice = data["choices"][0]["message"]
    usage = data.get("usage", {})
    duration_ms = round((time.perf_counter() - start) * 1000, 2)

    logger.info(
        "OpenRouter completion received",
        model=data.get("model", model),
        prompt_tokens=usage.get("prompt_tokens", 0),
        completion_tokens=usage.get("completion_tokens", 0),
        duration_ms=duration_ms,
    )

    track_llm_usage(
        feature=feature,
        model=data.get("model", model),
        prompt_tokens=usage.get("prompt_tokens", 0),
        completion_tokens=usage.get("completion_tokens", 0),
        total_tokens=usage.get("total_tokens"),
        cost_usd=usage.get("cost"),
        user_id=user_id,
        family_member_id=family_member_id,
        duration_ms=duration_ms,
        request_id=data.get("id"),
    )

    return {
        "content": _strip_thinking(choice["content"]),
        "model": data.get("model", model),
        "prompt_tokens": usage.get("prompt_tokens", 0),
        "completion_tokens": usage.get("completion_tokens", 0),
    }


async def chat_completion_with_tools(
    messages: list[dict],
    tools: list[dict],
    model: str,
    max_tokens: int = 1000,
    temperature: float = 0.2,
    feature: str = "unspecified",
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> dict:
    """
    Single-turn OpenAI-compatible function-calling. Returns the raw assistant message dict
    ({"role": "assistant", "content": str | None, "tool_calls": [...] | None}) - unlike
    chat_completion(), the caller needs to see whether the model chose to answer directly
    or invoke a tool, not just extracted text. Used by whatsapp_agent.py's bounded, single-turn
    tool-calling loop (never an autonomous multi-step agent - see project plan).
    """
    logger.debug("chat_completion_with_tools started", model=model, tool_count=len(tools))
    if not settings.OPENROUTER_API_KEY:
        logger.warning("OpenRouter API key not configured - returning stub response", model=model)
        return {"role": "assistant", "content": "[AI unavailable - OPENROUTER_API_KEY not configured]", "tool_calls": None}

    payload = {
        "model": model,
        "messages": messages,
        "tools": tools,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "reasoning": {"enabled": False},
        "usage": {"include": True},
    }

    start = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                f"{settings.OPENROUTER_BASE_URL}/chat/completions",
                headers=_HEADERS,
                json=payload,
            )
            if resp.is_error:
                logger.error("OpenRouter tool-call API error", status_code=resp.status_code, model=model, body=resp.text)
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        track_llm_usage(
            feature=feature, model=model, user_id=user_id, family_member_id=family_member_id,
            status="error", error_message=str(exc), duration_ms=(time.perf_counter() - start) * 1000,
        )
        raise

    message = data["choices"][0]["message"]
    usage = data.get("usage", {})
    duration_ms = round((time.perf_counter() - start) * 1000, 2)

    track_llm_usage(
        feature=feature,
        model=data.get("model", model),
        prompt_tokens=usage.get("prompt_tokens", 0),
        completion_tokens=usage.get("completion_tokens", 0),
        total_tokens=usage.get("total_tokens"),
        cost_usd=usage.get("cost"),
        user_id=user_id,
        family_member_id=family_member_id,
        duration_ms=duration_ms,
        request_id=data.get("id"),
    )

    if message.get("content"):
        message["content"] = _strip_thinking(message["content"])
    return message


async def chat_completion_stream(
    messages: list[dict],
    model: str,
    max_tokens: int = 200000,
    temperature: float = 0.3,
    feature: str = "unspecified",
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> AsyncGenerator[str, None]:
    """SSE streaming completion. Yields content chunks."""
    logger.debug("chat_completion_stream started", model=model, message_count=len(messages))
    if not settings.OPENROUTER_API_KEY:
        logger.warning("OpenRouter API key not configured - streaming stub response", model=model)
        yield "[AI unavailable - OPENROUTER_API_KEY not configured]"
        return

    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": True,
        "reasoning": {"enabled": False},
        "usage": {"include": True},
    }

    start = time.perf_counter()
    chunk_count = 0
    # Buffers raw tokens so a <think>...</think> block split across many small stream chunks
    # (see _strip_thinking) is still caught and never reaches the patient mid-stream.
    buffer = ""
    in_think = False
    _OPEN_MARGIN = len("<think>") - 1
    _CLOSE_MARGIN = len("</think>") - 1
    stream_usage: dict = {}
    response_model = model
    response_id: str | None = None
    stream_error: Exception | None = None

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST",
                f"{settings.OPENROUTER_BASE_URL}/chat/completions",
                headers=_HEADERS,
                json=payload,
            ) as resp:
                if resp.is_error:
                    logger.error("OpenRouter streaming API error", status_code=resp.status_code, model=model)
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    data_str = line[6:]
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue

                    response_model = data.get("model", response_model)
                    response_id = data.get("id", response_id)
                    # The final chunk of a usage-tracked stream carries `usage` with empty/no
                    # choices - capture it here before attempting to read delta content below.
                    if data.get("usage"):
                        stream_usage = data["usage"]

                    try:
                        delta = data["choices"][0].get("delta", {})
                        content = delta.get("content", "")
                    except (KeyError, IndexError):
                        continue
                    if not content:
                        continue

                    buffer += content
                    while True:
                        if not in_think:
                            open_idx = buffer.find("<think>")
                            stray_close_idx = buffer.find("</think>")
                            if open_idx == -1 and stray_close_idx == -1:
                                # Hold back a small tail in case a tag is split across chunks
                                safe_len = max(0, len(buffer) - _OPEN_MARGIN)
                                if safe_len:
                                    chunk_count += 1
                                    yield buffer[:safe_len]
                                    buffer = buffer[safe_len:]
                                break
                            if stray_close_idx != -1 and (open_idx == -1 or stray_close_idx < open_idx):
                                # Orphaned closing tag with no opener - surrounding text is real content
                                if stray_close_idx:
                                    chunk_count += 1
                                    yield buffer[:stray_close_idx]
                                buffer = buffer[stray_close_idx + len("</think>"):]
                                continue
                            if buffer[:open_idx]:
                                chunk_count += 1
                                yield buffer[:open_idx]
                            buffer = buffer[open_idx + len("<think>"):]
                            in_think = True
                            continue
                        else:
                            close_idx = buffer.find("</think>")
                            if close_idx == -1:
                                # Still inside reasoning - discard all but a safety tail
                                buffer = buffer[-_CLOSE_MARGIN:] if _CLOSE_MARGIN else ""
                                break
                            buffer = buffer[close_idx + len("</think>"):]
                            in_think = False
                            continue

                # Flush whatever's left in the buffer once the stream ends
                if buffer and not in_think:
                    chunk_count += 1
                    yield buffer
    except Exception as exc:
        stream_error = exc

    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    logger.info(
        "OpenRouter stream completed",
        model=response_model,
        chunk_count=chunk_count,
        duration_ms=duration_ms,
        error=str(stream_error) if stream_error else None,
    )

    track_llm_usage(
        feature=feature,
        model=response_model,
        prompt_tokens=stream_usage.get("prompt_tokens", 0),
        completion_tokens=stream_usage.get("completion_tokens", 0),
        total_tokens=stream_usage.get("total_tokens"),
        cost_usd=stream_usage.get("cost"),
        user_id=user_id,
        family_member_id=family_member_id,
        status="error" if stream_error else "success",
        error_message=str(stream_error) if stream_error else None,
        duration_ms=duration_ms,
        request_id=response_id,
    )

    if stream_error:
        raise stream_error


async def get_embeddings(
    texts: list[str],
    model: str | None = None,
    feature: str = "embedding",
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> list[list[float]]:
    """
    Batch-embed a list of texts via OpenRouter's OpenAI-compatible /embeddings endpoint.
    Returns a zero-vector per input when no API key is configured (dev/offline graceful degradation) -
    callers should treat these as "no embedding available" rather than a real vector.
    """
    model = model or settings.AI_EMBEDDING_MODEL
    if not settings.OPENROUTER_API_KEY:
        logger.warning("OpenRouter API key not configured - returning zero embeddings", count=len(texts))
        return [[0.0] * settings.AI_EMBEDDING_DIMENSIONS for _ in texts]

    payload = {
        "model": model,
        "input": texts,
        "dimensions": settings.AI_EMBEDDING_DIMENSIONS,
    }

    start = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{settings.OPENROUTER_BASE_URL}/embeddings",
                headers=_HEADERS,
                json=payload,
            )
            if resp.is_error:
                logger.error("OpenRouter embeddings API error", status_code=resp.status_code, body=resp.text)
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        track_llm_usage(
            feature=feature,
            model=model,
            user_id=user_id,
            family_member_id=family_member_id,
            status="error",
            error_message=str(exc),
            duration_ms=(time.perf_counter() - start) * 1000,
        )
        raise

    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    ordered = sorted(data["data"], key=lambda item: item["index"])
    usage = data.get("usage", {})
    logger.info(
        "OpenRouter embeddings generated",
        model=data.get("model", model),
        count=len(ordered),
        duration_ms=duration_ms,
    )

    track_llm_usage(
        feature=feature,
        model=data.get("model", model),
        prompt_tokens=usage.get("prompt_tokens", 0),
        completion_tokens=0,
        total_tokens=usage.get("total_tokens"),
        cost_usd=usage.get("cost"),
        user_id=user_id,
        family_member_id=family_member_id,
        duration_ms=duration_ms,
        request_id=data.get("id"),
    )

    return [item["embedding"] for item in ordered]


async def extract_from_image(
    image_bytes: bytes,
    mime_type: str,
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> dict:
    """
    Extract structured medical data from an image using Vision LLM.
    Encodes the image as base64 and sends it as a multimodal message.
    Returns the same structure as extract_medical_data().
    """
    import base64

    logger.debug("extract_from_image started", mime_type=mime_type, image_bytes=len(image_bytes))
    if not settings.OPENROUTER_API_KEY:
        logger.warning("OpenRouter API key not configured - skipping image extraction")
        return {
            "extracted": {},
            "model": settings.AI_EXTRACTION_MODEL,
            "prompt_tokens": 0,
            "completion_tokens": 0,
        }

    b64 = base64.standard_b64encode(image_bytes).decode("utf-8")
    data_url = f"data:{mime_type};base64,{b64}"

    messages = [
        {"role": "system", "content": EXTRACTION_IMAGE_SYSTEM},
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": data_url}},
                {"type": "text", "text": EXTRACTION_IMAGE_USER},
            ],
        },
    ]

    result = await chat_completion(
        messages=messages,
        model=settings.AI_EXTRACTION_MODEL,
        max_tokens=settings.AI_MAX_TOKENS_EXTRACTION,
        temperature=0.1,
        feature="extraction_image",
        user_id=user_id,
        family_member_id=family_member_id,
    )

    try:
        extracted = json.loads(_strip_json_fences(result["content"]))
    except (json.JSONDecodeError, IndexError):
        extracted = {}

    return {
        "extracted": extracted,
        "model": result["model"],
        "prompt_tokens": result["prompt_tokens"],
        "completion_tokens": result["completion_tokens"],
    }


async def extract_medical_data(
    document_text: str,
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> dict:
    """
    Extract structured medical data from document text.
    Returns JSON with conditions, medications, observations, allergies, encounters.
    """
    logger.debug("extract_medical_data started", document_chars=len(document_text))
    messages = [
        {"role": "system", "content": EXTRACTION_TEXT_SYSTEM},
        {"role": "user", "content": EXTRACTION_TEXT_USER.format(document_text=document_text[:8000])},
    ]

    result = await chat_completion(
        messages=messages,
        model=settings.AI_EXTRACTION_MODEL,
        max_tokens=settings.AI_MAX_TOKENS_EXTRACTION,
        temperature=0.1,
        feature="extraction_text",
        user_id=user_id,
        family_member_id=family_member_id,
    )

    try:
        extracted = json.loads(_strip_json_fences(result["content"]))
    except (json.JSONDecodeError, IndexError) as exc:
        logger.warning("Failed to parse extraction JSON from model output", error=str(exc))
        extracted = {}

    logger.info(
        "Medical data extraction completed",
        conditions=len(extracted.get("conditions", [])),
        medications=len(extracted.get("medications", [])),
        observations=len(extracted.get("observations", [])),
        allergies=len(extracted.get("allergies", [])),
        encounters=len(extracted.get("encounters", [])),
    )

    return {
        "extracted": extracted,
        "model": result["model"],
        "prompt_tokens": result["prompt_tokens"],
        "completion_tokens": result["completion_tokens"],
    }


async def analyze_observations(
    observations: list[dict],
    language: Language = Language.EN,
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> dict:
    """
    Analyze extracted observations and return a structured health assessment.
    Returns {"analysis": {overall_status, overall_explanation, parameters[]}, "model": str}
    Only processes observations with a numeric value; skips empty lists.
    Explanation text follows `language`; status keywords stay fixed English (see analysis_system).
    """
    numeric_obs = [o for o in observations if o.get("value") is not None]
    if not numeric_obs:
        logger.debug("analyze_observations skipped - no numeric observations")
        return {"analysis": None, "model": settings.AI_EXTRACTION_MODEL}

    logger.debug("analyze_observations started", numeric_obs_count=len(numeric_obs))

    obs_lines = "\n".join(
        f"- {o.get('name', 'Unknown')}: {o.get('value', 'N/A')} {o.get('unit', '')} "
        f"(Ref: {o.get('reference_range') or 'N/A'}, Interp: {o.get('interpretation') or 'N/A'})"
        for o in numeric_obs[:20]
    )

    messages = [
        {"role": "system", "content": analysis_system(language)},
        {"role": "user", "content": ANALYSIS_USER.format(observations_text=obs_lines)},
    ]

    result = await chat_completion(
        messages=messages,
        model=settings.AI_EXTRACTION_MODEL,
        max_tokens=2000,
        temperature=0.1,
        feature="observation_analysis",
        user_id=user_id,
        family_member_id=family_member_id,
    )

    try:
        analysis = json.loads(_strip_json_fences(result["content"]))
    except (json.JSONDecodeError, ValueError) as exc:
        logger.warning("Failed to parse observation analysis JSON from model output", error=str(exc))
        analysis = None

    logger.info(
        "Observation analysis completed",
        overall_status=(analysis or {}).get("overall_status") if analysis else None,
        parameter_count=len((analysis or {}).get("parameters", [])) if analysis else 0,
    )
    return {"analysis": analysis, "model": result["model"]}


async def summarize_document(
    document_text: str,
    record_type: str,
    language: Language = Language.EN,
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> dict:
    """Generate a plain-language summary of a medical document, in `language`."""
    logger.debug(
        "summarize_document started", record_type=record_type, document_chars=len(document_text), language=language.value
    )
    messages = [
        {"role": "system", "content": summary_system(language)},
        {"role": "user", "content": SUMMARY_USER.format(record_type=record_type, document_text=document_text[:6000])},
    ]

    result = await chat_completion(
        messages=messages,
        model=settings.AI_SUMMARY_MODEL,
        max_tokens=settings.AI_MAX_TOKENS_SUMMARY,
        temperature=0.3,
        feature="document_summary",
        user_id=user_id,
        family_member_id=family_member_id,
    )

    summary = result["content"]
    disclaimer = ai_disclaimer(language)
    # Safety net: append disclaimer if AI omitted it
    if disclaimer not in summary:
        logger.debug("AI summary missing disclaimer - appending safety net disclaimer")
        summary = f"{summary}\n\n{disclaimer}"

    logger.info("Document summary generated", record_type=record_type, summary_chars=len(summary))
    return {
        "summary": summary,
        "model": result["model"],
    }


async def summarize_health_overview(
    snapshot_text: str,
    language: Language = Language.EN,
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
) -> dict:
    """Generate a friendly, whole-person narrative from an aggregated clinical snapshot
    (active conditions/medications/allergies/recent labs across all of the patient's records),
    in `language`."""
    logger.debug("summarize_health_overview started", snapshot_chars=len(snapshot_text), language=language.value)
    messages = [
        {"role": "system", "content": health_overview_system(language)},
        {"role": "user", "content": HEALTH_OVERVIEW_USER.format(snapshot_text=snapshot_text[:6000])},
    ]

    result = await chat_completion(
        messages=messages,
        model=settings.AI_SUMMARY_MODEL,
        max_tokens=settings.AI_MAX_TOKENS_SUMMARY,
        temperature=0.3,
        feature="health_overview",
        user_id=user_id,
        family_member_id=family_member_id,
    )

    summary = result["content"]
    disclaimer = ai_disclaimer(language)
    if disclaimer not in summary:
        summary = f"{summary}\n\n{disclaimer}"

    logger.info("Health overview generated", summary_chars=len(summary))
    return {"summary": summary, "model": result["model"]}
