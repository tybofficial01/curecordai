import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curecordai/core/theme/app_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

// Maps consent_type → is_granted (latest record per type)
final consentSummaryProvider = FutureProvider<Map<String, bool>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get<List<dynamic>>('/consent/',
      cachePolicy: CachePolicy.refreshForceCache);
  final records = res.data ?? [];
  // Records come newest-first; first occurrence of each type wins
  final Map<String, bool> summary = {};
  for (final r in records) {
    final m = r as Map<String, dynamic>;
    final type = m['consent_type'] as String? ?? '';
    if (!summary.containsKey(type)) {
      summary[type] = m['is_granted'] as bool? ?? false;
    }
  }
  return summary;
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ConsentManagementScreen extends ConsumerWidget {
  const ConsentManagementScreen({super.key});

  List<_ConsentItem> _manageable(AppLocalizations t) => [
        _ConsentItem(
          type: 'analytics',
          title: t.consentAnalyticsTitle,
          subtitle: t.consentAnalyticsSubtitle,
        ),
        _ConsentItem(
          type: 'marketing_communications',
          title: t.consentMarketingTitle,
          subtitle: t.consentMarketingSubtitle,
        ),
      ];

  List<_ConsentItem> _readonly(AppLocalizations t) => [
        _ConsentItem(
          type: 'terms_of_service',
          title: t.consentTermsOfServiceTitle,
          subtitle: t.consentTermsOfServiceSubtitle,
        ),
        _ConsentItem(
          type: 'privacy_policy',
          title: t.consentPrivacyPolicyTitle,
          subtitle: t.consentPrivacyPolicySubtitle,
        ),
        _ConsentItem(
          type: 'data_processing',
          title: t.consentDataProcessingTitle,
          subtitle: t.consentDataProcessingSubtitle,
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final summaryAsync = ref.watch(consentSummaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.consentManagementTitle,
            style: AppFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: summaryAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) =>
            Center(child: Text(t.profileFailedToLoadWith(e.toString()))),
        data: (summary) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(t.consentOptionalSectionTitle),
              const SizedBox(height: 8),
              _ConsentCard(
                items: _manageable(t),
                summary: summary,
                editable: true,
                t: t,
                onToggle: (type, value) =>
                    _postConsent(context, ref, type, value),
              ),
              const SizedBox(height: 20),
              _SectionHeader(t.consentRequiredSectionTitle),
              const SizedBox(height: 8),
              _ConsentCard(
                items: _readonly(t),
                summary: summary,
                editable: false,
                t: t,
                onToggle: null,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.consentWithdrawalNote,
                        style: AppFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.5),
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

  Future<void> _postConsent(
      BuildContext context, WidgetRef ref, String type, bool granted) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/consent/', data: {
        'consent_type': type,
        'is_granted': granted,
      });
      ref.invalidate(consentSummaryProvider);
    } catch (_) {
      if (context.mounted) {
        final t = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.consentUpdateFailed)),
        );
      }
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.primary,
        letterSpacing: 1,
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.items,
    required this.summary,
    required this.editable,
    required this.onToggle,
    required this.t,
  });
  final List<_ConsentItem> items;
  final Map<String, bool> summary;
  final bool editable;
  final void Function(String type, bool value)? onToggle;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  color: Color(0xFFE5E7EB)),
            _ConsentRow(
              item: items[i],
              isGranted: summary[items[i].type] ?? false,
              editable: editable,
              onToggle:
                  editable ? (v) => onToggle?.call(items[i].type, v) : null,
              t: t,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.item,
    required this.isGranted,
    required this.editable,
    required this.onToggle,
    required this.t,
  });
  final _ConsentItem item;
  final bool isGranted;
  final bool editable;
  final ValueChanged<bool>? onToggle;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: AppFonts.manrope(
                        fontSize: 12, color: const Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (editable)
            Switch(
              value: isGranted,
              activeColor: AppTheme.primary,
              onChanged: onToggle,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isGranted
                    ? const Color(0xFFE8F5F4)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isGranted ? t.consentAccepted : t.consentNotSet,
                style: AppFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isGranted ? AppTheme.primary : const Color(0xFF9CA3AF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsentItem {
  final String type;
  final String title;
  final String subtitle;
  const _ConsentItem(
      {required this.type, required this.title, required this.subtitle});
}
