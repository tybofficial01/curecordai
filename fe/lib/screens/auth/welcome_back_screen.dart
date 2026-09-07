import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/illustration_header.dart';
import '../../widgets/secondary_button.dart';

class WelcomeBackScreen extends StatelessWidget {
  const WelcomeBackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: _HelpIcon(),
                ),
              ),
              IllustrationHeader(
                imagePath: AppStrings.signupOptionsAsset,
                height: MediaQuery.of(context).size.height * 0.42,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(AppStrings.welcomeBack,
                        style: AppTextStyles.screenTitle),
                    const SizedBox(height: 8),
                    Text(AppStrings.welcomeBackSubtitle,
                        style: AppTextStyles.subtitle),
                    const SizedBox(height: 32),
                    SecondaryButton(
                      label: AppStrings.continueWithPhone,
                      onPressed: () =>
                          Navigator.pushNamed(context, '/phone-login'),
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: AppStrings.continueWithEmail,
                      onPressed: () =>
                          Navigator.pushNamed(context, '/email-login'),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.subtitle,
                          children: [
                            const TextSpan(
                                text: '${AppStrings.newToCurecord} '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => Navigator.pushReplacementNamed(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryTeal),
        color: AppColors.background,
      ),
      alignment: Alignment.center,
      child: Text(
        '?',
        style: AppFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryTeal,
        ),
      ),
    );
  }
}
