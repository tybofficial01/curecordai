import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/google_signin_service.dart';

class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  ConsumerState<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends ConsumerState<EmailSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final t = ref.read(appLocalizationsProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).sendEmailOtp(email: email);
      if (!mounted) return;
      context.push(
        '/auth/email-otp-register',
        extra: {'fullName': fullName, 'email': email, 'password': password},
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      String msg;
      if (e.response?.statusCode == 409) {
        msg = t.authEmailAlreadyRegistered;
      } else if (body is Map && body['detail'] != null) {
        msg = body['detail'].toString();
      } else {
        msg = t.authSignUpFailed;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.errorNoInternet)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    final t = ref.read(appLocalizationsProvider);
    setState(() => _isGoogleLoading = true);
    try {
      final idToken = await GoogleSignInService.signInAndGetIdToken();
      if (idToken == null) return; // user cancelled
      final isNewUser =
          await ref.read(authProvider.notifier).loginGoogle(idToken);
      if (!mounted) return;
      context.go('/auth/success', extra: isNewUser);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.authGoogleSignInFailed)),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String? _validateName(String? v) {
    final t = ref.read(appLocalizationsProvider);
    if (v == null || v.trim().length < 2) return t.validationNameMinLength;
    return null;
  }

  String? _validateEmail(String? v) {
    final t = ref.read(appLocalizationsProvider);
    if (v == null || v.isEmpty) return t.validationEmailRequired;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
      return t.validationEmailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final t = ref.read(appLocalizationsProvider);
    if (v == null || v.isEmpty) return t.validationPasswordRequired;
    if (v.length < 8) return t.validationPasswordMin8;
    if (!RegExp(r'[A-Z]').hasMatch(v)) return t.validationPasswordUppercase;
    if (!RegExp(r'[0-9]').hasMatch(v)) return t.validationPasswordNumber;
    return null;
  }

  String? _validateConfirm(String? v) {
    final t = ref.read(appLocalizationsProvider);
    if (v != _passwordController.text) return t.validationPasswordsMismatch;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset(
                AppTheme.imagePath('email_signup.png'),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  width: double.infinity,
                  color: AppTheme.card,
                  child: Icon(Icons.image_outlined,
                      color: AppTheme.textMuted, size: 40),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.authCreateAccountTitle,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.authSignupSubtitle,
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      Text(
                        t.fieldFullName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: t.hintFullName,
                          prefixIcon: Icon(Icons.person_outline,
                              color: AppTheme.textSecondary, size: 20),
                        ),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      Text(
                        t.fieldEmail,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: t.hintEmail,
                          prefixIcon: Icon(Icons.email_outlined,
                              color: AppTheme.textSecondary, size: 20),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      Text(
                        t.fieldPassword,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: t.hintPassword,
                          prefixIcon: Icon(Icons.lock_outlined,
                              color: AppTheme.textSecondary, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      Text(
                        t.fieldConfirmPassword,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: t.hintConfirmPassword,
                          prefixIcon: Icon(Icons.lock_outlined,
                              color: AppTheme.textSecondary, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: _validateConfirm,
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(t.authSignUpButton),
                      ),
                      const SizedBox(height: 16),

                      Row(children: [
                        Expanded(child: Divider(color: AppTheme.cardBorder)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(t.commonOr,
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: AppTheme.cardBorder)),
                      ]),
                      const SizedBox(height: 16),

                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isGoogleLoading ? null : _signUpWithGoogle,
                            icon: _isGoogleLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.g_mobiledata, size: 22),
                            label: Text(
                                _isGoogleLoading ? t.authSigningIn : t.authGoogle),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppTheme.surface,
                              side: BorderSide(color: AppTheme.cardBorder),
                              minimumSize: const Size(0, 52),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.apple, size: 22),
                            label: Text(t.authApple),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppTheme.surface,
                              side: BorderSide(color: AppTheme.cardBorder),
                              minimumSize: const Size(0, 52),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 14, color: AppTheme.textSecondary),
                            children: [
                              TextSpan(text: t.authAlreadyHaveAccount),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => context.go('/auth/login'),
                                  child: Text(
                                    t.authLogIn,
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
