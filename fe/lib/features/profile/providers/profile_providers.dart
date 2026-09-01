import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../home/screens/home_screen.dart' show homeUserProvider;
import '../models/profile_models.dart';

// ── Profile ───────────────────────────────────────────────────────────────────

class ProfileNotifier extends AsyncNotifier<FullProfileResponse> {
  @override
  Future<FullProfileResponse> build() => _fetch();

  Future<FullProfileResponse> _fetch() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get<Map<String, dynamic>>('/profile',
        cachePolicy: CachePolicy.refreshForceCache);
    return FullProfileResponse.fromJson(res.data ?? {});
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> uploadAvatar(String filePath) async {
    final api = ref.read(apiClientProvider);
    final id = state.value?.id;
    await api.dio.post(
      '/profile/avatar',
      data: FormData.fromMap({
        // Field name must match the backend's UploadFile parameter name exactly
        // (`file: UploadFile = File(...)` in profile.py) - FastAPI has no alias here.
        'file': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
      }),
    );
    // The cached avatar file is keyed by user id, not url - a new photo at the
    // same id would otherwise keep showing the old cached image for 7 days.
    if (id != null) {
      await RecordFileCacheManager.instance.removeFile('avatar_$id');
    }
    await refresh();
    // homeUserProvider hits a separately cached endpoint (`/users/me`) that also carries
    // the profile photo - without this it keeps showing the old picture on the home
    // screen until that HTTP cache entry happens to revalidate on its own.
    ref.invalidate(homeUserProvider);
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, FullProfileResponse>(
  ProfileNotifier.new,
);

// ── Preferences ───────────────────────────────────────────────────────────────

const _kPrefLanguage = 'pref_language';
const _kPrefDarkTheme = 'pref_is_dark_theme';

class PreferencesNotifier extends StateNotifier<PreferencesSchema> {
  PreferencesNotifier(this._ref) : super(const PreferencesSchema()) {
    _loadLocalThenRemote();
  }
  final Ref _ref;

  /// Reads the last-known preferences from `shared_preferences` first so the
  /// app never flashes hardcoded defaults on a cold, offline start, then
  /// refreshes from the backend (silently keeping the local value on failure).
  Future<void> _loadLocalThenRemote() async {
    final prefs = await SharedPreferences.getInstance();
    final localLang = prefs.getString(_kPrefLanguage);
    final localDark = prefs.getBool(_kPrefDarkTheme);
    if (localLang != null || localDark != null) {
      state = PreferencesSchema(
        language: localLang ?? state.language,
        isDarkTheme: localDark ?? state.isDarkTheme,
      );
    }
    try {
      final api = _ref.read(apiClientProvider);
      final res = await api.get<Map<String, dynamic>>(
          '/profile/preferences',
          cachePolicy: CachePolicy.refreshForceCache);
      if (res.data != null) {
        state = PreferencesSchema.fromJson(res.data!);
        await _persistLocally();
      }
    } catch (_) {
      // Offline / failed - keep whatever shared_preferences already gave us.
    }
  }

  Future<void> _persistLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefLanguage, state.language);
    await prefs.setBool(_kPrefDarkTheme, state.isDarkTheme);
  }

  Future<void> setLanguage(String lang) async {
    state = state.copyWith(language: lang);
    await _persistLocally();
    await _sync();
  }

  Future<void> setTheme(bool isDark) async {
    state = state.copyWith(isDarkTheme: isDark);
    await _persistLocally();
    await _sync();
  }

  Future<void> _sync() async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.put('/profile/preferences', data: state.toJson());
    } catch (_) {}
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, PreferencesSchema>((ref) {
  return PreferencesNotifier(ref);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final prefs = ref.watch(preferencesProvider);
  return prefs.isDarkTheme ? ThemeMode.dark : ThemeMode.light;
});

/// The `Locale` used for framework-level, RTL/native-locale-aware behaviour
/// (Material/Cupertino widget strings, text direction). Roman Urdu has no
/// real `Locale` of its own - it's Latin-script, so it intentionally maps to
/// `en` here for LTR layout. This is distinct from which of the 3 ARB string
/// sets a screen shows - see `appLocalizationsProvider`
/// (core/l10n/app_localizations_provider.dart), which is keyed off
/// `prefs.language` directly instead of this Locale.
final localeProvider = Provider<Locale>((ref) {
  final prefs = ref.watch(preferencesProvider);
  return prefs.language == 'ur' ? const Locale('ur') : const Locale('en');
});

// ── Privacy ───────────────────────────────────────────────────────────────────

class PrivacyNotifier extends AsyncNotifier<PrivacySchema> {
  @override
  Future<PrivacySchema> build() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.get<Map<String, dynamic>>('/profile/privacy',
          cachePolicy: CachePolicy.refreshForceCache);
      return PrivacySchema.fromJson(res.data ?? {});
    } catch (_) {
      return const PrivacySchema();
    }
  }

  Future<void> applyChanges(PrivacySchema schema) async {
    state = AsyncData(schema);
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/profile/privacy', data: schema.toJson());
    } catch (_) {}
  }
}

final privacyProvider =
    AsyncNotifierProvider<PrivacyNotifier, PrivacySchema>(PrivacyNotifier.new);

// ── Data Sharing ──────────────────────────────────────────────────────────────

class DataSharingNotifier extends AsyncNotifier<List<DataSharingSchema>> {
  @override
  Future<List<DataSharingSchema>> build() => _fetch();

  Future<List<DataSharingSchema>> _fetch() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get<List<dynamic>>('/profile/data-sharing',
        cachePolicy: CachePolicy.refreshForceCache);
    return (res.data ?? [])
        .map((e) => DataSharingSchema.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> revoke(String id) async {
    final api = ref.read(apiClientProvider);
    await api.delete('/profile/data-sharing/$id');
    final current = state.value ?? [];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }

  Future<void> add(DataSharingSchema entry) async {
    final api = ref.read(apiClientProvider);
    await api.post('/profile/data-sharing', data: entry.toJson());
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final dataSharingProvider =
    AsyncNotifierProvider<DataSharingNotifier, List<DataSharingSchema>>(
  DataSharingNotifier.new,
);
