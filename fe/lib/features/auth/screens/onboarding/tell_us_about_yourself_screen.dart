import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';

class TellUsAboutYourselfScreen extends ConsumerStatefulWidget {
  const TellUsAboutYourselfScreen({super.key, this.otpVerifiedToken});

  /// Non-null when arriving from the phone signup OTP flow.
  /// Step 1 will call /auth/register with this token before proceeding.
  final String? otpVerifiedToken;

  @override
  ConsumerState<TellUsAboutYourselfScreen> createState() =>
      _TellUsAboutYourselfScreenState();
}

class _TellUsAboutYourselfScreenState
    extends ConsumerState<TellUsAboutYourselfScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  String? _gender;
  bool _isLoading = false;
  String? _error;

  List<(String, String)> _genderOptions() {
    final t = ref.read(appLocalizationsProvider);
    return [
      (t.genderMale, 'male'),
      (t.genderFemale, 'female'),
      (t.genderOther, 'other'),
      (t.genderPreferNotToSay, 'unknown'),
    ];
  }

  @override
  void initState() {
    super.initState();
    final prefilled = ref.read(onboardingDataProvider).fullName;
    if (prefilled != null && prefilled.isNotEmpty) {
      _nameController.text = prefilled;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final t = ref.read(appLocalizationsProvider);
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final year = int.parse(_yearController.text.trim());

    // Phone signup: complete registration before moving on
    if (widget.otpVerifiedToken != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        await ref.read(authProvider.notifier).register(
              otpVerifiedToken: widget.otpVerifiedToken!,
              fullName: name,
            );
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = t.authRegistrationFailed;
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    ref.read(onboardingDataProvider.notifier).updateStep1(
          fullName: name,
          yearOfBirth: year,
          gender: _gender!,
        );
    context.push('/auth/onboarding/step2');
  }

  String? _validateName(String? v) {
    final t = ref.read(appLocalizationsProvider);
    if (v == null || v.trim().length < 2) return t.validationNameMinLength;
    return null;
  }

  String? _validateYear(String? v) {
    final t = ref.read(appLocalizationsProvider);
    if (v == null || v.isEmpty) return t.validationYearRequired;
    final year = int.tryParse(v);
    final now = DateTime.now().year;
    if (year == null || v.length != 4) return t.validationYearInvalid;
    if (year < 1900 || year > now) return t.validationYearRange(now);
    if (now - year < 13) return t.validationMinAge13;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.onboardingStep1Of3,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.help_outline, color: AppTheme.textSecondary),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: i == 0 ? AppTheme.primary : AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: AppTheme.surfaceVariant,
                        child: Image.asset(
                          AppTheme.imagePath('success_illustration.png'),
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t.onboardingTellUsTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.onboardingTellUsSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      _FieldLabel(t.fieldFullNameRequired),
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
                      _FieldLabel(t.fieldYearOfBirthRequired),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: t.hintYearOfBirth,
                          counterText: '',
                          prefixIcon: Icon(Icons.calendar_today_outlined,
                              color: AppTheme.textSecondary, size: 20),
                        ),
                        validator: _validateYear,
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel(t.fieldGenderRequired),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          hintText: t.hintSelectGender,
                          prefixIcon: Icon(Icons.person_2_outlined,
                              color: AppTheme.textSecondary, size: 20),
                        ),
                        items: _genderOptions()
                            .map((g) => DropdownMenuItem(
                                value: g.$2, child: Text(g.$1)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v),
                        validator: (v) =>
                            v == null ? t.validationGenderRequired : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: AppTheme.error, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      child: Text(t.commonPrevious),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _next,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : Text(t.commonNext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
