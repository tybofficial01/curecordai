# CureCordAI Backend - Security Audit Report

**Scope:** `be/` - all API routes, middleware, services, models, config, and infra files (~70 files).
**Date:** 2026-08-08 · **Method:** Manual file-by-file review (5 parallel focus areas: auth core, API routes/IDOR, middleware/infra, services/integrations, models/dependencies) + direct verification of conflicting findings.
**Status:** Read-only audit. No code changed.

## Executive summary

The authorization model is the strongest part of this codebase: every non-public endpoint requires auth, and read/update/delete paths consistently scope queries to `user_id == current_user.id` (+ `family_scope`). **No cross-tenant IDOR or RAG data-leakage was found** - that's the highest-value healthcare-data risk and it's handled correctly.

The weak spot is **flood/DoS protection**, which is exactly what was flagged as top priority: rate limiting exists only on a handful of explicitly-decorated routes (auth, AI chat, contact form). The vast majority of PHI endpoints (records, clinical data, family, alerts, consent, emergency, sharing) have **no rate limiting, no request body size cap, and run behind a bare uvicorn process with no reverse proxy or timeout hardening**. None of the fixes below require sacrificing throughput - they're bounded, O(1)-per-request checks (a shared Redis-backed limiter, a body-size guard, uvicorn/proxy timeout flags), which is the standard way to keep a system both safe and fast under load.

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 9 |
| Medium | 12 |
| Low | 10 |
| Info (no action needed) | - |

---

## High severity

### H1. No global/default rate limiting - most PHI endpoints are completely unthrottled
**Files:** `app/main.py:30,51-52`, contrast with `app/api/v1/auth.py`, `ai_chat.py`, `contact.py`
`Limiter(key_func=get_remote_address)` is created and registered as the exception handler, but `SlowAPIMiddleware` is never added via `app.add_middleware(...)`, and `Limiter()` has no `default_limits`. Verified directly against `main.py` - only routes carrying an explicit `@limiter.limit(...)` decorator are throttled (auth.py, ai_chat.py streaming, contact.py). Every list/read/write endpoint in `records.py`, `clinical.py`, `family.py`, `alerts.py`, `consent.py`, `emergency.py`, `insights.py`, and most of `sharing.py` has **zero rate limiting**.
**Impact:** scraping, resource-exhaustion DoS, and amplified brute-force against any unthrottled endpoint.
**Fix (scalable):** `Limiter(key_func=get_remote_address, default_limits=[f"{settings.RATE_LIMIT_API_PER_MINUTE}/minute"])` + `app.add_middleware(SlowAPIMiddleware)` gives every route a floor with no added latency for compliant traffic; keep the tighter per-route decorators where they already exist.

### H2. No request body size limit - unbounded JSON payload DoS
**File:** `app/main.py` (absent), confirmed no `GZipMiddleware`/content-length guard anywhere
File uploads are safe (S3 direct-PUT via presigned URL - bytes never transit the API), but any JSON POST (chat messages, notes, etc.) is fully buffered and parsed before Pydantic validation runs, with no cap. A handful of concurrent multi-hundred-MB POSTs can exhaust worker memory.
**Fix (scalable):** one small ASGI middleware rejecting requests where `Content-Length` exceeds ~1–2 MB for JSON routes. O(1) per request, no throughput cost.

