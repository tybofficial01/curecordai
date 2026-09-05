import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;
  String? token;
  UserModel? currentUser;

  bool _isSignup = true;

  // Onboarding data collected across steps
  String? fullName;
  String? yearOfBirth;
  String? gender;
  String? heightCm;
  String? weightKg;
  String? bloodGroup;
  String? allergies;
  List<String> selectedConditions = [];
  String? customConditions;

  final AuthService _authService;
  final StorageService _storageService;

static final _googleSignIn = GoogleSignIn(
  scopes: ['email'],
  serverClientId: '163511439914-1avrk8ab66oui774dkoqaqe38sl3uidu.apps.googleusercontent.com',
);


  AuthProvider(this._authService, this._storageService);

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    errorMessage = message;
    notifyListeners();
  }

  Future<bool> registerWithEmail(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final t = await _authService.registerWithEmail(email, password);
      await _storageService.saveToken(t);
      token = t;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      if (e.statusCode == 409) {
        _setError('An account with this email already exists. Log in instead?');
      } else if (e.statusCode == 422) {
        _setError('Please check your input and try again.');
      } else {
        _setError('Registration failed. Please try again.');
      }
      return false;
    } on NetworkException catch (e) {
      _setLoading(false);
      _setError(e.message);
      return false;
    } catch (_) {
      _setLoading(false);
      _setError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final t = await _authService.loginWithEmail(email, password);
      await _storageService.saveToken(t);
      token = t;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      if (e.statusCode == 401) {
        _setError('Incorrect email or password. Please try again.');
      } else if (e.statusCode == 404) {
        _setError('No account found with this email. Sign up instead?');
      } else {
        _setError('Login failed. Please try again.');
      }
      return false;
    } on NetworkException catch (e) {
      _setLoading(false);
      _setError(e.message);
      return false;
    } catch (_) {
      _setLoading(false);
      _setError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> sendPhoneOtp(String phoneNumber, {bool isSignup = true}) async {
    _isSignup = isSignup;
    _setLoading(true);
    _setError(null);
    try {
      await _authService.sendOtp(
          phoneNumber, isSignup ? 'registration' : 'login');
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      if (e.statusCode == 409) {
        _setError('This number is already registered. Try logging in.');
      } else if (e.statusCode == 404) {
        _setError('No account found with this number. Sign up instead?');
      } else {
        _setError('Failed to send OTP. Please try again.');
      }
      return false;
    } on NetworkException catch (e) {
      _setLoading(false);
      _setError(e.message);
      return false;
    } catch (_) {
      _setLoading(false);
      _setError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    _setLoading(true);
    _setError(null);
    try {
      final purpose = _isSignup ? 'registration' : 'login';
      final result = await _authService.verifyOtp(phoneNumber, otp, purpose);

      String? accessToken;
      if (_isSignup && result['is_new_user'] == true) {
        // New user - exchange otp_verified_token for real tokens
        final otpToken = result['otp_verified_token'] as String;
        accessToken = await _authService.registerWithPhone(otpToken, 'User');
      } else {
        accessToken = result['access_token'] as String?;
      }

      if (accessToken == null) {
        _setLoading(false);
        _setError('Verification failed. Please try again.');
        return false;
      }

      await _storageService.saveToken(accessToken);
      token = accessToken;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      if (e.statusCode == 400) {
        _setError('Incorrect code. Please try again.');
      } else if (e.statusCode == 429) {
        _setError('Too many attempts. Please request a new code.');
      } else {
        _setError('Verification failed. Please try again.');
      }
      return false;
    } on NetworkException catch (e) {
      _setLoading(false);
      _setError(e.message);
      return false;
    } catch (_) {
      _setLoading(false);
      _setError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> googleLogin() async {
    _setLoading(true);
    _setError(null);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _setLoading(false);
        return false; // User cancelled
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _setLoading(false);
        _setError('Google sign-in failed. Please try again.');
        return false;
      }
      final t = await _authService.googleLogin(idToken);
      await _storageService.saveToken(t);
      token = t;
      _setLoading(false);
      return true;
    } on NetworkException catch (e) {
      _setLoading(false);
      _setError(e.message);
      return false;
    } catch (_) {
      _setLoading(false);
      _setError('Google sign-in failed. Please try again.');
      return false;
    }
  }

  Future<bool> resendOtp(String phoneNumber) async {
    try {
      await _authService.resendOtp(
          phoneNumber, _isSignup ? 'registration' : 'login');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitOnboarding() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = <String, dynamic>{};
      if (fullName != null && fullName!.isNotEmpty)
        data['full_name'] = fullName;
      if (yearOfBirth != null && yearOfBirth!.isNotEmpty)
        data['year_of_birth'] = int.tryParse(yearOfBirth!);
      if (gender != null && gender!.isNotEmpty) data['gender'] = gender;
      if (heightCm != null && heightCm!.isNotEmpty)
        data['height_cm'] = double.tryParse(heightCm!);
      if (weightKg != null && weightKg!.isNotEmpty)
        data['weight_kg'] = double.tryParse(weightKg!);
      if (bloodGroup != null && bloodGroup!.isNotEmpty)
        data['blood_group'] = bloodGroup;
      if (allergies != null && allergies!.isNotEmpty)
        data['allergies'] = allergies;
      final conditions = [
        ...selectedConditions,
        if (customConditions != null && customConditions!.isNotEmpty)
          customConditions!,
      ];
      if (conditions.isNotEmpty) data['existing_conditions'] = conditions;
      await _authService.submitOnboarding(data);
      _setLoading(false);
      return true;
    } catch (_) {
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _storageService.clearAll();
    token = null;
    currentUser = null;
    fullName = null;
    yearOfBirth = null;
    gender = null;
    heightCm = null;
    weightKg = null;
    bloodGroup = null;
    allergies = null;
    selectedConditions = [];
    customConditions = null;
    notifyListeners();
  }

  Future<bool> checkAuthStatus() async {
    try {
      final hasToken = await _storageService.hasToken();
      if (!hasToken) return false;
      final user = await _authService.getMe();
      currentUser = user;
      notifyListeners();
      return true;
    } catch (_) {
      await _storageService.deleteToken();
      return false;
    }
  }
}
