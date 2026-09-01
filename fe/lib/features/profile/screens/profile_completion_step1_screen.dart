import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/step_shared_widgets.dart';

// The gender dropdown's stored values ('Male', 'Female', 'Other',
// 'Prefer not to say') are kept as fixed English strings (matching what
// step 1 persists) - only the on-screen label is localized.
String _genderLabel(AppLocalizations t, String gender) {
  switch (gender) {
    case 'Male':
      return t.genderMale;
    case 'Female':
      return t.genderFemale;
    case 'Other':
      return t.genderOther;
    case 'Prefer not to say':
      return t.genderPreferNotToSay;
    default:
      return gender;
  }
}

class ProfileCompletionStep1Screen extends ConsumerStatefulWidget {
  const ProfileCompletionStep1Screen({super.key});

  @override
  ConsumerState<ProfileCompletionStep1Screen> createState() =>
      _ProfileCompletionStep1ScreenState();
}

class _ProfileCompletionStep1ScreenState
    extends ConsumerState<ProfileCompletionStep1Screen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _submitted = false;

  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _dob != null &&
      _gender != null &&
      _phoneCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _next() {
    setState(() => _submitted = true);
    if (!_isValid) return;
    context.push('/profile-completion/step2');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(step: 1, onHelp: _showHelp),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.profileCompletionPersonalDetailsTitle,
                        style: AppFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text(t.profileCompletionPersonalDetailsSubtitle,
                        style: AppFonts.manrope(
                            fontSize: 15, color: AppTheme.textSecondary)),
                    const SizedBox(height: 24),
                    FormCard(
                      children: [
                        FieldLabel(t.profileFieldFullName),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                              hintText: t.profileHintFullName),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_submitted && _nameCtrl.text.trim().isEmpty)
                          FieldErrorText(t.profileCompletionFullNameRequired),
                        const SizedBox(height: 16),
                        FieldLabel(t.profileFieldDob),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              border: Border.all(
                                color: _submitted && _dob == null
                                    ? AppTheme.error
                                    : AppTheme.cardBorder,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _dob != null
                                        ? DateFormat('dd / MM / yyyy')
                                            .format(_dob!)
                                        : t.profileCompletionDobFormat,
                                    style: AppFonts.manrope(
                                      color: _dob != null
                                          ? AppTheme.textPrimary
                                          : AppTheme.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Icon(Icons.calendar_today_outlined,
                                    color: AppTheme.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        if (_submitted && _dob == null)
                          FieldErrorText(t.profileCompletionDobRequired),
                        const SizedBox(height: 16),
                        FieldLabel(t.profileFieldGender),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: InputDecoration(
                              hintText: t.profileHintSelectGender),
                          items: _genders
                              .map((g) => DropdownMenuItem(
                                  value: g, child: Text(_genderLabel(t, g))))
                              .toList(),
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                        if (_submitted && _gender == null)
                          FieldErrorText(t.profileCompletionGenderRequired),
                        const SizedBox(height: 16),
                        FieldLabel(t.profileFieldPhoneNumber),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                border: Border.all(color: AppTheme.cardBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CountryCodePicker(
                                onChanged: (_) {},
                                initialSelection: 'PK',
                                showFlag: true,
                                showDropDownButton: true,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                textStyle: AppFonts.manrope(
                                    fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                    hintText: t.profileCompletionPhoneHint),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        if (_submitted && _phoneCtrl.text.trim().isEmpty)
                          FieldErrorText(t.profileCompletionPhoneRequired),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        border: Border(
                            left:
                                BorderSide(color: AppTheme.primary, width: 3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t.profileCompletionStep1Note,
                        style: AppFonts.manrope(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            StepBottomBar(
                step: 1,
                onNext: _next,
                nextEnabled: true,
                nextLabel: t.profileCompletionNext),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    final t = ref.read(appLocalizationsProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.profileCompletionStep1HelpTitle,
                style: AppFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              t.profileCompletionStep1HelpBody,
              style: AppFonts.manrope(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
