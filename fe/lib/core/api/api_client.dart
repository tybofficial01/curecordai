import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../cache/http_cache.dart';
import '../storage/secure_storage.dart';

/// Maps the app's saved `language` value to an HTTP `Accept-Language` tag.
/// This is a nice-to-have signal for backend logging/analytics only - the
/// backend's actual language selection for AI responses comes from the
/// `AppSetting.language` value it already has server-side, not from this
/// header.
String _acceptLanguageFor(String language) {
  switch (language) {
    case 'ur':
      return 'ur';
    case 'roman_ur':
      return 'ur-Latn';
    case 'en':
    default:
      return 'en';
  }
}

// Returns the API base URL for the current environment:
//   • dart-define API_BASE_URL → production and real-device dev
//   • iOS Simulator            → localhost (same machine as dev server)
//   • Android emulator         → 10.0.2.2 (emulator bridge to host machine)
// Real device dev: --dart-define=API_BASE_URL=http://192.168.x.x:8000/api/v1
String get _baseUrl {
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (envUrl.isNotEmpty) return envUrl;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return 'http://localhost:8000/api/v1';
  }
  return 'http://10.0.2.2:8000/api/v1';
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});

class ApiClient {
  ApiClient(this._ref) {
    _cacheOptions = _ref.read(httpCacheOptionsProvider);
    _cacheStore = _ref.read(httpCacheStoreProvider);

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.addAll([
      // Added before the auth interceptor so cache-served responses (no
      // network call made) skip the token lookup entirely.
      DioCacheInterceptor(options: _cacheOptions),
      _AuthInterceptor(_ref, _dio),
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    ]);
  }

  late final Dio _dio;
  late final CacheOptions _cacheOptions;
  late final CacheStore _cacheStore;
  final Ref _ref;

  Dio get dio => _dio;

  /// Deletes every cached response whose path starts with [pathPrefix] (e.g.
  /// `/records`) - call after a mutation so the next read is guaranteed fresh
  /// instead of serving a still-live forceCache/refreshForceCache entry.
  Future<void> clearCachePath(String pathPrefix) =>
      clearHttpCachePath(_cacheStore, pathPrefix);

  /// Wipes the entire HTTP response cache - call on logout.
  Future<void> clearAllCache() => clearAllHttpCache(_cacheStore);

  // ── Convenience wrappers ─────────────────────────────────────────────────

  /// [cachePolicy] applies [CachePolicy.forceCache] (5-min maxStale) or
  /// [CachePolicy.refreshForceCache] on top of the shared encrypted cache;
  /// omit it to use the interceptor's global default ([CachePolicy.noCache]),
  /// which is correct for anything live or write-adjacent (alerts, AI chat,
  /// sharing, auth).
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CachePolicy? cachePolicy,
    CancelToken? cancelToken,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: cachePolicy == null
            ? options
            : cacheOptionsFor(_cacheOptions, cachePolicy, merge: options),
        cancelToken: cancelToken,
      );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.post<T>(path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.delete<T>(path, data: data, options: options);
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  // Shared by every request that hits a 401 while a refresh is already in
  // flight, so a page that fires several requests at once (e.g. Medications
  // fetching each family member's list in parallel) all wait for the same
  // refresh and retry with the new token, instead of only the first 401
  // benefiting and the rest failing outright.
  Future<String>? _refreshFuture;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    final language = _ref.read(preferencesProvider).language;
    options.headers['Accept-Language'] = _acceptLanguageFor(language);
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final newAccessToken = await (_refreshFuture ??= _refreshTokens());
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(err.requestOptions);
        handler.resolve(retryResponse);
        return;
      } catch (_) {
        // Refresh token was also rejected - the session is dead server-side.
        // Do the same full local wipe a manual logout does (tokens + HTTP
        // cache + downloaded files + in-memory provider state), not just
        // clear tokens, so stale cached data can't linger past this point.
        // Let the error propagate after so the router redirects to login.
        await _ref.read(authProvider.notifier).handleSessionExpired();
      }
    }
    handler.next(err);
  }

  /// Performs the refresh exactly once no matter how many concurrent 401s
  /// are waiting on it, then clears the shared future so the next 401 (from
  /// a genuinely expired new token) starts a fresh refresh.
  Future<String> _refreshTokens() async {
    try {
      final storage = _ref.read(secureStorageProvider);
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null) {
        throw StateError('No refresh token available');
      }

      final response = await _dio.post(
        '/auth/token/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': null}),
      );

      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String;
      await storage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      return newAccessToken;
    } finally {
      _refreshFuture = null;
    }
  }
}
