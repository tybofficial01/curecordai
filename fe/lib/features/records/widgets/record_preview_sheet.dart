import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/records_provider.dart';

const _kTypeIcons = {
  'lab_report': Icons.science_outlined,
  'prescription': Icons.medication_outlined,
  'radiology': Icons.image_outlined,
  'discharge_summary': Icons.local_hospital_outlined,
  'vaccination': Icons.vaccines_outlined,
  'insurance': Icons.shield_outlined,
  'referral': Icons.send_outlined,
  'other': Icons.description_outlined,
};

/// Shared record_type -> icon/label mapping so a document looks the same everywhere
/// it's referenced (records list, record detail, AI chat citation chips).
IconData recordTypeIcon(String type) =>
    _kTypeIcons[type] ?? Icons.description_outlined;

/// Unknown types fall through to the raw backend value rather than being
/// mistranslated - it is data, not a UI label.
String recordTypeLabel(AppLocalizations t, String type) {
  switch (type) {
    case 'lab_report':
      return t.recordTypeLabReport;
    case 'prescription':
      return t.recordTypePrescription;
    case 'radiology':
      return t.recordTypeRadiology;
    case 'discharge_summary':
      return t.recordTypeDischargeSummary;
    case 'vaccination':
      return t.recordTypeVaccination;
    case 'insurance':
      return t.recordTypeInsurance;
    case 'referral':
      return t.recordTypeReferral;
    case 'other':
      return t.recordTypeOther;
    default:
      return type;
  }
}

/// Shared processing_status -> label mapping (pending/processing/completed/failed),
/// used anywhere a document card shows its status alongside its type.
String recordStatusLabel(AppLocalizations t, String? status) {
  switch (status) {
    case 'pending':
      return t.statusPending;
    case 'processing':
      return t.statusProcessing;
    case 'completed':
      return t.statusCompleted;
    case 'failed':
      return t.statusFailed;
    default:
      return status ?? '';
  }
}

String formatRecordDate(AppLocalizations t, String? iso) {
  if (iso == null || iso.isEmpty) return ' - ';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${shortMonthName(t, dt.month)} '
        '${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  } catch (_) {
    return iso;
  }
}

/// Quick, read-only record preview - opened from an AI chat citation chip (or anywhere
/// else a lightweight peek is useful) without navigating away from the current screen.
/// Shows the caller's fallback title/type/date instantly while the full record loads,
/// then fills in the AI summary. "View Full Record" hands off to the full, editable
/// RecordDetailScreen for anything beyond a quick look.
class RecordPreviewSheet extends ConsumerWidget {
  const RecordPreviewSheet({
    super.key,
    required this.recordId,
    this.fallbackTitle,
    this.fallbackType,
    this.fallbackDate,
  });

  final String recordId;
  final String? fallbackTitle;
  final String? fallbackType;
  final String? fallbackDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final recordAsync = ref.watch(recordDetailProvider(recordId));
    final record = recordAsync.value;
    final title = record?['title'] as String? ?? fallbackTitle ?? t.recordWord;
    final type = record?['record_type'] as String? ?? fallbackType ?? 'other';
    final recordDate = record?['record_date'] as String? ?? fallbackDate;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(recordTypeIcon(type),
                              color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${recordTypeLabel(t, type)} · ${formatRecordDate(t, recordDate)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: AppTheme.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    recordAsync.when(
                      data: (data) => _PreviewBody(record: data),
                      loading: () => Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primary)),
                      ),
                      error: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline,
                                color: AppTheme.error, size: 28),
                            const SizedBox(height: 8),
                            Text(t.recordPreviewLoadFailed,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => ref
                                  .invalidate(recordDetailProvider(recordId)),
                              child: Text(t.commonRetry),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/records/$recordId');
                        },
                        icon: const Icon(Icons.open_in_full, size: 16),
                        label: Text(t.recordViewFullRecord),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final status = record['processing_status'] as String? ?? '';
    final summary = record['ai_summary'] as String?;
    final issuer = (record['laboratory_name'] ?? record['issuing_organization'])
        as String?;
    final doctor = record['referring_doctor'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == 'processing' || status == 'pending')
          _InfoBanner(
            icon: Icons.hourglass_top,
            color: AppTheme.warning,
            text: t.recordStillProcessing,
          )
        else if (status == 'failed')
          _InfoBanner(
            icon: Icons.error_outline,
            color: AppTheme.error,
            text: record['processing_error'] as String? ?? t.recordProcessingFailed,
          ),
        if (issuer != null)
          _PreviewRow(
              icon: Icons.local_hospital_outlined,
              label: t.recordIssuedBy,
              value: issuer),
        if (doctor != null)
          _PreviewRow(
              icon: Icons.person_outline,
              label: t.recordDoctor,
              value: doctor),
        if (summary != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.primary, size: 15),
                    const SizedBox(width: 7),
                    Text(t.recordsAiSummary,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(summary,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$label: $value',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(
      {required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
