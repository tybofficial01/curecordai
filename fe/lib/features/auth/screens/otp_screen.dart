import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.purpose,
  });

  final String phoneNumber;

  /// 'registration' | 'login'
  final String purpose;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  int _resendSeconds = 29;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSeconds = 29;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  String get _countdownFormatted {
    final mins = (_resendSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_resendSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _verifyOtp() async {
    final t = ref.read(appLocalizationsProvider);
    if (_otp.length != 6) {
      setState(() => _error = t.otpIncompleteError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authProvider.notifier).verifyOtp(
            phoneNumber: widget.phoneNumber,
            otp: _otp,
            purpose: widget.purpose,
          );

      if (!mounted) return;

      final isNewUser = result['is_new_user'] == true;

      if (widget.purpose == 'registration') {
        if (isNewUser) {
          // New user - go straight to onboarding step 1, which will complete registration
          final token = result['otp_verified_token'] as String? ?? '';
          context.go('/auth/onboarding/step1', extra: token);
        } else {
          // Phone already registered - tell user to log in instead
          setState(() => _error = t.otpAlreadyRegisteredError);
        }
      } else {
        // purpose == 'login'
        if (isNewUser) {
          // Phone not found - ask them to sign up
          setState(() => _error = t.otpNotFoundError);
        } else {
          // Existing user - tokens already saved by verifyOtp
          context.go('/auth/success', extra: false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = t.otpInvalidError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    try {
      await ref.read(authProvider.notifier).sendOtp(
            phoneNumber: widget.phoneNumber,
            purpose: widget.purpose,
          );
      _startResendTimer();
    } catch (_) {
      setState(() => _error = ref.read(appLocalizationsProvider).otpResendFailedError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Illustration area - top 40%
            Expanded(
              flex: 40,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1F1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: AppTheme.primary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content - bottom 60%
            Expanded(
              flex: 60,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      t.otpVerifyTitle,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(text: t.otpSubtitlePrefix),
                          TextSpan(
                            text: widget.phoneNumber,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 6 OTP input boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 48,
                          height: 56,
                          child: TextFormField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: _controllers[index].text.isNotEmpty
                                      ? AppTheme.primary
                                      : AppTheme.cardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceVariant,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 5) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                              setState(() {});
                              if (_otp.length == 6) _verifyOtp();
                            },
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.error, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Resend row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _resendSeconds > 0 ? t.otpResendCodeIn : '',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (_resendSeconds > 0)
                          Text(
                            _countdownFormatted,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _resendSeconds == 0 ? _resendOtp : null,
                      child: Text(
                        t.otpResendSms,
                        style: TextStyle(
                          color: _resendSeconds == 0
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(t.otpVerify),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Terms footer
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        children: [
                          TextSpan(text: t.otpTermsPrefix),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {},
                              child: Text(
                                t.otpTermsLink,
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
