import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../ai_chat/screens/ai_chat_screen.dart';
import '../../emergency/screens/emergency_screen.dart';
import '../../family/providers/family_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../home/providers/dashboard_banner_provider.dart';
import '../../insights/providers/insights_provider.dart';
import '../../insights/screens/health_summary_screen.dart';
import '../../medications/providers/medications_provider.dart';
import '../../profile/providers/profile_providers.dart';
import '../../profile/screens/consent_management_screen.dart';
import '../../records/providers/records_provider.dart';
import '../../sharing/screens/share_screen.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? userId;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        errorMessage: errorMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState());

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  SecureStorageService get _storage => _ref.read(secureStorageProvider);

  Future<void> checkSession() async {
    final hasSession = await _storage.hasValidSession();
    state = state.copyWith(
      status:
          hasSession ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  Future<Map<String, dynamic>> sendOtp({
    required String phoneNumber,
    required String purpose,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.post('/auth/otp/send', data: {
        'phone_number': phoneNumber,
        'purpose': purpose,
      });
      state = state.copyWith(status: AuthStatus.initial);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otp,
    required String purpose,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.post('/auth/otp/verify', data: {
        'phone_number': phoneNumber,
        'otp': otp,
        'purpose': purpose,
      });
      final data = response.data as Map<String, dynamic>;

      if (data['access_token'] != null) {
        await _saveSession(data);
      }

      state = state.copyWith(status: AuthStatus.initial);
      return data;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<void> register({
    required String otpVerifiedToken,
    required String fullName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.post('/auth/register', data: {
        'otp_verified_token': otpVerifiedToken,
        'full_name': fullName,
      });
      await _saveSession(response.data as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendEmailOtp({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.post('/auth/otp/send-email', data: {
        'email': email,
      });
      state = state.copyWith(status: AuthStatus.initial);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<String> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.post('/auth/otp/verify-email', data: {
        'email': email,
        'otp': otp,
      });
      final data = response.data as Map<String, dynamic>;
      state = state.copyWith(status: AuthStatus.initial);
      return data['email_verified_token'] as String;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<void> registerEmail({
    required String fullName,
    required String email,
    required String password,
    required String emailVerifiedToken,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.post('/auth/register/email', data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'email_verified_token': emailVerifiedToken,
      });
      await _saveSession(response.data as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<void> loginEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.post('/auth/login/email', data: {
        'email': email,
        'password': password,
      });
      await _saveSession(response.data as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<bool> loginGoogle(String idToken) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response =
          await _api.post('/auth/oauth/google', data: {'id_token': idToken});
      final data = response.data as Map<String, dynamic>;
      await _saveSession(data);
      state = state.copyWith(status: AuthStatus.authenticated);
      return data['is_new_user'] as bool? ?? false;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _parseError(e));
      rethrow;
    }
  }

  Future<void> logout({bool allDevices = false}) async {
    final refreshToken = await _storage.getRefreshToken();
    final accessToken = await _storage.getAccessToken();

    // Log the user out locally right away - don't make them wait on a network
    // round trip to feel logged out.
    await _clearLocalSession();

    // Revoke the session server-side in the background. The access token is
    // passed explicitly since storage was just cleared and the auth
    // interceptor reads its token from storage, not from this closure.
    unawaited(_revokeSession(
      refreshToken: refreshToken,
      accessToken: accessToken,
      allDevices: allDevices,
    ));
  }

  /// Called by [_AuthInterceptor] when a 401 can't be recovered (refresh
  /// token also rejected) - the session is already dead server-side, so this
  /// does the same full local wipe as [logout] minus the (pointless) server
  /// revocation call.
  Future<void> handleSessionExpired() => _clearLocalSession();

  /// Security rule: wipe every cached health record on device on logout, or
  /// when the session dies from an unrecoverable 401. This clears the
  /// encrypted Hive-backed HTTP cache (records/family/profile/insights/
  /// consent), the downloaded file cache (PDFs/images/avatars), and
  /// invalidates the in-memory Riverpod state for the same data - so nothing
  /// from this session lingers if a different account logs in without
  /// restarting the app.
  Future<void> _clearLocalSession() async {
    await _storage.clearTokens();
    await _api.clearAllCache();
    await RecordFileCacheManager.instance.emptyCache();
    _invalidateCachedDataProviders();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _invalidateCachedDataProviders() {
    _ref.invalidate(recordsListProvider);
    _ref.invalidate(recordDetailProvider);
    _ref.invalidate(recordsByFamilyMemberProvider);
    _ref.invalidate(foldersProvider);
    _ref.invalidate(recordClinicalProvider);
    _ref.invalidate(recordFullProvider);
    _ref.invalidate(familyMembersProvider);
    _ref.invalidate(familyMemberDetailProvider);
    _ref.invalidate(healthSummaryProvider);
    _ref.invalidate(observationTrendProvider);
    _ref.invalidate(profileProvider);
    _ref.invalidate(privacyProvider);
    _ref.invalidate(dataSharingProvider);
    _ref.invalidate(consentSummaryProvider);
    _ref.invalidate(homeUserProvider);
    _ref.invalidate(recentRecordsProvider);
    _ref.invalidate(homeActiveAllergiesProvider);
    _ref.invalidate(activeMedicationsProvider);
    _ref.invalidate(recentChatSessionsProvider);
    _ref.invalidate(emergencySettingsProvider);
    _ref.invalidate(emergencyContactsProvider);
    _ref.invalidate(activeBloodGroupProvider);
    _ref.invalidate(emergencyActiveAllergiesProvider);
    _ref.invalidate(shareSessionsProvider);
    _ref.invalidate(sessionHistoryProvider);
    _ref.invalidate(healthOverviewProvider);
  }

  Future<void> _revokeSession({
    required String? refreshToken,
    required String? accessToken,
    required bool allDevices,
  }) async {
    try {
      await _api.post(
        '/auth/logout',
        data: {'refresh_token': refreshToken, 'all_devices': allDevices},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (_) {
      // Best-effort - local session is already cleared regardless.
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final user = data['user'] as Map<String, dynamic>?;

    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    if (user != null) {
      await _storage.saveUserId(user['id'] as String);
    }
  }

  String _parseError(Object e) {
    if (e is Exception) return e.toString();
    return _ref.read(appLocalizationsProvider).commonErrorOccurred;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
