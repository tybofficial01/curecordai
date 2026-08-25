# Flutter Caching Implementation - Summary

Implements the plan approved after [FLUTTER_CACHE_AUDIT.md](FLUTTER_CACHE_AUDIT.md). Scope: `fe/lib/` only (`core/` and `features/` - the dead legacy dirs identified in the audit appendix were not touched).

## New files

- `fe/lib/core/cache/http_cache.dart` - encrypted Hive-backed HTTP cache store, base `CacheOptions`, per-request policy builder, cache-clearing helpers.
- `fe/lib/core/cache/file_cache_manager.dart` - `RecordFileCacheManager`, the shared `flutter_cache_manager` instance for PDFs/images/avatars.
- `fe/lib/core/network/connectivity_provider.dart` - `isOnlineProvider` (`StreamProvider<bool>` over `connectivity_plus`).
- `fe/lib/core/widgets/offline_banner.dart` - `OfflineBannerScope` (global banner) and `OfflineBlockedNotice` (full-screen block for upload/AI/sharing).

## pubspec.yaml

Added: `dio_cache_interceptor: ^3.5.1`, `dio_cache_interceptor_hive_store: ^3.2.2`, `hive: ^2.2.3`, `flutter_cache_manager: ^3.4.1`, `connectivity_plus: ^7.0.0`.

**Deviation from the plan:** the plan said "`DbCacheStore` with encrypted hive as the backing store." `DbCacheStore` is a real but different dio_cache_interceptor store backed by SQLite, not Hive - it doesn't support Hive encryption at all. Used `HiveCacheStore` instead (from `dio_cache_interceptor_hive_store`), which does what the security rule actually requires: an encrypted Hive box as the cache backing store.

**Also had to downgrade** `dio_cache_interceptor`/`dio_cache_interceptor_hive_store` from the `^4.0.0` originally planned to `^3.5.1`/`^3.2.2` - pub's dependency resolver rejected 4.x (the hive-store package's 4.x line requires `dio_cache_interceptor ^4.x`, but its transitive `hive_ce` dependency doesn't align with the plain `hive` package the resolved 3.x line uses internally). Went with the 3.x line since `HiveCacheStore` there calls `Hive.init()` and expects `package:hive`'s `HiveCipher` directly - kept the whole app on one Hive runtime instead of running `hive` and `hive_ce` side by side.

## HTTP caching (`core/api/api_client.dart`, `core/cache/http_cache.dart`)

- `DioCacheInterceptor` registered on the shared `Dio` instance, ahead of the auth interceptor (cache hits skip the token lookup entirely).
- Global default policy: `CachePolicy.noCache` - alerts, AI chat, sharing, QR generation, uploads, and all mutations (POST/PUT/PATCH/DELETE) inherit this safely with **no code changes needed**, since nothing explicitly opts them into caching.
- `ApiClient.get()` gained an optional `cachePolicy` parameter. Applied per the plan:
  - **`CachePolicy.forceCache` (5-min maxStale):** `/records`, `/records/{id}`, `/records/{id}/clinical`, `/records/folders`, `/family`, `/family/{id}` - the audit's flagged "health vault + family" endpoints.
  - **`CachePolicy.refreshForceCache`:** `/users/me`, `/profile`, `/profile/preferences`, `/profile/privacy`, `/profile/data-sharing`, `/insights/summary`, `/insights/health-overview`, `/allergies`, `/emergency/settings`, `/emergency/contacts`, `/consent/`.