### H3. Upload size/type checks are client-declared only - presigned PUT has no server-side cap
**Files:** `app/api/v1/records.py:140-190`, `app/services/s3_service.py:41-67`
`init_upload` validates `file_mime_type`/`file_size_bytes` against config, but these are **client-supplied metadata**. The actual `generate_presigned_url("put_object", ...)` carries no `content-length-range` condition, so a client can declare a small size and then PUT an arbitrarily large object to the same URL - fully bypassing `MAX_FILE_SIZE_MB`.
**Fix (implemented):** switched `init_upload` to S3 **presigned POST** (`content-length-range` + exact-match `Content-Type` policy conditions) instead of presigned PUT - S3 itself now rejects an oversized/wrong-type upload before it ever lands, enforced server-side by AWS, not by the app. (An earlier iteration of this fix added a `HeadObject` check in `confirm_upload` as a post-hoc backstop; that was removed once presigned POST shipped - it added a real S3 network round-trip to every upload confirmation for a check that had become redundant, since S3's policy enforcement is strictly earlier and stronger.) Web (`web/lib/api/records.ts`) and mobile (`fe/.../upload_screen.dart`) upload flows were both updated to POST multipart form data instead of a raw PUT body.

### H4. Expensive LLM endpoint has no rate limiting
**File:** `app/api/v1/insights.py:201-268` (`health_overview`)
Triggers an LLM call on every hit with no `@limiter.limit(...)`, unlike `ai_chat.py` (30/min) and `contact.py` (5/hour). An authenticated user can hammer this to drive up LLM API cost.
**Fix:** add a rate limit consistent with `ai_chat.py`'s pattern (e.g. 10/min); consider short-TTL caching since underlying clinical data changes infrequently.

### H5. Uvicorn exposed directly with no reverse proxy or slow-loris hardening
**Files:** `Dockerfile:26`, `docker-compose.yml:31-32,43`
`uvicorn app.main:app --host 0.0.0.0 --port 8000` - no `--timeout-keep-alive`, `--limit-concurrency`, `--limit-max-requests`, `--workers`, or `--proxy-headers`. Port 8000 maps straight to the host; no nginx/traefik/ALB config found anywhere in the repo.
**Fix (scalable):** put a reverse proxy in front for TLS termination, connection timeouts, and slow-loris buffering; set `--timeout-keep-alive 5` and size `--workers` to CPU count for prod. This is the standard prod topology and *improves* effective throughput (connection reuse, proxy buffering) rather than costing it.

### H6. No security headers set anywhere
**File:** `app/middleware/__init__.py` (empty), `app/main.py`
No `Strict-Transport-Security`, `Content-Security-Policy`, `X-Frame-Options`, or `X-Content-Type-Options` on any response. The doctor-facing public share view (`DOCTOR_VIEW_BASE_URL`) is renderable in an iframe with no `X-Frame-Options`/CSP - clickjacking risk on a page that displays PHI.
**Fix:** one `@app.middleware("http")` function setting the four headers on every response - a few dict writes, no measurable latency cost.

### H7. `APP_DEBUG=true` ships as the default; nothing enforces it off in production, and it drives SQL echo
**Files:** `.env:6`, `.env.example:6`, `app/config.py`, `app/database.py:13`
`create_async_engine(..., echo=settings.APP_DEBUG)` - if `APP_DEBUG` is ever left `true` in a deployed environment (e.g. a prod deploy that copies `.env.example` verbatim), **every SQL statement including bound parameter values (PHI) is echoed to stdout/logs**. `APP_DEBUG` and `APP_ENV` are independent, uncoupled flags - nothing fails fast on the dangerous combination.
**Fix:** add a `pydantic` `model_validator` on `Settings` that raises at startup if `APP_ENV == "production" and APP_DEBUG`. Startup-only check, zero runtime cost. Also flip `.env.example`'s default to `false`.

### H8. `python-jose` is unmaintained and carries known risk classes for JWT verification
**File:** `requirements.txt:18` (`python-jose[cryptography]==3.3.0`)
No release since 3.3.0 (2021). This library's version history includes an algorithm-confusion issue and a JWE decompression-bomb DoS class; regardless of exact CVE numbers (verify against NVD/OSV before citing one), using an unmaintained library for auth-token verification is itself the risk. Note: the app's own usage is currently safe (`algorithms=[settings.JWT_ALGORITHM]` is explicitly pinned, see L7) - this is a supply-chain/maintenance risk, not an active exploit in this codebase today.
**Fix:** migrate to `PyJWT` or `authlib` (both actively maintained, both used in FastAPI's own docs). Contained change - only `app/core/security.py` and `app/services/auth_service.py`'s Apple-JWT verification touch this library.

### H9. No account-level brute-force lockout on password login
**Files:** `app/services/auth_service.py:524-553`, `app/api/v1/auth.py:193-209`
Protection is IP-only (`@limiter.limit("10/minute")`, and only effective once H1's shared/Redis-backed limiter is in place - see M4). There is no per-account failed-attempt counter analogous to `UserOtpRequest.attempt_count`, so an attacker distributing requests across source IPs can brute-force one specific account indefinitely.
**Fix:** add a failed-login counter on `User` (or a dedicated table) with backoff/lockout after N failures, independent of source IP - same pattern already used for OTPs.

---

## Medium severity

### M1. `family_member_id` accepted on create without ownership validation
**Files:** `clinical.py` (all 5 `create_*`), `records.py:161-179`, `emergency.py:112-126`, `sharing.py:153-169`, `ai_chat.py:98-106`
None of these verify `body.family_member_id` belongs to `current_user`, unlike `family.py`'s `_get_member_or_404` (used correctly elsewhere). Doesn't leak data on read (reads still filter by `user_id`), but lets a client create rows keyed to an arbitrary/foreign `family_member_id` - data-integrity gap, inconsistent with the codebase's own scoping invariant.
**Fix:** one shared `_validate_family_member_ownership()` helper, called wherever `family_member_id` is accepted from the client.

### M2. No upper bound on list `limit` query params
**Files:** `records.py:108`, `clinical.py:272,346`, `ai_chat.py:87,110`, `alerts.py:41`
All are plain `int` with a default but no max (`Query(le=...)` missing). `?limit=5000000` forces a large unbounded result set and heavy DB scan.
**Fix:** `limit: int = Query(50, le=200)` on every list endpoint - trivial, no throughput cost, prevents accidental or malicious huge scans.

### M3. Doctor QR public view & session creation are unrate-limited
**Files:** `sharing.py:226-408` (`doctor_view`), `sharing.py:152-187` (`create_share_session`)
Design itself is sound (SHA-256 token hash, 48-byte token, expiry + status checks, no full-record data ever rendered) - but neither endpoint uses the app's limiter. `doctor_view` runs a DB read + scan-tracking write on every hit with no throttle; `create_share_session` lets a user mint unlimited QR sessions.
**Fix:** `@limiter.limit("20/minute")` on `doctor_view` (IP-keyed), a per-user limit (e.g. `10/hour`) on `create_share_session`.

### M4. Rate limiter uses per-process in-memory storage
**Files:** `app/main.py:30`, `app/api/v1/auth.py:33`
No `storage_uri` (no Redis) - in any multi-worker/multi-pod deployment each process has independent counters, so effective limits scale up with instance count, weakening every rate-limit-based protection above (H1, H4, H9, M3). Also: two separately-instantiated `Limiter()` objects (main.py and auth.py) - works today but is confusing config debt.
**Fix:** point `storage_uri` at Redis in production (`slowapi`/`limits` supports this natively - no custom code needed) and consolidate to one shared `Limiter` instance/module. This is the change that makes H1/H9's fixes actually hold under horizontal scaling.

### M5. Audit log immutability is convention-only, not DB-enforced
**File:** `app/models/audit.py:12-13`
Docstring says "IMMUTABLE. Never UPDATE or DELETE," but nothing in the DB (no revoked grants, no trigger) actually prevents it, and `hash_chain_value` is nullable so chaining isn't mandatory. For a HIPAA §164.312(b) audit trail, a compromised app-layer credential could tamper with history.
**Fix:** `REVOKE UPDATE, DELETE` on the audit role + a `BEFORE UPDATE/DELETE` trigger that raises; make `hash_chain_value` non-nullable.

### M6. PHI text/JSON columns rely entirely on disk-level encryption
**File:** `app/models/records.py` - `MedicalRecord.extracted_text`, `ai_summary`, `ai_analysis` (JSONB), `RecordChunk.chunk_text`
Full extracted clinical text and AI-derived summaries are plain columns with no application-layer encryption. A DB dump, misconfigured read replica, or compromised read-only credential exposes plaintext PHI with no defense-in-depth.
**Fix:** confirm RDS/Postgres at-rest encryption + encrypted backups are enabled infra-side at minimum; consider field-level encryption (matching the pattern already used for `IntegrationToken.access_token_encrypted`) for these specific columns given their sensitivity.

### M7. DB connection pool has no statement/command timeout
**File:** `app/database.py:8-15`
`pool_size`/`max_overflow` are correctly bounded (good - prevents unbounded connection growth), but no `statement_timeout` is set. A single slow/runaway query can hold a connection indefinitely; with a bounded pool, a handful of stuck queries exhausts it for everyone.
**Fix:** `connect_args={"server_settings": {"statement_timeout": "60000"}}` (asyncpg supports this). One line, no throughput cost, directly protects scalability under load.

### M8. Timing side-channel on `/auth/login/email` enables account enumeration
**File:** `app/services/auth_service.py:534-543`
Unknown email returns 401 immediately (no bcrypt call); known email + wrong password falls through to `verify_password` (~100-200ms). The delay difference leaks which emails are registered - inconsistent with `send_password_reset_otp`, which was deliberately written to avoid exactly this.
**Fix:** run a dummy bcrypt compare on the not-found path so timing is uniform.

### M9. Refresh-token reuse doesn't trigger session-wide revocation
**File:** `app/services/auth_service.py:787-832`
Rotation itself is correct, but presenting an already-rotated/revoked refresh token just 401s - it doesn't revoke the rest of that user's sessions. No automatic signal/response to a stolen-token replay race.
**Fix:** when a lookup finds a session already inactive due to `token_rotation`, revoke all sessions for that `user_id` and log to `SecurityIncident` (model already exists for this).

### M10. Forgeable `X-Forwarded-For` recorded into the audit/security trail
**File:** `app/api/v1/auth.py:36-40` (`_client_ip`)
Trusts the client-supplied header with no trusted-proxy allowlist, and this value is persisted into `UserOtpRequest.ip_address`/`UserSession.ip_address` for forensics. (The actual rate-limit key, `get_remote_address`, is unaffected - it reads the raw connection, not this header.)
**Fix:** only trust `X-Forwarded-For` behind a configured reverse proxy (ties into H5) via `ProxyHeadersMiddleware` with a `trusted_hosts` allowlist; otherwise fall back to `request.client.host`.

### M11. `terminology.py` fans out one HTTP call per extracted clinical entity, uncapped before the fan-out
**File:** `app/services/terminology.py:248-265`
`standardize_extracted` runs `asyncio.gather` over every extracted condition/med/observation/allergy with no length cap before the gather. `process_record.py` caps *persisted* conditions at `[:20]`, but that cap is applied after this fan-out already fired - a document that causes the extraction LLM to hallucinate hundreds of entities triggers hundreds of concurrent outbound calls to ICD-11/RxNorm/etc.
**Fix:** slice each list to `[:50]` before the `asyncio.gather` call, matching a `[:50]` persistence cap now applied to all five `_persist_*` functions in `process_record.py` (previously only `conditions` was capped, at `[:20]`; medications/observations/allergies/encounters persisted unbounded).

### M12. `docker-compose.yml` hardcodes a weak Postgres password and exposes it to the host
**File:** `docker-compose.yml:11,14,36`
`POSTGRES_PASSWORD: password`, and port 5432 published to the host. Dev-only by design, but if this compose file is ever reused for a reachable staging environment it's an open, weakly-credentialed DB.
**Fix:** don't publish 5432 to the host at all (the `api` service reaches it over the Docker network regardless) - removes the exposure with no functional loss except local `psql` debugging convenience.

---

## Low severity

### L1. S3 object keys not sanitized against embedded path/control characters
**Files:** `app/services/s3_service.py:34-39`, used from `records.py:161-162`
Only `" " → "_"` is applied; `../`, embedded `/`, and control characters pass through. Not currently exploitable for cross-user traversal (two random UUID segments precede the filename), but allows S3-key smuggling and an unsanitized filename may reflect into UI/API responses.
**Fix:** `re.sub(r'[^\w.\-]', '_', filename)[:255]` before use.

### L2. `folder_id` not ownership-checked on record update
**File:** `records.py:230-243`
No cross-tenant leak results (listing stays scoped by `user_id`), but a record can end up pointing at a nonexistent or foreign `folder_id`.
**Fix:** validate via the same lookup pattern already used in `update_folder`.

### L3. Apple Sign-In doesn't validate the `iss` claim
**File:** `app/services/auth_service.py:721-726`
`jwt.decode(..., audience=settings.APPLE_CLIENT_ID)` checks signature + `aud` but never asserts `iss == "https://appleid.apple.com"`. Low practical risk since keys are fetched live from Apple's own JWKS, but a foot-gun if generalized to more OIDC issuers later.
**Fix:** pass `issuer="https://appleid.apple.com"` to `jwt.decode`.

### L4. `JWT_ALGORITHM` is config-driven rather than hardcoded
**File:** `app/config.py:40`, used in `core/security.py`
Correctly prevents attacker-controlled-`alg` confusion today, but if an operator ever sets `JWT_ALGORITHM=HS256` while `jwt_public_key` (non-secret PEM) is still supplied as the verification key, tokens become forgeable by anyone holding the public key.
**Fix:** hardcode `"RS256"` in code instead of trusting the env var.

### L5. Integration tokens' "encrypted" naming isn't structurally enforced
**File:** `app/models/integrations.py:63-64`
`access_token_encrypted`/`refresh_token_encrypted` are plain `Text` columns - encryption is presumably applied at the service layer by convention, but nothing prevents a future write path from storing a raw token.
**Fix:** wrap writes in a SQLAlchemy `TypeDecorator` so encryption is structural, not convention-based.

### L6. Key files and Apple JWKS re-fetched on every request (secondary DoS/perf)
**Files:** `app/config.py:42-48` (`jwt_private_key`/`jwt_public_key` properties - blocking disk read per token op), `app/services/auth_service.py:694-697` (Apple JWKS fetched fresh every call, no caching)
**Fix:** `functools.cached_property` for the key files (load once at startup); cache Apple's JWKS with its stated rotation interval.

### L7. `alembic.ini` has a stale hardcoded local dev credential (currently inert)
**File:** `alembic.ini:5`
`alembic/env.py` unconditionally overrides this via `settings.DATABASE_URL`, so it's dead as long as that override stays in place. Worth removing for hygiene.

### L8. Dependency hygiene - parsing libraries for untrusted files, verify current patch levels
**Files:** `requirements.txt` - `cryptography==44.0.0` (verify against 44.0.1+ patch, OpenSSL-related fix), `pypdf==5.1.0`/`PyMuPDF==1.24.14` (PDF parsers have a recurring history of DoS/memory issues on malformed input - since this app parses user-uploaded PDFs directly, treat as an untrusted-input boundary), `python-docx==1.1.2` (verify XXE protection on untrusted `.docx` uploads).
**Fix:** run untrusted-file extraction (`process_record.py`) in a resource-bounded worker (timeout + memory cap) regardless of library patch level - this is good practice independent of any specific CVE, and doesn't cost normal-path throughput since it only bounds the worst case.

### L9. RBAC default-deny and audit read-vs-write distinction depend on application code, not the schema
**Files:** `app/models/rbac.py`, `app/models/audit.py`
Schema itself is sound (many-to-many with `valid_until`/`is_active`, unique constraints), but whether authorization defaults to deny with no matching row, and whether every PHI *read* (not just write) gets an audit row, can't be verified from the model alone.
**Fix:** not a code change - confirm via a quick manual test that an unassigned role/permission denies access, and spot-check that read endpoints call the audit logger.

### L10. `OTP purpose` semantics allow a logic inconsistency
**File:** `app/services/auth_service.py:167-186`
An OTP requested with `purpose="registration"` against an already-registered phone silently logs the user in instead of rejecting. Not independently exploitable (still requires proving OTP ownership via SMS) but inconsistent with intent.
**Fix:** reject registration-purpose OTP requests against existing accounts.

---

## What's correctly implemented (confirmed, not assumed)

- **No cross-tenant IDOR found** across records, clinical, family, alerts, consent, emergency, sharing - reads/updates/deletes consistently AND `user_id == current_user.id` (+ `family_scope`).
- **No cross-tenant RAG/chat leakage** - `retrieve_relevant_chunks` and `patient_context.py` scope every vector query to the authenticated user's own `user_id`, never trusting client-supplied `family_member_id` alone.
- **No SQL injection** - 100% SQLAlchemy ORM/parameterized queries across all reviewed files; the only raw `text()` usage is a static `server_default=text("gen_random_uuid()")`.
- **No hardcoded secrets/credentials** found in any application code file (all sourced from `settings`); `.env` and `keys/` are correctly gitignored and confirmed never committed to git history.
- **Password hashing:** bcrypt cost 12 with a SHA-256 pre-hash to safely absorb bcrypt's 72-byte limit.
- **OTPs:** bcrypt-hashed at rest, CSPRNG-generated, per-record `attempt_count`/`max_attempts` genuinely caps guesses regardless of caller IP.
- **Password reset:** avoids account-enumeration (identical response for registered/unregistered emails) and revokes all other sessions on successful reset.
- **Session revocation is real:** `get_current_user` does a live DB check on `UserSession.is_active` every request, not just JWT `exp` - logout actually works, not just cosmetically.
- **`require_role()`** queries roles live from the DB rather than trusting the JWT's baked-in role claim - a revoked role can't be exploited via a still-valid access token.
- **Google/Apple OAuth:** signature/audience/expiry validated (via Google's own library / live JWKS fetch for Apple); account auto-linking gated on the provider's `email_verified` flag.
- **Mass assignment:** all `Update*Request` schemas are field-allowlisted; no `user_id`/`role`/`is_deleted` fields exposed; `emergency.py` explicitly excludes `family_member_id` from its setattr loop.
- **Response schemas don't over-expose:** no `password_hash`/`otp_hash`/`token_hash`/internal S3 keys found in any `Out` schema; `RecordOut` correctly omits full `extracted_text`.
- **CORS:** no wildcard-with-credentials misconfiguration - dev uses a scoped localhost regex, prod uses an explicit origin allowlist from env.
- **Error handling:** global exception handler always returns a generic message regardless of `APP_DEBUG`; full details logged server-side only; `/docs`/`/redoc` disabled in production.
- **Audit middleware design:** opaque IDs only (no PHI values logged), runs as a background task (no added latency to the PHI response path), separate DB pool from app data.
- **Prompt injection surface:** user/document text is interpolated only into user-role prompt segments, never concatenated into the system prompt - role separation is consistent across `prompts.py`, `openrouter.py`, `chat_memory.py`.
- **S3 presigned URLs:** short TTL (15 min), scoped to a single object key, raw URLs never persisted, generated on demand.
- **QR/doctor-share design:** raw token never stored (SHA-256 hash only), 48-byte token, expiry + status + revocation, scope-limited data windows - no full record list ever rendered to the public view.
- **DB pool bounded** (`pool_size`/`max_overflow` set, not unbounded) with `pool_pre_ping` to avoid stale-connection errors.
- **Docker:** runs as non-root (`adduser`/`USER appuser`), no secrets baked into the image.
- No dangerous default/admin accounts created by seed scripts.

---

## Prioritized action list

Ordered by risk-reduction-per-effort. Items marked ⚡ are single-file, low-risk changes that can ship immediately without a deploy-topology change.

1. ⚡ **H1** - Add `default_limits` + `SlowAPIMiddleware` in `main.py` so every route gets a rate-limit floor.
2. **M4** - Point the rate limiter at Redis (`storage_uri`) and consolidate to one `Limiter` instance - without this, H1/H9's fixes don't hold once you run more than one process.
3. ⚡ **H7** - Add the `APP_ENV == production` + `APP_DEBUG` startup guard; flip `.env.example` default to `false`.
4. ⚡ **H6** - Add the 4 security headers via one middleware function.
5. ⚡ **H2** - Add a request body size cap for JSON routes.
6. **H5** - Put a reverse proxy in front of uvicorn; set `--timeout-keep-alive` / `--workers`.
7. **H3** - Move file uploads to presigned POST with `content-length-range`, or verify size in `confirm_upload`.
8. ⚡ **H4, M3** - Add rate limits to `insights.py:health_overview`, `sharing.py:doctor_view`, `sharing.py:create_share_session`.
9. **H9** - Add per-account login lockout.
10. **H8** - Migrate `python-jose` → `PyJWT`/`authlib` (plan as a small, tested, standalone change).
11. ⚡ **M2** - Cap all `limit` query params with `Query(le=200)`.
12. ⚡ **M1** - Add the shared `family_member_id` ownership-validation helper.
13. **M7** - Add `statement_timeout` to the DB engine's `connect_args`.
14. **M5** - Lock down audit-log immutability at the DB grant/trigger level.
15. **M6** - Confirm at-rest encryption on Postgres; scope field-level encryption for `extracted_text`/`ai_summary`/`chunk_text` if not already covered.
16. **M8, M9, M10** - Fix login-timing enumeration, refresh-token-reuse session teardown, and trusted-proxy handling for `X-Forwarded-For` (bundle with H5 since M10 depends on the proxy topology).
17. **M11, M12** - Cap `terminology.py` fan-out before the gather; stop publishing Postgres's port in `docker-compose.yml`.
18. Remaining **L1–L10** - batch as routine hardening (S3 filename sanitization, Apple `iss` check, hardcode JWT alg, cache key files/JWKS, etc.) - none are urgent in isolation.

**On the "don't compromise scalability" constraint:** every fix above is either a startup-time check (H7, L4), a one-time per-request O(1) guard (H1, H2, M2, M7), or an infra-topology change that *improves* throughput under load (H5, M4 - Redis-backed limiting and a reverse proxy are how you scale rate limiting and connection handling horizontally, not overhead against it). None require synchronous work in the hot path beyond what's already there.
