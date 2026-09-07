import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/illustration_header.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/social_button.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithEmail(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Helpers.pushReplaceAll(context, '/home');
    } else if (auth.errorMessage != null) {
      Helpers.showSnackBar(context, auth.errorMessage!, isError: true);
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.googleLogin();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Helpers.pushReplaceAll(context, '/home');
    } else if (auth.errorMessage != null) {
      Helpers.showSnackBar(context, auth.errorMessage!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IllustrationHeader(
                    imagePath: AppStrings.emailSignupAsset,
                    height: MediaQuery.of(context).size.height * 0.30,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(AppStrings.emailLoginTitle,
                              style: AppTextStyles.screenTitle),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.emailLoginSubtitle,
                            style: AppTextStyles.subtitle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          CustomTextField(
                            label: 'Email',
                            hint: 'example@gmail.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Password',
                            hint: 'Enter password',
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            validator: (v) =>
                                Validators.required(v, 'Password'),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.secondaryText,
                              ),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Login',
                            onPressed: _isSubmitting ? null : _onLogin,
                            isLoading: _isSubmitting,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SocialButton(
                                  type: SocialButtonType.google,
                                  onPressed:
                                      _isSubmitting ? null : _onGoogleSignIn,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SocialButton(
                                  type: SocialButtonType.apple,
                                  onPressed: () => Helpers.showSnackBar(
                                      context, 'Apple login coming soon'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.subtitle,
                                children: [
                                  const TextSpan(
                                      text: '${AppStrings.newToCurecord} '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () =>
                                          Navigator.pushReplacementNamed(
                                              context, '/create-account'),
                                      child: Text(AppStrings.signUp,
                                          style: AppTextStyles.linkText),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSubmitting) const LoadingOverlay(),
          ],
        ),
      ),
    );
  }
}
