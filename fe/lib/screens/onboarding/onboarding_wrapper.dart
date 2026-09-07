import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/progress_step_bar.dart';
import '../../widgets/secondary_button.dart';
import 'almost_there_screen.dart';
import 'physical_metrics_screen.dart';
import 'tell_us_about_yourself_screen.dart';

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  int _currentStep = 1;
  bool _isSubmitting = false;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  bool _validateCurrentStep() {
    if (_currentStep == 1) {
      return _step1FormKey.currentState?.validate() ?? false;
    }
    if (_currentStep == 2) {
      return _step2FormKey.currentState?.validate() ?? true;
    }
    return true; // Step 3 has no required validation
  }

  void _onNext() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _onPrevious() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  Future<void> _onFinish() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.submitOnboarding();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!success) {
      Helpers.showSnackBar(
        context,
        'Could not save your profile. You can update it later in settings.',
        isError: true,
      );
    }
    Helpers.pushReplaceAll(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildCurrentStep()),
                  _buildNavButtons(),
                ],
              ),
              if (_isSubmitting) const LoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Step $_currentStep of 3',
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryTeal),
                ),
                alignment: Alignment.center,
                child: Text(
                  '?',
                  style: AppFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressStepBar(currentStep: _currentStep),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return TellUsAboutYourselfScreen(formKey: _step1FormKey);
      case 2:
        return PhysicalMetricsScreen(formKey: _step2FormKey);
      case 3:
        return const AlmostThereScreen();
      default:
        return TellUsAboutYourselfScreen(formKey: _step1FormKey);
    }
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          if (_currentStep == 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _onFinish,
                child: Text(
                  AppStrings.skipForNow,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.secondaryText),
                ),
              ),
            ),
          if (_currentStep == 2)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _onNext,
                child: Text(
                  AppStrings.skipForNow,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.secondaryText),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: AppStrings.previous,
                  onPressed: _currentStep > 1 ? _onPrevious : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label:
                      _currentStep == 3 ? AppStrings.finish : AppStrings.next,
                  onPressed: _isSubmitting
                      ? null
                      : (_currentStep == 3 ? _onFinish : _onNext),
                  isLoading: _isSubmitting && _currentStep == 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
