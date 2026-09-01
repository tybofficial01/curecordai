import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curecordai/core/theme/app_fonts.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  List<_PolicySection> _sections(AppLocalizations t) => [
        _PolicySection(
          title: t.privacyPolicyDataWeCollectTitle,
          body: t.privacyPolicyDataWeCollectBody,
        ),
        _PolicySection(
          title: t.privacyPolicyHowWeUseDataTitle,
          body: t.privacyPolicyHowWeUseDataBody,
        ),
        _PolicySection(
          title: t.privacyPolicyAiProcessingTitle,
          body: t.privacyPolicyAiProcessingBody,
        ),
        _PolicySection(
          title: t.privacyPolicyStorageSecurityTitle,
          body: t.privacyPolicyStorageSecurityBody,
        ),
        _PolicySection(
          title: t.privacyPolicyFamilyAccessTitle,
          body: t.privacyPolicyFamilyAccessBody,
        ),
        _PolicySection(
          title: t.privacyPolicySharingCliniciansTitle,
          body: t.privacyPolicySharingCliniciansBody,
        ),
        _PolicySection(
          title: t.privacyPolicyYourRightsTitle,
          body: t.privacyPolicyYourRightsBody,
        ),
        _PolicySection(
          title: t.privacyPolicyDataRetentionTitle,
          body: t.privacyPolicyDataRetentionBody,
        ),
        _PolicySection(
          title: t.privacyPolicyContactTitle,
          body: t.privacyPolicyContactBody,
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(t.privacyPolicyAppBarTitle,
            style: AppFonts.manrope(
                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.privacyPolicyHeading,
              style: AppFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              t.privacyPolicyIntro,
              style: AppFonts.manrope(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            for (final section in _sections(t)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: AppFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: AppFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;
}
