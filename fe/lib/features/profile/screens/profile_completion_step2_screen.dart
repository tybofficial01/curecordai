import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:curecordai/core/theme/app_fonts.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/step_shared_widgets.dart';

class ProfileCompletionStep2Screen extends ConsumerStatefulWidget {
  const ProfileCompletionStep2Screen({super.key});

  @override
  ConsumerState<ProfileCompletionStep2Screen> createState() =>
      _ProfileCompletionStep2ScreenState();
}

class _ProfileCompletionStep2ScreenState
    extends ConsumerState<ProfileCompletionStep2Screen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _bloodGroup;

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

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _next() {
    final t = ref.read(appLocalizationsProvider);
    final hasEmpty = _heightCtrl.text.trim().isEmpty ||
        _weightCtrl.text.trim().isEmpty ||
        _bloodGroup == null;
    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.profileCompletionStep2SkipNotice)),
      );
    }
    context.push('/profile-completion/step3');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(step: 2, onHelp: _showHelp),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.profileCompletionPhysicalMetricsTitle,
                        style: AppFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      t.profileCompletionPhysicalMetricsSubtitle,
                      style: AppFonts.manrope(
                          fontSize: 15, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    FormCard(
                      children: [
                        FieldLabel(t.profileFieldHeightCm),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            hintText: t.profileHintHeightExample,
                            suffixIcon: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() {
                                    final v =
                                        int.tryParse(_heightCtrl.text) ?? 0;
                                    _heightCtrl.text = '${v + 1}';
                                  }),
                                  child: Icon(Icons.keyboard_arrow_up,
                                      size: 20, color: AppTheme.textSecondary),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    final v =
                                        int.tryParse(_heightCtrl.text) ?? 1;
                                    if (v > 1) _heightCtrl.text = '${v - 1}';
                                  }),
                                  child: Icon(Icons.keyboard_arrow_down,
                                      size: 20, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FieldLabel(t.profileFieldWeightKg),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: t.profileHintWeightExample,
                            suffixText: 'kg',
                            suffixStyle: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.profileCompletionStep2Note,
                              style: AppFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            StepBottomBar(
                step: 2,
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
            Text(t.profileCompletionStep2HelpTitle,
                style: AppFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              t.profileCompletionStep2HelpBody,
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