- **Deliberately left uncached:** `recordFullProvider` (`/records/{id}/full`, `records_provider.dart`). The Record Detail screen polls this every 3s via `ref.invalidate` while AI extraction is processing (`record_detail_screen.dart:_startPolling`) - a cache policy here would have served the same stale "processing" response for the whole maxStale window and the UI would never see the pipeline finish. Cache-path invalidation after edits still applies to it via `clearCachePath('/records')`, just not a `forceCache`/`refreshForceCache` read policy.
- **Offline fallback mechanism:** `hitCacheOnErrorExcept: const []` on the base `CacheOptions` - an empty list means "return the cached response on any error status code," and per the package's own semantics, network-level failures (no connection) fall back to cache regardless of this setting. This is what makes health vault/family/profile screens keep showing last-known data offline with **zero per-screen offline-fallback code** - it's handled once, centrally, at the HTTP layer.
- **Known limitation:** `refreshForceCache` (and, to no functional difference here, `forceCache`) only truly benefits from server-driven revalidation (ETags/`Cache-Control`) once the backend emits them - see the audit's §6. Right now the *client* correctly negotiates `If-None-Match`/ETags whenever the server sends them (built into `dio_cache_interceptor`), but the backend doesn't yet, per the audit. This was flagged as out of scope for the Flutter-only audit and remains a backend follow-up.

## Cache invalidation

- **After upload confirm** (`upload_screen.dart`): `api.clearCachePath('/records')` before the existing `ref.invalidate` calls, so the next fetch is guaranteed fresh instead of possibly still inside the 5-minute `forceCache` window.
- **After record edit/delete** (`record_detail_screen.dart`, `records_screen.dart`) and **folder create** (`records_provider.dart`): same `clearCachePath('/records')` pattern. Record delete also evicts the file-cache entry (`RecordFileCacheManager.instance.removeFile(recordId)`).
- **After family add/edit** (`add_caregiver_screen.dart`, `add_family_member_screen.dart`, `profile_screen.dart`): `clearCachePath('/family')`.
- **After avatar upload** (`profile_providers.dart`): removes the old cached avatar file by its `avatar_<id>` key, since a new photo at the same stable key would otherwise keep showing the old cached image for 7 days.
- **On logout** (`auth_provider.dart`): `api.clearAllCache()` wipes the entire encrypted HTTP cache (records, family, profile, insights, consent - everything), and every data provider - including the ones that used to be screen-private - is explicitly `ref.invalidate`d. The downloaded file cache (PDFs/images) is **not** touched, per the plan - only cleared on explicit document delete or its own 7-day expiry.

**Follow-up applied:** the screen-private providers flagged in the first pass (`_userProvider`/`_recentRecordsProvider`/`_activeAllergiesProvider` in `home_screen.dart`, the four in `emergency_screen.dart`, `_shareSessionsProvider` in `share_screen.dart`, `_sessionHistoryProvider` in `ai_chat_screen.dart`, `_healthOverviewProvider` in `health_summary_screen.dart`) have been un-prefixed (made file-public: `homeUserProvider`, `recentRecordsProvider`, `homeActiveAllergiesProvider`, `emergencySettingsProvider`, `emergencyContactsProvider`, `activeBloodGroupProvider`, `emergencyActiveAllergiesProvider`, `shareSessionsProvider`, `sessionHistoryProvider`, `healthOverviewProvider`) and are now imported and invalidated in `auth_provider.dart`'s `_invalidateCachedDataProviders()` alongside the rest. Logout now resets every data provider's in-memory state, not just the ones that happened to already be exported.

## File caching (`document_viewer_modal.dart`, avatar images)

