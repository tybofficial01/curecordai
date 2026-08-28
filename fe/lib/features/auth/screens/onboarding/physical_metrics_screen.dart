import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/onboarding_provider.dart';

class PhysicalMetricsScreen extends ConsumerStatefulWidget {
  const PhysicalMetricsScreen({super.key});

  @override
  ConsumerState<PhysicalMetricsScreen> createState() =>
      _PhysicalMetricsScreenState();
}

class _PhysicalMetricsScreenState extends ConsumerState<PhysicalMetricsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _bloodGroup;

  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _skip() {
    ref.read(onboardingDataProvider.notifier).updateStep2();
    context.push('/auth/onboarding/step3');
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(onboardingDataProvider.notifier).updateStep2(
          heightCm: double.tryParse(_heightController.text.trim()),
          weightKg: double.tryParse(_weightController.text.trim()),
          bloodGroup: _bloodGroup,
        );
    context.push('/auth/onboarding/step3');
  }

  String? _validateHeight(String? v) {
    if (v == null || v.isEmpty) return null;
    final h = double.tryParse(v);
    if (h == null || h < 50 || h > 300) {
      return ref.read(appLocalizationsProvider).validationHeightRange;
    }
    return null;
  }

  String? _validateWeight(String? v) {
    if (v == null || v.isEmpty) return null;
    final w = double.tryParse(v);
    if (w == null || w < 1 || w > 500) {
      return ref.read(appLocalizationsProvider).validationWeightRange;
    }
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
                    t.onboardingStep2Of3,
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
                        color: i <= 1 ? AppTheme.primary : AppTheme.cardBorder,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.onboardingPhysicalMetricsTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.onboardingPhysicalMetricsSubtitle,
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
                              t.fieldHeightCm,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: t.hintHeightCm,
                                prefixIcon: Icon(Icons.height,
                                    color: AppTheme.textSecondary, size: 20),
                              ),
                              validator: _validateHeight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t.fieldWeightKg,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: t.hintWeightKg,
                                prefixIcon: Icon(Icons.monitor_weight_outlined,
                                    color: AppTheme.textSecondary, size: 20),
                              ),
                              validator: _validateWeight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t.fieldBloodGroup,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                hintText: t.hintSelectBloodGroup,
                                prefixIcon: Icon(Icons.bloodtype_outlined,
                                    color: AppTheme.textSecondary, size: 20),
                              ),
                              items: _bloodGroups
                                  .map((g) => DropdownMenuItem(
                                      value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) => setState(() => _bloodGroup = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.primary, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.onboardingPhysicalDataNotice,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: Text(t.commonPrevious),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(t.commonNext),
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
