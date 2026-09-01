import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../emergency/screens/emergency_screen.dart' show emergencyActiveAllergiesProvider;
import '../../home/screens/home_screen.dart' show homeActiveAllergiesProvider;
import '../../insights/providers/insights_provider.dart' show healthSummaryProvider;
import '../providers/profile_providers.dart';
import '../utils/avatar_crop.dart';
import '../widgets/step_shared_widgets.dart';

// Predefined condition values are kept as fixed English strings for storage/state
// (matching what's persisted on the backend) - only their on-screen label is localized.
String _conditionLabel(AppLocalizations t, String condition) {
  switch (condition) {
    case 'Asthma':
      return t.profileConditionAsthma;
    case 'Diabetes':
      return t.profileConditionDiabetes;
    case 'Epilepsy':
      return t.profileConditionEpilepsy;
    case 'Hypertension':
      return t.profileConditionHypertension;
    case 'Thyroid Issue':
      return t.profileConditionThyroidIssue;
    default:
      return condition;
  }
}

// The gender dropdown's stored values ('Male', 'Female', 'Other',
// 'Prefer not to say') are kept as fixed English strings (matching what
// `_save()` sends the backend) - only the on-screen label is localized.
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

class ProfileInformationScreen extends ConsumerStatefulWidget {
  const ProfileInformationScreen({super.key});

  @override
  ConsumerState<ProfileInformationScreen> createState() =>
      _ProfileInformationScreenState();
}

