import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/google_signin_service.dart';

class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final t = ref.read(appLocalizationsProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).loginEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      context.go('/auth/success', extra: false);
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      final msg = (code == 401 || code == 422)
          ? t.authIncorrectEmailOrPassword
          : t.errorNoInternet;
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

  Future<void> _loginWithGoogle() async {
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
                        t.authEmailLoginTitle,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.authEmailLoginSubtitle,
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(t.authLogin),
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
                            onPressed: _isGoogleLoading ? null : _loginWithGoogle,
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
                              TextSpan(text: t.authNewToApp),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () =>
                                      context.push('/auth/create-account'),
                                  child: Text(
                                    t.authSignUp,
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
