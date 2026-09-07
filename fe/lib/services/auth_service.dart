import 'dart:convert';
import 'api_service.dart';
import '../models/user_model.dart';

class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<String> registerWithEmail(String email, String password) async {
    final response = await _api.post('/auth/register/email', {
      'email': email.trim(),
      'password': password,
      'full_name': 'User',
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<String> loginWithEmail(String email, String password) async {
    final response = await _api.post('/auth/login/email', {
      'email': email.trim(),
      'password': password,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> sendOtp(
      String phoneNumber, String purpose) async {
    final response = await _api.post('/auth/otp/send', {
      'phone_number': phoneNumber,
      'purpose': purpose,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> verifyOtp(
      String phoneNumber, String otp, String purpose) async {
    final response = await _api.post('/auth/otp/verify', {
      'phone_number': phoneNumber,
      'otp': otp,
      'purpose': purpose,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<String> registerWithPhone(
      String otpVerifiedToken, String fullName) async {
    final response = await _api.post('/auth/register', {
      'otp_verified_token': otpVerifiedToken,
      'full_name': fullName,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<String> googleLogin(String idToken) async {
    final response = await _api.post('/auth/google', {'id_token': idToken});
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<void> resendOtp(String phoneNumber, String purpose) async {
    final response = await _api.post('/auth/otp/send', {
      'phone_number': phoneNumber,
      'purpose': purpose,
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  Future<bool> submitOnboarding(Map<String, dynamic> data) async {
    final response = await _api.postAuth('/users/onboarding', data);
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<UserModel> getMe() async {
    final response = await _api.get('/users/me');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(data);
    }
    throw ApiException(response.statusCode, response.body);
  }
}
