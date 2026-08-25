"""
Medical terminology standardization service.
Calls official APIs to verify and enrich AI-extracted clinical codes.
Best-effort: on timeout or API failure, returns None for code fields (graceful degradation).
"""
import asyncio
import time
from typing import Optional

import httpx
import structlog

from app.config import settings

logger = structlog.get_logger()

_TIMEOUT = httpx.Timeout(8.0, connect=4.0)

# ── ICD-11 token cache (in-process, per-worker) ───────────────────────────────
_icd11_token: Optional[str] = None
_icd11_token_expiry: float = 0.0


async def _get_icd11_token() -> Optional[str]:
    global _icd11_token, _icd11_token_expiry

    if not settings.ICD11_CLIENT_ID or not settings.ICD11_CLIENT_SECRET:
        return None

    now = time.monotonic()
    if _icd11_token and now < _icd11_token_expiry:
        logger.debug("ICD-11 token cache hit")
        return _icd11_token

    logger.debug("ICD-11 token cache miss - fetching new token")
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.post(
                "https://icdaccessmanagement.who.int/connect/token",
                data={
                    "client_id": settings.ICD11_CLIENT_ID,
                    "client_secret": settings.ICD11_CLIENT_SECRET,
                    "scope": "icdapi_access",
                    "grant_type": "client_credentials",
                },
            )
            resp.raise_for_status()
            data = resp.json()
            _icd11_token = data["access_token"]
            # Refresh 60 s before actual expiry
            _icd11_token_expiry = now + data.get("expires_in", 3600) - 60
            return _icd11_token
    except Exception as exc:
        logger.warning("ICD-11 token fetch failed", error=str(exc))
        return None


async def lookup_icd11(condition_name: str) -> tuple[Optional[str], Optional[str]]:
    """Returns (icd11_code, icd11_display) or (None, None) on failure."""
    if not condition_name:
        return None, None

    token = await _get_icd11_token()
    if not token:
        return None, None

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                "https://id.who.int/icd/release/11/2024-01/mms/search",
                params={
                    "q": condition_name,
                    "linearizationname": "mms",
                    "flatResults": "true",
                    "useFlexisearch": "false",
                },
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/json",
                    "Accept-Language": "en",
                    "API-Version": "v2",
                },
            )
            resp.raise_for_status()
            data = resp.json()
            entities = data.get("destinationEntities", [])
            if not entities:
                logger.debug("ICD-11 lookup - no match", name=condition_name)
                return None, None
            top = entities[0]
            code = top.get("theCode")
            title_obj = top.get("title", {})
            display = title_obj.get("@value") if isinstance(title_obj, dict) else str(title_obj)
            logger.debug("ICD-11 lookup matched", name=condition_name, code=code)
            return code, display
    except Exception as exc:
        logger.warning("ICD-11 lookup failed", name=condition_name, error=str(exc))
        return None, None


async def lookup_loinc(observation_name: str) -> tuple[Optional[str], Optional[str]]:
    """Returns (loinc_code, loinc_display) or (None, None) on failure.
    Uses NLM Clinical Tables LOINC search (free, no auth required).
    """
    if not observation_name:
        return None, None

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                "https://clinicaltables.nlm.nih.gov/api/loinc_items/v3/search",
                params={
                    "terms": observation_name,
                    "df": "LOINC_NUM,LONG_COMMON_NAME",
                    "maxList": "1",
                    "type": "question",
                },
            )
            resp.raise_for_status()
            # Response format: [total, [[code, display], ...], extra, [[code, display]]]
            result = resp.json()
            if not result or result[0] == 0:
                logger.debug("LOINC lookup - no match", name=observation_name)
                return None, None
            # result[3] has the display list when df is specified
            display_list = result[3] if len(result) > 3 else []
            if not display_list:
                logger.debug("LOINC lookup - no display list", name=observation_name)
                return None, None
            row = display_list[0]
            code = row[0]
            logger.debug("LOINC lookup matched", name=observation_name, code=code)
            return (row[0], row[1]) if len(row) > 1 else (row[0], None)
    except Exception as exc:
        logger.warning("LOINC lookup failed", name=observation_name, error=str(exc))
        return None, None


