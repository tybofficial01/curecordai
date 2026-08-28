import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';

class PhoneSignupScreen extends ConsumerStatefulWidget {
  const PhoneSignupScreen({super.key});

  @override
  ConsumerState<PhoneSignupScreen> createState() => _PhoneSignupScreenState();
}

class _PhoneSignupScreenState extends ConsumerState<PhoneSignupScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+92';
  bool _isLoading = false;

  static const _countryCodes = [
    '+92',
    '+1',
    '+44',
    '+91',
    '+971',
    '+966',
    '+49',
    '+33',
    '+61',
    '+86'
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final t = ref.read(appLocalizationsProvider);
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.validationPhoneRequired)),
      );
      return;
    }

    final fullPhone = '$_countryCode${phone.replaceAll(RegExp(r'[^0-9]'), '')}';
    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).post('/auth/otp/send', data: {
        'phone_number': fullPhone,
        'purpose': 'registration',
      });
      if (!mounted) return;
      context.push('/auth/otp-register', extra: fullPhone);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.statusCode == 409
          ? t.authPhoneAlreadyRegistered
          : t.otpSendFailedError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.otpSendFailedError)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                AppTheme.imagePath('enter_phone_number.png'),
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  width: double.infinity,
                  color: AppTheme.card,
                  child: Icon(Icons.image_outlined,
                      color: AppTheme.textMuted, size: 40),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
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
                      t.authPhoneSignupSubtitle,
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t.fieldPhoneNumber,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _countryCode,
                              dropdownColor: AppTheme.card,
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 14),
                              items: _countryCodes
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _countryCode = v!),
                              icon: Icon(Icons.expand_more,
                                  color: AppTheme.textSecondary, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(color: AppTheme.textPrimary),
                            decoration:
                                InputDecoration(hintText: t.hintPhoneNumber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(t.authSendOtp),
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}
