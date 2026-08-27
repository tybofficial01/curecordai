import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/l10n/app_localizations_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../emergency/screens/emergency_screen.dart' show emergencyActiveAllergiesProvider;
import '../../../home/screens/home_screen.dart' show homeActiveAllergiesProvider;
import '../../../insights/providers/insights_provider.dart' show healthSummaryProvider;
import '../../providers/onboarding_provider.dart';

class AlmostThereScreen extends ConsumerStatefulWidget {
  const AlmostThereScreen({super.key});

  @override
  ConsumerState<AlmostThereScreen> createState() => _AlmostThereScreenState();
}

class _AlmostThereScreenState extends ConsumerState<AlmostThereScreen> {
  final _allergiesController = TextEditingController();
  final _otherConditionController = TextEditingController();
  bool _isLoading = false;

  /// The stored/API value stays English; only the chip label is localized.
  static const _conditions = [
    'Asthma',
    'Diabetes',
    'Epilepsy',
    'Hypertension',
    'Thyroid Issue',
  ];

  String _conditionLabel(String value) {
    final t = ref.read(appLocalizationsProvider);
    switch (value) {
      case 'Asthma':
        return t.conditionAsthma;
      case 'Diabetes':
        return t.conditionDiabetes;
      case 'Epilepsy':
        return t.conditionEpilepsy;
      case 'Hypertension':
        return t.conditionHypertension;
      case 'Thyroid Issue':
        return t.conditionThyroidIssue;
      default:
        return value;
    }
  }
  final Set<String> _selectedConditions = {};

  @override
  void dispose() {
    _allergiesController.dispose();
    _otherConditionController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final t = ref.read(appLocalizationsProvider);
    final data = ref.read(onboardingDataProvider);
    final allConditions = [
      ..._selectedConditions,
      if (_otherConditionController.text.trim().isNotEmpty)
        _otherConditionController.text.trim(),
    ];

    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).post('/users/onboarding', data: {
        'full_name': data.fullName,
        'year_of_birth': data.yearOfBirth,
        'gender': data.gender,
        if (data.heightCm != null) 'height_cm': data.heightCm,
        if (data.weightKg != null) 'weight_kg': data.weightKg,
        if (data.bloodGroup != null) 'blood_group': data.bloodGroup,
        'allergies': _allergiesController.text.trim(),
        'existing_conditions': allConditions,
      });
      // These allergy summaries are plain FutureProviders (not autoDispose), so
      // without an explicit invalidate here they would keep showing whatever
      // was fetched (usually empty, from before onboarding) for the rest of
      // the app session.
      ref.invalidate(homeActiveAllergiesProvider);
      ref.invalidate(healthSummaryProvider);
      ref.invalidate(emergencyActiveAllergiesProvider);
    } on DioException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.onboardingSaveProfileFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.onboardingSaveProfileFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/auth/success', extra: true);
      }
    }
  }

  void _skip() => context.go('/auth/success', extra: true);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.onboardingStep3Of3,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.help_outline,
                            color: AppTheme.textSecondary),
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
                            color: AppTheme.primary,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.onboardingAlmostThereTitle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.onboardingAlmostThereSubtitle,
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.fieldAllergies,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _allergiesController,
                                maxLines: 3,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: t.hintAllergiesExample,
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.helperSeparateWithCommas,
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.fieldExistingConditions,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _conditions.map((c) {
                                  final selected =
                                      _selectedConditions.contains(c);
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      if (selected) {
                                        _selectedConditions.remove(c);
                                      } else {
                                        _selectedConditions.add(c);
                                      }
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppTheme.primary
                                            : AppTheme.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: selected
                                              ? AppTheme.primary
                                              : AppTheme.cardBorder,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            selected ? Icons.check : Icons.add,
                                            size: 14,
                                            color: selected
                                                ? Colors.white
                                                : AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _conditionLabel(c),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: selected
                                                  ? Colors.white
                                                  : AppTheme.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _otherConditionController,
                                maxLength: 200,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: t.hintAddOtherConditions,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  t.badgeHipaaSecureStorage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  t.badgeEncryptedPersonalData,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _skip,
                            child: Text(
                              t.commonSkipForNow,
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => context.pop(),
                          child: Text(t.commonPrevious),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _finish,
                          child: Text(t.commonFinish),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