async def lookup_rxnorm_atc(medication_name: str) -> tuple[Optional[str], Optional[str]]:
    """Returns (atc_code, atc_display) or (None, None) on failure.
    Step 1 - RxNorm rxcui lookup.
    Step 2 - RxClass ATC mapping.
    Both APIs are free, no auth required.
    """
    if not medication_name:
        return None, None

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            # Step 1: Resolve RxCUI from medication name
            rxcui_resp = await client.get(
                "https://rxnav.nlm.nih.gov/REST/rxcui.json",
                params={"name": medication_name, "search": "1"},
            )
            rxcui_resp.raise_for_status()
            rxcui_list = rxcui_resp.json().get("idGroup", {}).get("rxnormId", [])
            if not rxcui_list:
                logger.debug("RxNorm lookup - no rxcui match", name=medication_name)
                return None, None
            rxcui = rxcui_list[0]

            # Step 2: Map RxCUI to ATC class
            atc_resp = await client.get(
                "https://rxnav.nlm.nih.gov/REST/rxclass/class/byRxcui.json",
                params={"rxcui": rxcui, "relaSource": "ATC"},
            )
            atc_resp.raise_for_status()
            drug_info_list = (
                atc_resp.json()
                .get("rxclassDrugInfoList", {})
                .get("rxclassDrugInfo", [])
            )
            if not drug_info_list:
                logger.debug("RxClass lookup - no ATC class match", name=medication_name, rxcui=rxcui)
                return None, None

            # Pick the most specific (longest ATC code = deepest hierarchy level)
            best = max(
                drug_info_list,
                key=lambda x: len(x.get("rxclassMinConceptItem", {}).get("classId", "")),
            )
            concept = best.get("rxclassMinConceptItem", {})
            logger.debug("RxNorm/ATC lookup matched", name=medication_name, atc_code=concept.get("classId"))
            return concept.get("classId"), concept.get("className")

    except Exception as exc:
        logger.warning("RxNorm/ATC lookup failed", name=medication_name, error=str(exc))
        return None, None


async def lookup_snomed(substance_name: str) -> tuple[Optional[str], Optional[str]]:
    """Returns (snomed_code, snomed_display) or (None, None) on failure.
    Uses SNOMED International public browser API (free, no auth required for read).
    """
    if not substance_name:
        return None, None

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                "https://browser.ihtsdotools.org/snowstorm/snomed-ct/browser/MAIN/descriptions",
                params={
                    "term": substance_name,
                    "conceptActive": "true",
                    "limit": "3",
                    "language": "en",
                },
                headers={"Accept": "application/json"},
            )
            resp.raise_for_status()
            items = resp.json().get("items", [])
            if not items:
                logger.debug("SNOMED lookup - no match", name=substance_name)
                return None, None
            top = items[0]
            concept = top.get("concept", {})
            concept_id = concept.get("conceptId")
            fsn = concept.get("fsn", {})
            display = fsn.get("term") if isinstance(fsn, dict) else top.get("term")
            logger.debug("SNOMED lookup matched", name=substance_name, concept_id=concept_id)
            return concept_id, display

    except Exception as exc:
        logger.warning("SNOMED lookup failed", name=substance_name, error=str(exc))
        return None, None


_MAX_ENTITIES_PER_CATEGORY = 50


async def standardize_extracted(extracted: dict) -> dict:
    """
    Enrich AI-extracted entities with verified codes from official terminology APIs.
    All lookups run concurrently per category.
    Gracefully degrades - never raises; missing codes remain None.
    """
    # Capped before the concurrent fan-out below, not just at persist time - a document that
    # makes the extraction model hallucinate hundreds of entities would otherwise still fire
    # hundreds of concurrent outbound calls to ICD-11/RxNorm/LOINC/SNOMED per request.
    conditions = extracted.get("conditions", [])[:_MAX_ENTITIES_PER_CATEGORY]
    medications = extracted.get("medications", [])[:_MAX_ENTITIES_PER_CATEGORY]
    observations = extracted.get("observations", [])[:_MAX_ENTITIES_PER_CATEGORY]
    allergies = extracted.get("allergies", [])[:_MAX_ENTITIES_PER_CATEGORY]

    logger.debug(
        "standardize_extracted started",
        conditions=len(conditions),
        medications=len(medications),
        observations=len(observations),
        allergies=len(allergies),
    )

    # Run all four categories concurrently
    cond_results, med_results, obs_results, allergy_results = await asyncio.gather(
        asyncio.gather(
            *[lookup_icd11(c.get("name", "")) for c in conditions],
            return_exceptions=True,
        ),
        asyncio.gather(
            *[lookup_rxnorm_atc(m.get("name", "")) for m in medications],
            return_exceptions=True,
        ),
        asyncio.gather(
            *[lookup_loinc(o.get("name", "")) for o in observations],
            return_exceptions=True,
        ),
        asyncio.gather(
            *[lookup_snomed(a.get("substance", "")) for a in allergies],
            return_exceptions=True,
        ),
    )

    for i, result in enumerate(cond_results):
        if isinstance(result, tuple) and result[0]:
            conditions[i]["icd11_code"] = result[0]
            conditions[i]["icd11_display"] = result[1]

    for i, result in enumerate(med_results):
        if isinstance(result, tuple) and result[0]:
            medications[i]["atc_code"] = result[0]
            medications[i]["atc_display"] = result[1]

    for i, result in enumerate(obs_results):
        if isinstance(result, tuple) and result[0]:
            observations[i]["loinc_code"] = result[0]
            observations[i]["loinc_display"] = result[1]

    for i, result in enumerate(allergy_results):
        if isinstance(result, tuple) and result[0]:
            allergies[i]["snomed_code"] = result[0]
            allergies[i]["snomed_display"] = result[1]

    logger.info(
        "standardize_extracted completed",
        conditions_coded=sum(1 for c in conditions if c.get("icd11_code")),
        medications_coded=sum(1 for m in medications if m.get("atc_code")),
        observations_coded=sum(1 for o in observations if o.get("loinc_code")),
        allergies_coded=sum(1 for a in allergies if a.get("snomed_code")),
    )
    return extracted
