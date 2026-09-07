import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/illustration_header.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/otp_input_field.dart';
import '../../widgets/primary_button.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.phoneNumber,
    required this.isSignup,
  });

  final String phoneNumber;
  final bool isSignup;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  String _otp = '';
  bool _hasError = false;
  bool _isSubmitting = false;
  bool _resendDisabled = true;
  bool _verifyDisabled = false;
  int _countdown = 29;
  Timer? _timer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));
    _startTimer();
  }

  void _startTimer() {
    _countdown = 29;
    _resendDisabled = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _resendDisabled = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String _formatCountdown() {
    final seconds = _countdown.toString().padLeft(2, '0');
    return '00:$seconds';
  }

  Future<void> _onVerify() async {
    if (_isSubmitting || _verifyDisabled) return;
    if (_otp.length < 6) {
      Helpers.showSnackBar(context, 'Please enter the complete 6-digit code',
          isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _hasError = false;
    });

    // TODO: Replace with real OTP verification via SMS API when credits available
    // Hardcoded: accept 123456 as valid OTP
    if (_otp == '123456') {
      final auth = context.read<AuthProvider>();
      final success = await auth.verifyOtp(widget.phoneNumber, _otp);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (success) {
        if (widget.isSignup) {
          Navigator.pushReplacementNamed(context, '/onboarding');
        } else {
          Helpers.pushReplaceAll(context, '/home');
        }
      } else {
        _onWrongOtp(auth.errorMessage);
      }
      return;
    }

    // Non-hardcoded path - real API
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(widget.phoneNumber, _otp);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      if (widget.isSignup) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      } else {
        Helpers.pushReplaceAll(context, '/home');
      }
    } else {
      if (auth.errorMessage?.contains('Too many') == true) {
        setState(() => _verifyDisabled = true);
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) setState(() => _verifyDisabled = false);
        });
      }
      _onWrongOtp(auth.errorMessage);
    }
  }

  void _onWrongOtp(String? message) {
    setState(() {
      _hasError = true;
      _otp = '';
    });
    _otpController.clear();
    _shakeController.forward(from: 0);
    if (message != null) {
      Helpers.showSnackBar(context, message, isError: true);
    }
  }

  Future<void> _onResend() async {
    if (_resendDisabled) return;
    final auth = context.read<AuthProvider>();
    await auth.resendOtp(widget.phoneNumber);
    if (!mounted) return;
    _startTimer();
    Helpers.showSnackBar(context, 'Code resent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IllustrationHeader(
                    imagePath: AppStrings.otpVerificationAsset,
                    height: MediaQuery.of(context).size.height * 0.30,
                  ),
                  const SizedBox(height: 16),
                  Text(AppStrings.otpTitle, style: AppTextStyles.screenTitle),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTextStyles.subtitle,
                      children: [
                        const TextSpan(text: '${AppStrings.otpSubtitle} '),
                        TextSpan(
                          text: widget.phoneNumber,
                          style: AppTextStyles.subtitle
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          sin(_shakeAnimation.value * pi / 180) * 10,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: OtpInputField(
                      controller: _otpController,
                      onCompleted: (value) {
                        setState(() => _otp = value);
                        _onVerify();
                      },
                      onChanged: (value) => setState(() {
                        _otp = value;
                        _hasError = false;
                      }),
                      hasError: _hasError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Resend code in ${_formatCountdown()}',
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _resendDisabled ? null : _onResend,
                    child: Text(
                      AppStrings.resendSms,
                      style: AppFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _resendDisabled
                            ? AppColors.placeholder
                            : AppColors.primaryTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: AppStrings.verify,
                    onPressed:
                        (_isSubmitting || _verifyDisabled) ? null : _onVerify,
                    isLoading: _isSubmitting,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.caption,
                        children: [
                          const TextSpan(text: 'By continuing you agree to '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {},
                              child: Text('Terms',
                                  style: AppTextStyles.linkText
                                      .copyWith(fontSize: 12)),
                            ),
                          ),
                          const TextSpan(text: ' & '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {},
                              child: Text('Privacy Policy',
                                  style: AppTextStyles.linkText
                                      .copyWith(fontSize: 12)),
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
            if (_isSubmitting) const LoadingOverlay(),
          ],
        ),
      ),
    );
  }
}
