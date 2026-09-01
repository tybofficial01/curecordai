import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';

final healthOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final response = await api.get<Map<String, dynamic>>(
    '/insights/health-overview',
    queryParameters: memberId != null ? {'family_member_id': memberId} : null,
    cachePolicy: CachePolicy.refreshForceCache,
  );
  return response.data ?? {};
});

/// A comprehensive, whole-person health overview - an AI narrative built from everything
/// active across all of the patient's records (conditions, medications, allergies, recent
/// labs/vitals), not a single document's summary. Reached from Home → "View Summary".
class HealthSummaryScreen extends ConsumerWidget {
  const HealthSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final overviewAsync = ref.watch(healthOverviewProvider);
    final profile = ref.watch(activeProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(profile.isOwnerMode
            ? t.healthSummaryTitle
            : t.healthSummaryTitleFor(profile.displayName)),
      ),
      body: overviewAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(t.healthSummaryCouldNotLoad,
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(healthOverviewProvider),
                child: Text(t.commonRetry),
              ),
            ],
          ),
        ),
        data: (data) {
          final narrative = data['narrative_summary'] as String?;
          final conditions =
              (data['conditions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final medications =
              (data['medications'] as List?)?.cast<Map<String, dynamic>>() ??
                  [];
          final allergies =
              (data['allergies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final observations = (data['recent_observations'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

          if (narrative == null &&
              conditions.isEmpty &&
              medications.isEmpty &&
              allergies.isEmpty &&
              observations.isEmpty) {
            return _EmptyState(
                isOwnerMode: profile.isOwnerMode,
                displayName: profile.displayName,
                t: t);
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => ref.invalidate(healthOverviewProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (narrative != null) ...[
                  _NarrativeCard(text: narrative, t: t),
                  const SizedBox(height: 20),
                ],
                if (conditions.isNotEmpty) ...[
                  _SectionHeader(
                      icon: Icons.monitor_heart_outlined,
                      title: t.healthSummaryActiveConditions),
                  const SizedBox(height: 8),
                  _Section(
                      children: conditions
                          .map((c) => _Tile(
                                title: c['condition_name'] as String? ?? ' - ',
                                subtitle: _capitalize(
                                    c['clinical_status'] as String?),
                                trailing: c['icd11_code'] as String?,
                              ))
                          .toList()),
                  const SizedBox(height: 20),
                ],
                if (medications.isNotEmpty) ...[
                  _SectionHeader(
                      icon: Icons.medication_outlined,
                      title: t.healthSummaryCurrentMedications),
                  const SizedBox(height: 8),
                  _Section(
                      children: medications
                          .map((m) => _Tile(
                                title:
                                    m['medication_name_raw'] as String? ?? ' - ',
                                subtitle: [
                                  m['dosage_instruction'],
                                  m['dose_frequency']
                                ]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                              ))
                          .toList()),
                  const SizedBox(height: 20),
                ],
                if (allergies.isNotEmpty) ...[
                  _SectionHeader(
                      icon: Icons.warning_amber_outlined,
                      title: t.healthSummaryAllergies),
                  const SizedBox(height: 8),
                  _Section(
                      children: allergies
                          .map((a) => _Tile(
                                title: a['substance_name'] as String? ?? ' - ',
                                subtitle: a['reaction_description'] as String?,
                                trailing: a['criticality'] as String?,
                                trailingColor: a['criticality'] == 'high'
                                    ? AppTheme.error
                                    : AppTheme.warning,
                              ))
                          .toList()),
                  const SizedBox(height: 20),
                ],
                if (observations.isNotEmpty) ...[
                  _SectionHeader(
                      icon: Icons.science_outlined,
                      title: t.healthSummaryRecentLabsVitals),
                  const SizedBox(height: 8),
                  _Section(
                      children: observations.take(10).map((o) {
                    final qty = o['value_quantity'];
                    final unit = o['value_unit'] as String? ?? '';
                    final str = o['value_string'] as String?;
                    final value =
                        qty != null ? '$qty $unit'.trim() : (str ?? ' - ');
                    return _Tile(
                      title: o['observation_name'] as String? ?? ' - ',
                      subtitle: null,
                      trailing: value,
                    );
                  }).toList()),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: AppTheme.textSecondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.healthSummaryDisclaimer,
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              height: 1.5),
                        ),
                      ),
                    ],
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

String? _capitalize(String? s) {
  if (s == null || s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.text, required this.t});
  final String text;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.10),
            AppTheme.primary.withValues(alpha: 0.03)
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(t.healthSummaryYourOverview,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary, height: 1.65)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i < children.length - 1)
                Divider(color: AppTheme.cardBorder, height: 1, indent: 16),
            ],
          );
        }),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.title, this.subtitle, this.trailing, this.trailingColor});
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!,
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty)
            Text(trailing!,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: trailingColor ?? AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.isOwnerMode, required this.displayName, required this.t});
  final bool isOwnerMode;
  final String displayName;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.summarize_outlined, color: AppTheme.textMuted, size: 56),
            const SizedBox(height: 16),
            Text(
              isOwnerMode
                  ? t.healthSummaryNoDataYet
                  : t.healthSummaryNoDataYetFor(displayName),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              t.healthSummaryUploadPrompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
