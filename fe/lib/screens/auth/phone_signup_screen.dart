import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/illustration_header.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/phone_input_field.dart';
import '../../widgets/primary_button.dart';

class PhoneSignupScreen extends StatefulWidget {
  const PhoneSignupScreen({super.key});

  @override
  State<PhoneSignupScreen> createState() => _PhoneSignupScreenState();
}

class _PhoneSignupScreenState extends State<PhoneSignupScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+92';
  String? _phoneError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    if (_isSubmitting) return;
    final phoneError = Validators.phone(_phoneController.text);
    setState(() => _phoneError = phoneError);
    if (phoneError != null) return;

    final phoneNumber =
        Helpers.formatPhoneNumber(_countryCode, _phoneController.text);
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.sendPhoneOtp(phoneNumber, isSignup: true);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Navigator.pushNamed(
        context,
        '/otp-verify',
        arguments: {'phoneNumber': phoneNumber, 'isSignup': true},
      );
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
                    imagePath: AppStrings.enterPhoneAsset,
                    height: MediaQuery.of(context).size.height * 0.35,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(AppStrings.phoneSignupTitle,
                            style: AppTextStyles.screenTitle),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.phoneSignupSubtitle,
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        PhoneInputField(
                          controller: _phoneController,
                          onCountryChanged: (code) =>
                              setState(() => _countryCode = code),
                          errorText: _phoneError,
                        ),
                        const SizedBox(height: 32),
                        PrimaryButton(
                          label: AppStrings.sendOtp,
                          onPressed: _isSubmitting ? null : _onSendOtp,
                          isLoading: _isSubmitting,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.subtitle,
                              children: [
                                const TextSpan(
                                    text: '${AppStrings.alreadyHaveAccount} '),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pushReplacementNamed(
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
