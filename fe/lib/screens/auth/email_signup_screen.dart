import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/illustration_header.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/social_button.dart';

class EmailSignupScreen extends StatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.registerWithEmail(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Navigator.pushReplacementNamed(context, '/onboarding');
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
      Navigator.pushReplacementNamed(context, '/onboarding');
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
                          Text(AppStrings.emailSignupTitle,
                              style: AppTextStyles.screenTitle),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.emailSignupSubtitle,
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
                            validator: Validators.password,
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
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Confirm Password',
                            hint: 'Re-enter password',
                            controller: _confirmPasswordController,
                            obscureText: !_showConfirmPassword,
                            validator: (v) => Validators.confirmPassword(
                                v, _passwordController.text),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.secondaryText,
                              ),
                              onPressed: () => setState(() =>
                                  _showConfirmPassword = !_showConfirmPassword),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Sign up',
                            onPressed: _isSubmitting ? null : _onSignUp,
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
                                      text:
                                          '${AppStrings.alreadyHaveAccount} '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () =>
                                          Navigator.pushReplacementNamed(
                                              context, '/welcome-back'),
                                      child: Text(AppStrings.logIn,
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
