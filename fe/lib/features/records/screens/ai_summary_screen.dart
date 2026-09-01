import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/records_provider.dart';

class AiSummaryScreen extends ConsumerWidget {
  const AiSummaryScreen({super.key, required this.recordId});
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final recordAsync = ref.watch(recordDetailProvider(recordId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
            SizedBox(width: 8),
            Text(t.aiSummaryAppBarTitle),
          ],
        ),
        backgroundColor: AppTheme.background,
      ),
      body: recordAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(t.aiSummaryLoadFailed,
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.refresh(recordDetailProvider(recordId)),
                child: Text(t.commonRetry),
              ),
            ],
          ),
        ),
        data: (record) {
          final status = record['processing_status'] as String? ?? '';
          final analysis = record['ai_analysis'] as Map<String, dynamic>?;

          if (status == 'processing') {
            return _ProcessingState(t: t);
          }

          if (status == 'failed') {
            return _FailedState(t: t);
          }

          if (analysis == null || analysis.isEmpty) {
            return _NoAnalysisState(recordId: recordId, t: t);
          }

          return _AnalysisContent(record: record, analysis: analysis, t: t);
        },
      ),
    );
  }
}

// ── Loading state while AI processes ──────────────────────────────────────────

class _ProcessingState extends StatelessWidget {
  const _ProcessingState({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.auto_awesome, color: AppTheme.primary, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              t.aiSummaryProcessing,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.aiSummaryProcessingSubtitle,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _FailedState extends StatelessWidget {
  const _FailedState({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 64),
            const SizedBox(height: 16),
            Text(t.aiSummaryFailedTitle,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
                t.aiSummaryFailedSubtitle,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/ai'),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: Text(t.aiSummaryAskAiInstead),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAnalysisState extends StatelessWidget {
  const _NoAnalysisState({required this.recordId, required this.t});
  final String recordId;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.science_outlined,
                  color: AppTheme.primary, size: 40),
            ),
            const SizedBox(height: 24),
            Text(t.aiSummaryNoLabParams,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              t.aiSummaryNoLabParamsSubtitle,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/ai'),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(t.aiSummaryContinueInChat),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/records/$recordId'),
                child: Text(t.aiSummaryViewRecordDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full analysis content ──────────────────────────────────────────────────────

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent(
      {required this.record, required this.analysis, required this.t});
  final Map<String, dynamic> record;
  final Map<String, dynamic> analysis;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final overallStatus = analysis['overall_status'] as String? ?? 'Good';
    final overallExplanation = analysis['overall_explanation'] as String? ?? '';
    final parameters = (analysis['parameters'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Overall result card ─────────────────────────────────────────────
          _OverallCard(
              status: overallStatus, explanation: overallExplanation, t: t),
          const SizedBox(height: 16),

          // ── Parameter cards ─────────────────────────────────────────────────
          ...parameters.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ParameterCard(parameter: p),
              )),

          const SizedBox(height: 8),

          // ── AI disclaimer ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: AppTheme.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.aiSummaryDisclaimer,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Continue in chat button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/ai'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(t.aiSummaryContinueExplanation,
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overall status card ────────────────────────────────────────────────────────

class _OverallCard extends StatelessWidget {
  const _OverallCard(
      {required this.status, required this.explanation, required this.t});
  final String status;
  final String explanation;
  final AppLocalizations t;

  Color get _statusColor {
    switch (status) {
      case 'Good':
        return AppTheme.success;
      case 'Fair':
        return AppTheme.warning;
      case 'Poor':
        return AppTheme.error;
      default:
        return AppTheme.success;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case 'Good':
        return Icons.check_circle;
      case 'Fair':
        return Icons.warning_rounded;
      case 'Poor':
        return Icons.error_rounded;
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.aiSummaryResultLabel,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_statusIcon, color: _statusColor, size: 28),
              const SizedBox(width: 10),
              Text(
                t.aiSummaryOverallLabel(status),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _statusColor),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Individual parameter card ──────────────────────────────────────────────────

class _ParameterCard extends StatelessWidget {
  const _ParameterCard({required this.parameter});
  final Map<String, dynamic> parameter;

  Color get _statusColor {
    switch (parameter['status']) {
      case 'Healthy':
        return AppTheme.success;
      case 'Optimal':
        return AppTheme.primary;
      case 'Monitoring':
        return AppTheme.warning;
      case 'Attention':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _paramIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('hemoglobin') ||
        lower.contains('haemoglobin') ||
        lower.contains('hgb') ||
        lower.contains('rbc') ||
        lower.contains('iron')) {
      return Icons.water_drop_outlined;
    }
    if (lower.contains('glucose') ||
        lower.contains('sugar') ||
        lower.contains('hba1c')) {
      return Icons.water_drop_outlined;
    }
    if (lower.contains('cholesterol') ||
        lower.contains('ldl') ||
        lower.contains('hdl') ||
        lower.contains('triglyceride')) {
      return Icons.equalizer_outlined;
    }
    if (lower.contains('pressure') ||
        lower.contains('bp') ||
        lower.contains('systolic')) {
      return Icons.speed_outlined;
    }
    if (lower.contains('platelet') ||
        lower.contains('wbc') ||
        lower.contains('leukocyte')) {
      return Icons.bubble_chart_outlined;
    }
    if (lower.contains('creatinine') ||
        lower.contains('urea') ||
        lower.contains('kidney') ||
        lower.contains('gfr')) {
      return Icons.filter_alt_outlined;
    }
    if (lower.contains('thyroid') ||
        lower.contains('tsh') ||
        lower.contains('t3') ||
        lower.contains('t4')) {
      return Icons.manage_accounts_outlined;
    }
    return Icons.biotech_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final name = parameter['name'] as String? ?? '';
    final value = parameter['value'] as String? ?? '';
    final unit = parameter['unit'] as String? ?? '';
    final status = parameter['status'] as String? ?? '';
    final explanation = parameter['explanation'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_paramIcon(name), color: _statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                    if (value.isNotEmpty)
                      Text(
                        '$value ${unit.isNotEmpty ? unit : ''}'.trim(),
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _statusColor),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              explanation,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