- `RecordFileCacheManager` (`flutter_cache_manager`): 7-day `stalePeriod`. Cap is `maxNrOfCacheObjects: 150` rather than a literal byte count - `flutter_cache_manager`'s `Config` only supports an object-count cap, not raw bytes, so 500MB is approximated at ~3.3MB/file (typical scanned medical PDF/image size). Marked with a `ponytail:` comment noting the ceiling and how to upgrade (a periodic directory-size sweep) if average file size grows enough to matter.
- **Cache key is `record_id`, not the URL** - `download_url` is a presigned S3 link with a 15-minute TTL that rotates on every fetch (per the audit's §2/§6). Both the PDF viewer (`getSingleFile(url, key: recordId)`) and the in-modal image viewer (`CachedNetworkImage(cacheKey: recordId, ...)`) key on the stable record id, so a document is only downloaded once per 7-day window regardless of how many times its presigned URL is regenerated.
- **Avatar images** (`home_screen.dart`, `profile_information_screen.dart`, `profile_screen.dart`, `settings_screen.dart`): swapped raw `NetworkImage`/`Image.network` for `CachedNetworkImageProvider`/`CachedNetworkImage` using the same `RecordFileCacheManager`. Where a stable id was available (own profile `id`, family member `id`) it's used as the cache key (`avatar_<id>`) for the same rotation-safety reason as documents; the two spots in `home_screen.dart` that only receive a bare URL string (no id in scope) fall back to the default URL-keyed cache, which is a real disk-cache improvement over the previous in-memory-only `NetworkImage` even if it wouldn't survive a URL rotation.
- No DICOM-specific caching was added - the audit confirmed there is no DICOM viewer/download code path anywhere in the app to attach one to.

## Local storage

- **Auth tokens:** already correctly in `flutter_secure_storage` (`secure_storage.dart`) - no change needed.
- **Cache encryption key:** `SecureStorageService.getOrCreateCacheEncryptionKey()` - generates a `Hive.generateSecureKey()` AES-256 key once per device install, stored in `flutter_secure_storage`. Used as the `HiveCacheStore`'s `encryptionCipher`. Intentionally **not** cleared on logout - it protects the cache box itself (which is fully wiped via `clearAllCache()`), not any one user's session.
- **User preferences (theme, language):** `PreferencesNotifier` (`profile_providers.dart`) now reads from `shared_preferences` first on startup - so the app never flashes hardcoded defaults on a cold, offline start - then refreshes from `/profile/preferences` in the background and writes through to `shared_preferences` on every change and every successful backend read.
- **Cached health record data:** lives only in the encrypted `HiveCacheStore` box described above - no separate hand-rolled cache was built, since the HTTP cache *is* the local persistence of that data. Nothing is stored in plain `shared_preferences`.

## Offline handling

- `isOnlineProvider` (`connectivity_provider.dart`): initial `checkConnectivity()` + live `onConnectivityChanged` stream, exposed as a single `bool`.
- `OfflineBannerScope`, mounted once in `app.dart`'s `MaterialApp.router(builder: ...)`, shows a persistent "You're offline - showing last saved data" banner above every screen in the app - including the full-screen routes above the tab shell - without touching each screen individually.
- Health vault, family, profile, insights, and emergency screens need no additional offline-specific code: the `hitCacheOnErrorExcept` fallback at the HTTP layer means their existing `FutureProvider`/`AsyncNotifier` code already receives a cached `Response` transparently when offline, so their existing `.when(data: ...)` branches just render the cached data as if it were fresh.
- **Explicitly disabled offline** (`OfflineBlockedNotice`, full-screen replacement): `upload_screen.dart`, `ai_chat_screen.dart`, `share_screen.dart` - each checks `isOnlineProvider` at the top of `build()` and shows a clear explanatory message instead of the normal UI, per the plan.

## Security rule compliance

- No medical data is stored in plain text anywhere - the only persisted health-record cache is the encrypted `HiveCacheStore` box, keyed with a device-specific AES-256 key held in `flutter_secure_storage`.
- Logout wipes that entire cache (`api.clearAllCache()` → `HiveCacheStore.clean()`) plus tokens plus reachable in-memory provider state, per the "on logout, all medical data cached on device must be wiped completely" rule - with the one documented in-memory-only limitation above.
- The downloaded file cache (PDFs/images) is untouched by logout by design, matching the plan's explicit instruction not to clear it there.

## Verification

`flutter pub get` and `flutter analyze` both run clean - 0 errors, 0 warnings. Remaining `info`-level lints (113) are pre-existing style nits (`prefer_const_constructors`, `curly_braces_in_flow_control_structures`) in files this change didn't touch, including the dead legacy `lib/providers/auth_provider.dart` identified in the audit appendix; left alone per "without touching anything else."

Not done as part of this change: no emulator/device run was performed, so this is verified at the analyzer/type level, not by exercising the app's UI live.
