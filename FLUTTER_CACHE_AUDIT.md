# Flutter Caching Audit - CurecordAI (`fe/`)

**Scope:** `fe/lib/` - 94 `.dart` files total. Of these, 20 files under `lib/screens/`, `lib/services/`, `lib/providers/`, `lib/models/`, `lib/widgets/` (top-level, not under `lib/features/` or `lib/core/`) are **dead code** - verified unreachable from `main.dart → app.dart → core/router/app_router.dart` (no import anywhere in the live tree references them). They are excluded from the findings below since nothing in Phase 2 would touch them; see [Appendix: Dead Code](#appendix-dead-code).

**Live scope analyzed:** 74 files under `lib/core/` and `lib/features/`.

**Bottom line:** There is currently **no caching layer of any kind** - no HTTP cache, no ETag/conditional requests, no disk-persisted local storage for fetched data, and no offline handling beyond generic "retry" error states. The only thing genuinely cached today is Riverpod's default in-memory provider retention (lost on app restart, and actively defeated in several places by `.autoDispose` or eager `ref.invalidate`) and Flutter's built-in `ImageCache` behind raw `NetworkImage`/`Image.network` (in-memory only, no disk persistence). `flutter_secure_storage` is used correctly for tokens. `shared_preferences` and `cached_network_image` are both declared in `pubspec.yaml` but **never used anywhere** in the live code.

---

## Summary of Critical Issues

1. **Zero HTTP caching anywhere** - every one of the ~45 API call sites hits the network on every invocation; no `dio` cache interceptor, no ETag, no `If-None-Match`. See [§1](#1-api-calls).
2. **Health vault & family data refetch on every screen visit with no offline fallback** - `recordsListProvider`, `familyMembersProvider`, `recordFullProvider`, `healthSummaryProvider` all hit the network unconditionally; two of them (`_healthOverviewProvider`, `_sessionHistoryProvider`) are `.autoDispose`, so they refetch on every widget mount even within the same session. See [§1](#1-api-calls), [§5](#5-state-management-and-caching).
3. **PDF/image documents are fully re-downloaded into memory on every open** - `document_viewer_modal.dart` uses a bare `Dio()` (bypassing the shared API client) for PDFs and raw `Image.network` for images; no disk cache exists. `cached_network_image` is already in `pubspec.yaml` but unused. See [§2](#2-file-downloads).
4. **No offline handling anywhere in the app** - `connectivity_plus` is not a dependency, `SocketException`/connectivity is never checked, and there is no offline banner or cached-data fallback on any screen. Every screen just shows a generic "Could not load" + Retry on network failure (not a crash, but not graceful either). See [§4](#4-offline-handling).
5. **Logout does not clear in-memory Riverpod caches** - `AuthNotifier.logout()` (`features/auth/providers/auth_provider.dart:214`) clears secure-storage tokens but never invalidates `recordsListProvider`, `familyMembersProvider`, `profileProvider`, etc. If a second account logs in within the same app process (without a full app restart), stale medical data from the previous session can remain in Riverpod's provider cache until something happens to invalidate it. Relevant to the SECURITY RULE for Phase 2. See [§3](#3-local-storage-usage).
6. **Presigned URLs (15-min TTL) make naive URL-keyed file caching unsafe** - `download_url` is embedded in the `/records/{id}/full` response and rotates on every fetch (`record_detail_screen.dart:362`). Any `flutter_cache_manager`/`CachedNetworkImage` integration in Phase 2 must key the cache by `record_id`, not by the URL string, or cache entries will silently orphan. See [§2](#2-file-downloads).
7. **Unused dependencies already in `pubspec.yaml`**: `shared_preferences` (^2.3.2) and `cached_network_image` (^3.4.1) are declared but have zero imports anywhere in `lib/`. Preferences (theme, language) are fetched from `/profile/preferences` on every app start with no local persistence - if that call fails offline, the app silently falls back to defaults. See [§3](#3-local-storage-usage), [§5](#5-state-management-and-caching).

---

## 1. API calls

`fe/lib/core/api/api_client.dart` wraps a single shared `Dio` instance (`apiClientProvider`) with one interceptor for auth (`_AuthInterceptor`, line 93) and one `LogInterceptor` (line 40). **No cache interceptor is registered.** Every call below goes straight to the network, every time.

| Endpoint | Method | Call site | Changes how often | Cached? |
|---|---|---|---|---|
| `/users/me` | GET | `home_screen.dart:16` (`_userProvider`), `emergency_screen.dart:42` | Rarely | No |
| `/records` | GET | `records_provider.dart:12` (`recordsListProvider`), `records_provider.dart:34` (`recordsByFamilyMemberProvider`), `home_screen.dart:27` (`_recentRecordsProvider`) | Rarely (health vault) | **No - flagged** |
| `/records/{id}` | GET | `records_provider.dart:22` (`recordDetailProvider`) | Rarely | **No - flagged** |
| `/records/folders` | GET | `records_provider.dart:44` (`foldersProvider`) | Rarely | No |
| `/records/{id}/clinical` | GET | `records_provider.dart:51` (`recordClinicalProvider`) | Rarely | **No - flagged** |
| `/records/{id}/full` | GET | `records_provider.dart:60` (`recordFullProvider`) | Rarely | **No - flagged** |
| `/records/folders` | POST | `records_provider.dart:71` | write | N/A (correctly no-cache) |
| `/records/{id}` | DELETE | `records_screen.dart:754` | write | N/A |
| `{apiPathFor(kind)}/{entityId}` | PATCH | `record_detail_screen.dart:1357` | write | N/A |
| `/records/upload/init` | POST | `upload_screen.dart:143` | write | N/A |
| S3 presigned upload | POST | `upload_screen.dart:184` | write | N/A |
| `/records/{id}/upload/confirm` | POST | `upload_screen.dart:201` | write | N/A |
| `/family` | GET | `family_provider.dart:8` (`familyMembersProvider`) | Rarely | **No - flagged** |
| `/family/{memberId}` | GET | `family_provider.dart:15` (`familyMemberDetailProvider`) | Rarely | **No - flagged** |
| `/family` | POST | `add_caregiver_screen.dart:56`, `add_family_member_screen.dart:89` | write | N/A |
| `/family/{memberId}` | PATCH | `profile_screen.dart:753` | write | N/A |
| `/insights/summary` | GET | `insights_provider.dart:11` (`healthSummaryProvider`) | Rarely | **No - flagged** |
| `/insights/trends/{loincCode}` | GET | `insights_provider.dart:24` (`observationTrendProvider`) | Rarely | No |
| `/allergies?clinical_status=active` | GET | `home_screen.dart:38`, `emergency_screen.dart:52` | Rarely (health vault) | **No - flagged** |
| `/profile` | GET | `profile_providers.dart:16` (`ProfileNotifier._fetch`) | Rarely | **No - flagged** |
| `/profile/avatar` | POST | `profile_providers.dart:27`, `profile_information_screen.dart:183` | write | N/A |
| `/profile/preferences` | GET | `profile_providers.dart:55` | Rarely | **No - flagged, no local persistence either (see §3)** |
| `/profile/preferences` | PUT | `profile_providers.dart:73` | write | N/A |
| `/profile/privacy` | GET | `profile_providers.dart:100` | Rarely | No |
| `/profile/privacy` | PUT | `profile_providers.dart:111` | write | N/A |
| `/profile/data-sharing` | GET | `profile_providers.dart:127` | Occasional | No |
| `/profile/data-sharing/{id}` | DELETE | `profile_providers.dart:135` | write | N/A |
| `/profile/data-sharing` | POST | `profile_providers.dart:142` | write | N/A |
| `/profile`, `/profile/physical-metrics`, `/profile/health-details` | PUT | `profile_information_screen.dart:136,143,148`, `profile_completion_step3_screen.dart:46` | write | N/A |
| `/consent/` | GET | `consent_management_screen.dart:13` (`consentSummaryProvider`) | Occasional | No |
| `/consent/` | POST | `consent_management_screen.dart:137` | write | N/A |
| `/consent/data-export` | POST | `settings_screen.dart:495` | write | N/A |
| `/emergency/settings` | GET | `emergency_screen.dart:14` | Rarely | No |
| `/emergency/contacts` | GET | `emergency_screen.dart:25` | Rarely | No |
| `/emergency/settings` | PATCH | `emergency_screen.dart:116` | write | N/A |
| `/emergency/contacts` | POST/DELETE | `emergency_screen.dart:143,170` | write | N/A |
| `/alerts` | GET | `alerts_screen.dart:9` (`_alertsProvider`) | Frequent-ish | No (appropriate) |
| `/alerts/read-all`, `/alerts/{id}/read`, `/alerts/{id}` | POST/DELETE | `alerts_screen.dart:40,112,117,134,139,157,162` | write | N/A |
| `/share/...` | GET | `share_screen.dart:16` (`_shareSessionsProvider`) | Occasional | No |
| `/share/qr` | POST | `share_screen.dart:86` | write | N/A (correctly no-cache candidate) |
| `/ai/sessions` | GET | `ai_chat_screen.dart:100,994` | Live/frequent | N/A (correctly no-cache candidate) |
| `/ai/sessions/{id}/messages` | GET | `ai_chat_screen.dart:117,179` | Live/frequent | N/A |
| `/ai/sessions` | POST | `ai_chat_screen.dart:208` | write | N/A |
| `/ai/chat` (SSE stream) | POST | `ai_chat_screen.dart:300` | live | N/A (correctly no-cache candidate) |
| `/auth/*` (otp/register/login/oauth) | POST | `auth_provider.dart` (features) lines 58,78,104,120,138,160,181,198,233 | N/A | N/A (correctly no-cache candidate) |
| `/auth/token/refresh` | POST | `api_client.dart:127` | N/A | N/A (correctly no-cache candidate) |

**Endpoints fetching data that rarely changes with zero caching** (the ones that matter most for Phase 2, per the user's own framing - profile, family list, health vault records):
- `/records` and `/records/{id}` and `/records/{id}/full` and `/records/{id}/clinical` - `records_provider.dart:12,22,51,60`
- `/family` and `/family/{memberId}` - `family_provider.dart:8,15`
- `/profile` - `profile_providers.dart:16`
- `/insights/summary` - `insights_provider.dart:11`
- `/allergies` - `home_screen.dart:38`, `emergency_screen.dart:52`

---

## 2. File downloads

All document/image fetching lives in **`fe/lib/features/records/widgets/document_viewer_modal.dart`**, plus raw `NetworkImage` usage scattered across avatar/photo UI.

- **`document_viewer_modal.dart:94`** - `Image.network(url, ...)`: images are rendered via Flutter's default `Image.network`, which uses Flutter's in-memory `ImageCache` only (no disk persistence, evicted under memory pressure, and keyed by the URL string).
- **`document_viewer_modal.dart:128-142`** - `_PdfViewerState._load()` creates a **brand-new `Dio()` instance** (not the shared `apiClientProvider`) and does `Dio().get<List<int>>(widget.url, options: Options(responseType: ResponseType.bytes))` to pull the entire PDF into memory, then `PdfDocument.openData(...)`. This runs from scratch **every single time the modal is opened** - there is no disk cache, no check for an existing local copy, nothing.
- **`cached_network_image: ^3.4.1`** is declared in `fe/pubspec.yaml:32` but **is not imported or used anywhere** in `lib/` - it would have solved the image half of this for free.
- **No file caching package at all is installed** (`flutter_cache_manager` is not in `pubspec.yaml`; it ships transitively inside `cached_network_image` but isn't exposed/used directly).
- **Design constraint for Phase 2**: `download_url` is a presigned S3 URL with a **15-minute TTL**, embedded directly in the `/records/{id}/full` response (`record_detail_screen.dart:362`, consumed at `record_detail_screen.dart:237,239`) - it is regenerated (a new, different URL string) on every fetch of that record. A cache keyed by URL (the default behavior of both `CachedNetworkImage` and `flutter_cache_manager`) will never hit, because the key changes every time. **Phase 2 must derive the cache key from `record_id` (+ maybe a content hash/version), not from the URL.**

**Raw `NetworkImage` usage (avatar/profile photos)** - gets Flutter's default in-memory `ImageCache` only, no disk persistence, same URL-rotation risk if these URLs are also presigned:
- `home_screen.dart:480,511,537`
- `profile_information_screen.dart:241`
- `profile_screen.dart:281,683`
- `settings_screen.dart:81`

No DICOM-specific handling exists anywhere in the codebase (only PDF/image mime branches in `document_viewer_modal.dart:72-76`; the third branch is `_UnsupportedPreview`).

---

## 3. Local storage usage

**`shared_preferences`** (`fe/pubspec.yaml:28`) - **declared but never used.** No file in `lib/` imports `package:shared_preferences`. User theme (`themeModeProvider`, `profile_providers.dart:83`) and locale (`localeProvider`, `profile_providers.dart:88`) are derived purely from the in-memory `PreferencesNotifier` state (`profile_providers.dart:46-76`), which is loaded fresh from `/profile/preferences` on every app start (`_load()`, line 52) and **silently swallows errors** (`catch (_) {}`, line 57) - meaning on a cold start with no network, preferences just silently stay at hardcoded defaults instead of the user's last-known choice. Nothing is persisted locally.

**`flutter_secure_storage`** (`fe/pubspec.yaml:25`) - used correctly for the sensitive bits. `fe/lib/core/storage/secure_storage.dart`:
- `access_token`, `refresh_token`, `user_id` - stored via `_storage.write` (lines 14-16, 24-25, 33), Android `encryptedSharedPreferences: true` (line 10), iOS Keychain with `first_unlock` accessibility (line 11). Correct.
- `carousel_seen` flag (line 17, 49-55) - non-sensitive UI flag stored here too; harmless but arguably belongs in `shared_preferences` once that's wired up (cosmetic, not a security issue).
- **No `hive` or `sqflite`** dependency exists in `pubspec.yaml`, and no such usage exists anywhere in `lib/` - confirmed via search.

**Net effect: no medical data is persisted locally anywhere today** - records, family list, profile, insights all live only in transient Riverpod provider state (RAM only, cleared on app kill). This trivially satisfies the SECURITY RULE today (nothing in plaintext on disk) but also means the app has **zero offline capability** right now - see §4.

**Logout gap** (`fe/lib/features/auth/providers/auth_provider.dart:210-225`, `logout()`): clears `access_token`/`refresh_token`/`user_id` via `_storage.clearTokens()` (line 214) and best-effort revokes server-side (line 220), but **never calls `ref.invalidate(...)`** on any of the data providers (`recordsListProvider`, `familyMembersProvider`, `profileProvider`, `healthSummaryProvider`, etc.). Because these are plain global `FutureProvider`s (not scoped per-user), if the app allows switching accounts without a full process restart, the previous user's already-fetched records/profile data can remain resident in the Riverpod container. Today this is an in-memory-only leak (app RAM, not disk), but it becomes a real data-isolation bug once Phase 2 adds persisted, encrypted Hive caching - the same gap must be closed by clearing those boxes on logout too, per the SECURITY RULE.

---

## 4. Offline handling

**`connectivity_plus` is not a dependency** and is not referenced anywhere. **`SocketException` is never caught or checked anywhere in `lib/`** (confirmed via search - zero matches). There is no app-wide connectivity listener, no offline banner, and no cached-data fallback on any screen.

What every screen does instead, uniformly, is rely on Riverpod's `AsyncValue.error` branch inside `.when(...)` to show a generic "Could not load" + Retry button. This means **no screen crashes outright on a network failure** (no unguarded `.value!`/`.requireValue` was found in `lib/features`), but **every screen that makes an API call has zero fallback beyond "try again"** - none of them show last-known cached data, and none of them are aware of connectivity state.

Representative examples of this pattern (same shape repeats across the app):
- `record_preview_sheet.dart:156-183` - `.when(data:..., loading:..., error: (_, __) => ...)` shows "Could not load this record." + Retry, no fallback to `fallbackTitle`/cached data beyond what was already passed in as props.
- `profile_screen.dart:67` - `_ErrorView(onRetry: () => ref.refresh(profileProvider))`.
- `health_summary_screen.dart:51,82` - retry via `ref.invalidate(_healthOverviewProvider)`.
- `ai_summary_screen.dart:42` - `ref.refresh(recordDetailProvider(recordId))`.

**Screens/flows with no offline consideration at all** (would show the network error state with no cached fallback, per the user's requirement that health vault / family screens "must always show the last cached data when offline"):
- Records list - `records_screen.dart` (backed by `recordsListProvider`)
- Record detail - `record_detail_screen.dart` (backed by `recordFullProvider`)
- Family list - `family_screen.dart` (backed by `familyMembersProvider`)
- Home dashboard - `home_screen.dart` (three inline providers, lines 14-47)
- Insights - `insights_screen.dart`, `health_summary_screen.dart`

**Screens that should be explicitly disabled offline** (per the user's Phase 2 spec) but currently have no such gating:
- Document upload - `upload_screen.dart` (no connectivity check before `/records/upload/init` at line 143)
- AI assistant - `ai_chat_screen.dart` (no connectivity check before session/message calls)
- Doctor sharing - `share_screen.dart` (no connectivity check before `/share/qr` at line 86)

---

## 5. State management and caching

State management is **Riverpod 2** throughout (`flutter_riverpod: ^2.5.1`), consistent with the noted architecture. No Bloc/GetX/plain `Provider` package usage was found in the live tree (the `provider: ^6.1.2` dependency in `pubspec.yaml:59` is only used by the dead legacy code under `lib/providers/` - see [Appendix](#appendix-dead-code)).

**Default (non-`autoDispose`) `FutureProvider`s** - these persist for the app's process lifetime once first read, so within a single session they behave like an unbounded in-memory cache with no TTL and no disk persistence (lost on restart): `recordsListProvider`, `recordDetailProvider`, `recordsByFamilyMemberProvider`, `foldersProvider`, `recordClinicalProvider`, `recordFullProvider` (`records_provider.dart`), `familyMembersProvider`, `familyMemberDetailProvider` (`family_provider.dart`), `healthSummaryProvider`, `observationTrendProvider` (`insights_provider.dart`), and the private providers in `home_screen.dart:14,20,33`, `emergency_screen.dart:10,21,35,48`, `share_screen.dart:12`, `consent_management_screen.dart:11`. None use Riverpod's `keepAlive()`/cache-configuration APIs explicitly - they rely on the (undocumented-to-callers) default retention behavior, which is fragile: any accidental `.autoDispose` added later silently changes the caching characteristics.

**`.autoDispose` providers that refetch on every widget mount** (flagged - these are the ones actively working against caching):
- `health_summary_screen.dart:9` - `_healthOverviewProvider` (`FutureProvider.autoDispose<Map<String, dynamic>>`) - refetches `/insights/summary`-derived data every time the Health Summary screen is opened, even though summary data changes rarely.
- `ai_chat_screen.dart:991` - `_sessionHistoryProvider` (`FutureProvider.autoDispose`) - refetches the session list every time the history sheet opens.

**Aggressive `ref.invalidate`/`ref.refresh` usage** - every one of these forces a full network refetch with no cache-then-refresh pattern (no stale-while-revalidate): `alerts_screen.dart` (8 call sites, lines 41,52,113,118,135,140,158,163), `emergency_screen.dart:152,171`, `family_screen.dart:56,120`, `add_caregiver_screen.dart:62`, `add_family_member_screen.dart:100`, `records_screen.dart:73,91,495,755`, `record_detail_screen.dart:110,111,167,168,219,325,1359`, `upload_screen.dart:208,209`, `profile_screen.dart:667,754,755`, `insights_screen.dart:37`, `ai_summary_screen.dart:42`, `consent_management_screen.dart:141`, `share_screen.dart:97,295`, `records_provider.dart:72`.

**`AsyncNotifier`/`StateNotifier` classes** (`ProfileNotifier`, `PreferencesNotifier`, `PrivacyNotifier`, `DataSharingNotifier` in `profile_providers.dart`; `ActiveProfileNotifier` in `active_profile_provider.dart`) hold their fetched state in memory only, same characteristics as above - no persistence, no explicit cache policy.

---

## 6. ETag and conditional requests

**No conditional-request support exists anywhere.** Confirmed via search across `lib/core` and `lib/features`: zero occurrences of `ETag`, `If-None-Match`, or `etag` (case-insensitive). `_AuthInterceptor` (`api_client.dart:93-156`) only handles the `Authorization` header and 401 refresh/retry - it does not read or attach any caching-related headers, and the `LogInterceptor` (`api_client.dart:40-44`) is diagnostic-only.

**Endpoints that would most benefit from `If-None-Match`/ETag support** (all GET, all returning data that changes infrequently relative to how often they're called):
- `/records`, `/records/{id}`, `/records/{id}/full`, `/records/{id}/clinical` - `records_provider.dart:12,22,51,60`
- `/family`, `/family/{memberId}` - `family_provider.dart:8,15`
- `/profile` - `profile_providers.dart:16`
- `/insights/summary` - `insights_provider.dart:11`
- `/users/me` - `home_screen.dart:16`, `emergency_screen.dart:42`
- `/allergies` - `home_screen.dart:38`, `emergency_screen.dart:52`

Note: ETag support requires the **backend** to emit `ETag` response headers and honor `If-None-Match` with `304 Not Modified` - this audit only covers the Flutter side. Whether `be/app/api/v1/*` routers currently emit ETags was not checked (out of scope: task specifies `fe` directory only) and should be verified before Phase 2 wires up `If-None-Match` on the client, or the client-side header will simply be ignored by the server.

---

## Appendix: Dead Code

The following 20 files under `lib/screens/`, `lib/services/`, `lib/providers/`, `lib/models/`, `lib/widgets/` (top-level, sibling to `lib/features/` and `lib/core/`) are **not reachable from `main.dart`** - `app_router.dart` (the only router wired into `app.dart`) imports exclusively from `lib/features/`. Verified by checking every import chain from `main.dart → app.dart → core/router/app_router.dart` and confirming zero references from `lib/features/` or `lib/core/` into these directories:

- `lib/screens/**` (auth screens, carousel, home, onboarding, splash - all duplicated by newer equivalents under `lib/features/`)
- `lib/services/api_service.dart`, `auth_service.dart`, `storage_service.dart`
- `lib/providers/auth_provider.dart` (a second, older `authProvider` - not the one used by the live app, which is `lib/features/auth/providers/auth_provider.dart`)
- `lib/models/user_model.dart`
- `lib/widgets/*.dart` (custom_text_field, illustration_header, loading_overlay, otp_input_field, phone_input_field, primary_button, progress_step_bar, secondary_button, social_button)

This is out of scope for the caching work (nothing in Phase 2 touches unreachable code) but is worth flagging separately as dead-code cleanup, since it roughly doubles the size of the auth-related surface area for anyone reading the codebase cold.

---

*Please review before I proceed to Phase 2 implementation.*