class _ProfileInformationScreenState
    extends ConsumerState<ProfileInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _customCondCtrl = TextEditingController();

  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  String _countryCode = '+92';
  final Set<String> _selectedConditions = {};
  final List<String> _customConditions = [];
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  bool _initialized = false;

  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-'
  ];
  static const _predefined = [
    'Asthma',
    'Diabetes',
    'Epilepsy',
    'Hypertension',
    'Thyroid Issue'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _allergiesCtrl.dispose();
    _customCondCtrl.dispose();
    super.dispose();
  }

  // Maps backend-normalised gender ("male", "female", "unknown") to dropdown display values.
  String? _displayGender(String? g) {
    switch (g) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'unknown':
        return 'Prefer not to say';
      default:
        return null;
    }
  }

  void _prefill(dynamic profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = profile.fullName ?? '';
    // profile.phoneNumber is the full E.164 number (already including the country code) -
    // strip that prefix here since _save() re-adds _countryCode when submitting. Leaving the
    // full number in this field would double it up into "+92+923018761445" on save.
    final phone = profile.phoneNumber ?? '';
    _phoneCtrl.text =
        phone.startsWith(_countryCode) ? phone.substring(_countryCode.length) : phone;
    _heightCtrl.text = profile.heightCm?.toString() ?? '';
    _weightCtrl.text = profile.weightKg?.toString() ?? '';
    _allergiesCtrl.text = profile.allergies ?? '';
    _gender = _displayGender(profile.gender);
    _bloodGroup = profile.bloodGroup;
    if (profile.dateOfBirth != null) {
      try {
        _dob = DateFormat('yyyy-MM-dd').parse(profile.dateOfBirth!);
      } catch (_) {}
    }
    for (final c in profile.conditions) {
      if (_predefined.contains(c)) {
        _selectedConditions.add(c);
      } else {
        _customConditions.add(c);
      }
    }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/profile', data: {
        'full_name': _nameCtrl.text.trim(),
        'date_of_birth':
            _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
        'gender': _gender,
        'phone_number': '$_countryCode${_phoneCtrl.text.trim()}',
      });
      await api.put('/profile/physical-metrics', data: {
        'height_cm': double.tryParse(_heightCtrl.text.trim()),
        'weight_kg': double.tryParse(_weightCtrl.text.trim()),
        'blood_group': _bloodGroup,
      });
      await api.put('/profile/health-details', data: {
        'allergies': _allergiesCtrl.text.trim(),
        'conditions': [..._selectedConditions, ..._customConditions],
      });
      ref.read(profileProvider.notifier).refresh();
      // These allergy summaries are plain FutureProviders (not autoDispose), so
      // without an explicit invalidate here they would keep showing whatever
      // was fetched before this edit for the rest of the app session.
      ref.invalidate(homeActiveAllergiesProvider);
      ref.invalidate(healthSummaryProvider);
      ref.invalidate(emergencyActiveAllergiesProvider);
      if (mounted) {
        final t = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.profileUpdatedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final t = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.profileUpdateErrorWith(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    if (!mounted) return;
    final croppedPath = await cropAvatarImage(
      context,
      file.path,
      title: ref.read(appLocalizationsProvider).profileCropPhotoTitle,
    );
    if (croppedPath == null) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final api = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        // Must match the backend's UploadFile parameter name exactly
        // (`file: UploadFile = File(...)` in profile.py) - no alias is set there.
        'file':
            await MultipartFile.fromFile(croppedPath, filename: 'avatar.jpg'),
      });
      await api.dio.post('/profile/avatar', data: formData);
      await ref.read(profileProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        final t = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.profileFailedUpdatePicture)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _addCustomCondition() {
    final text = _customCondCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _customConditions.add(text);
      _customCondCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.profileInformationTitle,
            style: AppFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: profileAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text(t.profileFailedToLoadWith(e.toString()))),
        data: (profile) {
          _prefill(profile);
          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _isUploadingAvatar ? null : _pickAvatar,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor: AppTheme.primary,
                                  backgroundImage: profile.profilePhotoUrl !=
                                          null
                                      ? CachedNetworkImageProvider(
                                          profile.profilePhotoUrl!,
                                          cacheKey: 'avatar_${profile.id}',
                                          cacheManager:
                                              RecordFileCacheManager.instance,
                                        )
                                      : null,
                                  child: profile.profilePhotoUrl == null
                                      ? Text(
                                          (profile.fullName ?? 'U')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: AppFonts.manrope(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700),
                                        )
                                      : null,
                                ),
                                if (_isUploadingAvatar)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2)),
                                    child: const Icon(Icons.edit,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _Section(label: t.profileSectionPersonalDetailsLabel, children: [
                          FieldLabel(t.profileFieldFullName),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                                hintText: t.profileHintFullName),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? t.profileValidationRequired
                                : null,
                          ),
                          const SizedBox(height: 14),
                          FieldLabel(t.profileFieldDob),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              height: 56,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                border: Border.all(color: AppTheme.cardBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _dob != null
                                          ? DateFormat('dd / MM / yyyy')
                                              .format(_dob!)
                                          : t.profileDobPlaceholder,
                                      style: AppFonts.manrope(
                                          color: _dob != null
                                              ? AppTheme.textPrimary
                                              : AppTheme.textMuted,
                                          fontSize: 14),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today_outlined,
                                      color: AppTheme.textSecondary, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 14),
                          FieldLabel(t.profileFieldPhoneNumber),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  border: Border.all(color: AppTheme.cardBorder),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CountryCodePicker(
                                  onChanged: (code) => setState(() =>
                                      _countryCode = code.dialCode ?? '+92'),
                                  initialSelection: 'PK',
                                  showFlag: true,
                                  showDropDownButton: true,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  textStyle: AppFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      hintText: '000-000-0000'),
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _Section(label: t.profileSectionPhysicalMetricsLabel, children: [
                          FieldLabel(t.profileFieldHeightCm),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _heightCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                InputDecoration(hintText: t.profileHintHeightExample),
                          ),
                          const SizedBox(height: 14),
                          FieldLabel(t.profileFieldWeightKg),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                hintText: t.profileHintWeightExample, suffixText: 'kg'),
                          ),
                          const SizedBox(height: 14),
                          FieldLabel(t.profileFieldBloodGroupLabel),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _bloodGroup,
                            decoration: InputDecoration(
                                hintText: t.profileHintSelectBloodGroup),
                            items: _bloodGroups
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setState(() => _bloodGroup = v),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _Section(label: t.profileSectionHealthDetailsLabel, children: [
                          FieldLabel(t.profileFieldAllergies),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _allergiesCtrl,
                            minLines: 3,
                            maxLines: 5,
                            decoration: InputDecoration(
                                hintText: t.profileHintAllergiesExample),
                          ),
                          const SizedBox(height: 14),
                          FieldLabel(t.profileFieldExistingConditions),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._predefined.map((c) => _Chip(
                                    label: _conditionLabel(t, c),
                                    selected: _selectedConditions.contains(c),
                                    onTap: () => setState(() {
                                      if (_selectedConditions.contains(c)) {
                                        _selectedConditions.remove(c);
                                      } else {
                                        _selectedConditions.add(c);
                                      }
                                    }),
                                  )),
                              ..._customConditions.map((c) => _Chip(
                                    label: c,
                                    selected: true,
                                    isCustom: true,
                                    onTap: () => setState(
                                        () => _customConditions.remove(c)),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _customCondCtrl,
                            decoration: InputDecoration(
                              hintText: t.profileHintAddOtherConditions,
                              suffixIcon: IconButton(
                                icon: Icon(Icons.add, color: AppTheme.primary),
                                onPressed: _addCustomCondition,
                              ),
                            ),
                            onFieldSubmitted: (_) => _addCustomCondition(),
                          ),
                        ]),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(t.profileSaveChangesButton,
                              style: AppFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.manrope(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.isCustom = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.card,
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.cardBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppFonts.manrope(
                    fontSize: 13,
                    color: selected ? Colors.white : AppTheme.textSecondary)),
            const SizedBox(width: 4),
            Icon(isCustom ? Icons.close : (selected ? Icons.check : Icons.add),
                size: 14,
                color: selected ? Colors.white : AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
