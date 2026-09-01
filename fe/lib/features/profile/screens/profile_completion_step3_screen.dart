import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:curecordai/core/theme/app_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/step_shared_widgets.dart';

// Predefined condition values are kept as fixed English strings for storage
// (matching what's persisted on the backend) - only their on-screen label is
// localized. Mirrors `_conditionLabel` in profile_information_screen.dart.
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

class ProfileCompletionStep3Screen extends ConsumerStatefulWidget {
  const ProfileCompletionStep3Screen({super.key});

  @override
  ConsumerState<ProfileCompletionStep3Screen> createState() =>
      _ProfileCompletionStep3ScreenState();
}

class _ProfileCompletionStep3ScreenState
    extends ConsumerState<ProfileCompletionStep3Screen> {
  final _allergiesCtrl = TextEditingController();
  final _customConditionCtrl = TextEditingController();

  static const _predefinedConditions = [
    'Asthma',
    'Diabetes',
    'Epilepsy',
    'Hypertension',
    'Thyroid Issue',
  ];

  final Set<String> _selectedConditions = {};
  final List<String> _customConditions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _allergiesCtrl.dispose();
    _customConditionCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _isLoading = true);
    final t = ref.read(appLocalizationsProvider);
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/profile/health-details', data: {
        'allergies': _allergiesCtrl.text.trim(),
        'conditions': [..._selectedConditions, ..._customConditions],
      });
      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(t.profileCompletionSaveError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    final t = ref.read(appLocalizationsProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(t.profileCompletionSuccessTitle,
                style: AppFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              t.profileCompletionSuccessBody,
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/profile');
                },
                child: Text(t.profileCompletionGoToProfile,
                    style: AppFonts.manrope(
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomCondition() {
    final text = _customConditionCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _customConditions.add(text);
      _customConditionCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(step: 3, onHelp: _showHelp),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.profileCompletionAlmostThere,
                        style: AppFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      t.profileCompletionStep3Subtitle,
                      style: AppFonts.manrope(
                          fontSize: 15, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    FormCard(
                      children: [
                        FieldLabel(t.profileFieldAllergies),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _allergiesCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: t.profileHintAllergiesExample,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(t.profileCompletionSeparateWithCommas,
                            style: AppFonts.manrope(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        Divider(color: AppTheme.cardBorder),
                        const SizedBox(height: 16),
                        FieldLabel(t.profileFieldExistingConditions),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._predefinedConditions.map((c) => _ConditionChip(
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
                            ..._customConditions.map((c) => _ConditionChip(
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
                          controller: _customConditionCtrl,
                          decoration: InputDecoration(
                            hintText: t.profileHintAddOtherConditions,
                            suffixIcon: IconButton(
                              icon: Icon(Icons.add, color: AppTheme.primary),
                              onPressed: _addCustomCondition,
                            ),
                          ),
                          onFieldSubmitted: (_) => _addCustomCondition(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _TrustBadge(
                                icon: Icons.verified_user_outlined,
                                title: t.profileCompletionHipaaCompliant,
                                subtitle: t.profileCompletionSecureStorage)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _TrustBadge(
                                icon: Icons.enhanced_encryption_outlined,
                                title: t.profileCompletionEncrypted,
                                subtitle: t.profileCompletionPersonalData)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            StepBottomBar(
              step: 3,
              onNext: _isLoading ? () {} : _finish,
              nextEnabled: !_isLoading,
              nextLabel: _isLoading
                  ? t.profileCompletionSaving
                  : t.profileCompletionFinish,
            ),
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
            Text(t.profileCompletionStep3HelpTitle,
                style: AppFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              t.profileCompletionStep3HelpBody,
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

class _ConditionChip extends StatelessWidget {
  const _ConditionChip(
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
          color: selected ? AppTheme.primary : AppTheme.surface,
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
                    fontWeight: FontWeight.w500,
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

class _TrustBadge extends StatelessWidget {
  const _TrustBadge(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(height: 6),
          Text(title,
              style: AppFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          Text(subtitle,
              style: AppFonts.manrope(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
