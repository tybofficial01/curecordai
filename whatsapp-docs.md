# WhatsApp Cloud API — Reference for CurecordAI WhatsApp Agent
> **Instruction for the coding agent:** treat this file as the entry point. Read the relevant section before writing each piece of the integration. If something you need isn't covered here, fetch the linked page or official docs rather than relying on memory — this API has changed materially more than once in 2026  so recall from training data is not reliable for this integration.

---

## 1. Platform overview / getting started

- https://developers.facebook.com/documentation/business-messaging/whatsapp/about-the-platform
- https://developers.facebook.com/docs/whatsapp/cloud-api

**Key points:**
- Cloud API is the current, Meta-hosted implementation — the legacy On-Premises API is deprecated. Don't implement against On-Premises API docs if they show up in search.
- Meta doesn't publish an official end-to-end SDK for message sending/webhooks; it's a plain REST/JSON HTTP API called directly (matches this project's plan of a thin `whatsapp_service.py` httpx client, no vendor SDK).
- Meta publishes an official Postman collection and an in-browser "API Reference" playground with a "Try it" button per endpoint — useful for verifying request/response shapes while building, linked from the About page above.
- Default throughput: 80 messages/second per business phone number, with upgrades available.

---

## 2. Webhooks — setup, verification handshake, payload shapes

- https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview
- https://developers.facebook.com/docs/whatsapp/cloud-api/guides/set-up-webhooks/

**Key points:**
- Two-phase lifecycle: (1) a one-time **GET** verification handshake when you register the webhook URL in the Meta App Dashboard — Meta sends `hub.mode` (always `subscribe`), `hub.verify_token` (a string you define), and `hub.challenge`; your endpoint must echo back `hub.challenge` if the token matches. (2) Ongoing **POST** JSON payloads for actual events.
- Required permissions: `whatsapp_business_messaging` for message webhooks, `whatsapp_business_management` for everything else (status changes, template quality scores, account changes).
- You subscribe to specific webhook "fields" individually in the App Dashboard (messages, message status, template status, etc.) — don't assume all event types arrive by default.
- Webhooks cover: incoming messages, outgoing message status/delivery, call events, account status changes, messaging capability upgrades, template quality score changes.

---

## 3. Signature verification (the trust boundary for the webhook)

- https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview (see "Verifying Requests" section)

**Key points:**
- Every POST from Meta includes `X-Hub-Signature-256`, an HMAC-SHA256 signature of the raw request body using your app secret.
- Verify using `hmac.compare_digest`-style constant-time comparison on the **raw** body bytes, before any JSON parsing — matches this project's existing plan. Compute the HMAC yourself and compare rather than trusting the header at face value.
- Reject with 401 before touching the payload at all if verification fails.

---

## 4. Sending messages (text, media, templates)

- https://developers.facebook.com/docs/whatsapp/cloud-api/reference/messages/
- https://developers.facebook.com/documentation/business-messaging/whatsapp/messages/send-messages
- https://developers.facebook.com/docs/whatsapp/cloud-api/guides/send-messages/

**Key points:**
- Endpoint: `POST https://graph.facebook.com/<API_VERSION>/<PHONE_NUMBER_ID>/messages`, bearer token auth, `messaging_product: "whatsapp"` required in every payload.
- Messages are identified by a WAMID (max 128 chars) — track status via webhooks using this ID.
- **Delivery ordering is not guaranteed** across a batch of API requests. If your task sends multiple messages for one reply (e.g. a chunked long chat response), don't assume they arrive in send order — if strict order matters, confirm a "delivered" status webhook before sending the next chunk, or send as a single message and chunk only when over the ~4096 char limit.
- Message TTL (validity period): 30 days default for most message types; customizable for utility/authentication/marketing templates.
- Phone number formatting: include the leading `+` and country code explicitly in the `to` field. If `+` is omitted, your **own** business number's country code gets silently prepended to the customer number, which can misdeliver — relevant to the E.164 normalization step in this project's plan.
- Outbound media: either upload to Meta first and reference by `id`, or pass a `link` to a URL you host (Meta caches the linked asset for 10 minutes) — relevant to how `send_document` should send the presigned S3 URL for a record.

---

## 5. Media (inbound download, outbound upload)

- https://developers.facebook.com/documentation/business-messaging/whatsapp/business-phone-numbers/media

**Key points:**
- Inbound media messages (image, document, audio) arrive via webhook with a **media ID**, not a direct URL. Call `GET /<API_VERSION>/<MEDIA_ID>` with your bearer token to resolve it to a temporary download URL, then fetch that URL (also bearer-token-authenticated).
- **Inbound media URLs expire after 5 minutes** — download promptly inside the background task, don't defer.
- Max file size for media messages: 100MB. Oversized incoming files produce webhook error code `131052` ("Media file size too big").
- Common failure: MIME type mismatch (error `131053`) — verify the actual file MIME type rather than trusting the extension, especially for voice notes headed to Soniox.
- Outbound upload endpoint: `POST /<PHONE_NUMBER_ID>/media` as multipart form data.

---

## 6. Message templates (needed for the future medication-reminder feature, not the initial build)

- https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/overview
- https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/authentication-templates/authentication-templates
- https://developers.facebook.com/docs/whatsapp/updates-to-pricing/new-template-guidelines/ (category guidelines)

**Key points:**
- Templates are the **only** message type that can be sent outside an open 24-hour customer service window — required for any business-initiated message (e.g. medication reminders), not needed for replying to a user who messaged first.
- Three categories: Marketing, Utility, Authentication. A reminder feature is almost certainly **Utility** (follow-up on a user action/request), not Marketing — miscategorization gets templates rejected or recategorized after the fact, sometimes automatically and without warning per the 2025 policy update linked above.
- Templates must be created and approved (via WhatsApp Manager UI or the Message Templates API) before use; approval is typically minutes to ~48 hours.
- Template strings are not translated by Meta — you supply the exact string per language, and each name+language pair counts separately against template limits (relevant given this bot needs EN/UR/Roman Urdu).
- Authentication templates have fixed, non-customizable preset text (not relevant to reminders, but relevant if this project later WhatsApp-delivers OTPs instead of SMS).

---

## 7. Pricing / the 24-hour customer service window

- https://developers.facebook.com/docs/whatsapp/cloud-api/guides/send-messages/ (window rules)
- General guidance (not an official Meta page, cross-check against WhatsApp Business Messaging Policy at business.whatsapp.com/policy): the 24-hour window opens when a user messages first; free-form replies are allowed inside it without a template.

**Key points — confirm against Meta's current rate card before launch, this has moved twice in 2026:**
- **As of this writing, a pricing change takes effect October 1, 2026**: service messages and utility templates sent inside the 24-hour window — currently free — move to per-message billing. Verify the live rate card at launch time rather than assuming this doc's snapshot.
- Marketing templates require explicit opt-in and cost more than utility/authentication.
- This directly affects the `[NEW]` "WhatsApp Business messaging policy" section of the project plan — re-check before the medication-reminder feature ships, since a Utility template's cost will no longer be "free inside the window" by the time it's built.

---

## 8. Error codes

- https://developers.facebook.com/documentation/business-messaging/whatsapp/support/error-codes
- https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes/

**Key points:**
- Errors can surface **synchronously** (as the direct Graph API response to your send call) **or asynchronously** (via a webhook), sometimes both — the task orchestrator should handle both paths, not just the synchronous response, when marking a `WhatsAppInboundMessage`/outbound send as failed.
- Meta recommends building error-handling logic around the `code` value and `error_data.details`, not the human-readable `message`/title text, which is not guaranteed stable.
- Errors relevant to this build to handle explicitly:
  - `130429` — rate limit hit (Cloud API message throughput reached)
  - `131056` — per-recipient pair rate limit (too many messages to the same user in a short period) — relevant to the rate-limiting item flagged in the audit
  - `131052` — media file too big (>100MB)
  - `131053` — mismatched MIME type

---

## 9. Status page / observability

- https://developers.facebook.com/documentation/business-messaging/whatsapp/support

**Key points:**
- Meta publishes a WhatsApp Business API status page with Cloud-API-specific latency/availability metrics — worth wiring an alert or dashboard check against this rather than only inferring outages from your own error rates.

---

## How to keep this current

This file is a snapshot, not a live feed. Before implementing:
- **Webhook + signature verification + media download** (sections 2, 3, 5): stable mechanics, low change risk — this snapshot should be reliable.
- **Templates + pricing** (sections 6, 7): high change risk — Meta has changed template categorization enforcement and billing structure multiple times in 2026. Re-fetch these two sections specifically before building the medication-reminder feature, don't rely on this snapshot by then.
- If Claude Code (or another agent) hits a Graph API response shape not described here, fetch the specific reference page rather than guessing from this summary — these are curated notes, not the full spec.