import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/secure_storage.dart';

/// Encrypted Hive-backed store for cached HTTP responses (records, family, profile,
/// insights, etc.) - this box IS the local persistence for "cached health record
/// data" required by the security rule, so no separate hand-rolled cache exists.
/// Created once in `main()` before the app starts, then supplied to Riverpod via
/// an override - see [httpCacheStoreProvider].
///
/// [HiveCacheStore] itself calls `Hive.init(directory)` internally, so no
/// separate Hive bootstrap is needed here.
Future<HiveCacheStore> createEncryptedHttpCacheStore() async {
  final storage = SecureStorageService();
  final key = await storage.getOrCreateCacheEncryptionKey();
  final dir = await getApplicationDocumentsDirectory();
  return HiveCacheStore(
    dir.path,
    hiveBoxName: 'http_cache',
    encryptionCipher: HiveAesCipher(key),
  );
}

/// Overridden in `main()` with the store built by [createEncryptedHttpCacheStore].
final httpCacheStoreProvider = Provider<CacheStore>((ref) {
  throw UnimplementedError(
      'httpCacheStoreProvider must be overridden in main() before runApp()');
});

/// Base cache options shared by the interceptor. Global default policy is
/// [CachePolicy.noCache] - writes, auth, alerts, AI chat, sharing and QR
/// generation all inherit this safely without needing an explicit override.
/// Per-request policies (forceCache / refreshForceCache) are applied via
/// [ApiClient]'s `cachePolicy` parameter, see [cacheOptionsFor].
final httpCacheOptionsProvider = Provider<CacheOptions>((ref) {
  final store = ref.watch(httpCacheStoreProvider);
  return CacheOptions(
    store: store,
    policy: CachePolicy.noCache,
    // 401 is excluded so an expired/invalidated session surfaces immediately
    // instead of being silently masked by stale cached data (which left the
    // dashboard looking logged-in while the session was already dead).
    // Network-level failures (no connection) always fall back to cache
    // regardless of this setting - this is what makes health vault/family
    // screens keep showing last-known data while offline.
    hitCacheOnErrorExcept: const [401],
  );
});

/// Builds the per-request [Options] for a given [CachePolicy], to be merged into
/// a Dio call's `options`. `forceCache` gets the 5-minute maxStale the audit
/// flagged for health vault / family data; `refreshForceCache` and `noCache`
/// otherwise use the base options untouched.
Options cacheOptionsFor(CacheOptions base, CachePolicy policy, {Options? merge}) {
  final options = policy == CachePolicy.forceCache
      ? base.copyWith(
          policy: policy,
          maxStale: const Nullable(Duration(minutes: 5)),
        )
      : base.copyWith(policy: policy);
  final extra = {...?merge?.extra, ...options.toExtra()};
  return (merge ?? Options()).copyWith(extra: extra);
}

/// Wipes every cached response under [pathPrefix] (e.g. `/records`) - used after
/// a mutation (upload, edit, delete) so the next fetch is guaranteed fresh instead
/// of serving a still-live forceCache entry from before the change. Unanchored
/// (no `^`) since the matched path includes the `/api/v1` base prefix.
Future<void> clearHttpCachePath(CacheStore store, String pathPrefix) {
  return store.deleteFromPath(RegExp(RegExp.escape(pathPrefix)));
}

/// Wipes the entire cached-response store - used on logout, per the security rule
/// that all cached health data must be wiped completely when the user signs out.
Future<void> clearAllHttpCache(CacheStore store) => store.clean();
