import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/insights_provider.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../records/providers/records_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final summaryAsync = ref.watch(healthSummaryProvider);
    final profile = ref.watch(activeProfileProvider);
    final title = profile.isOwnerMode
        ? t.insightsTitle
        : t.insightsTitleFor(profile.displayName);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(title)),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(t.insightsCouldNotLoad,
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => ref.refresh(healthSummaryProvider),
                  child: Text(t.commonRetry)),
            ],
          ),
        ),
        data: (summary) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary stat cards ────────────────────────────────────
              Text(t.insightsOverview,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // A fixed pixel height (rather than childAspectRatio, which
                // derives height from the card's width) so the icon, number,
                // and label always fit regardless of screen width - a ratio
                // tall enough on wide screens was too short on narrow ones.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 112,
                ),
                children: [
                  _InsightCard(
                    icon: Icons.folder_outlined,
                    label: t.insightsTotalRecords,
                    value: '${summary['total_records'] ?? 0}',
                    color: AppTheme.primary,
                  ),
                  _InsightCard(
                    icon: Icons.calendar_today_outlined,
                    label: t.insightsThisMonth,
                    value: '${summary['records_this_month'] ?? 0}',
                    color: AppTheme.info,
                  ),
                  _InsightCard(
                    icon: Icons.medical_information_outlined,
                    label: t.insightsActiveConditions,
                    value: '${summary['active_conditions'] ?? 0}',
                    color: AppTheme.warning,
                  ),
                  _InsightCard(
                    icon: Icons.notifications_active_outlined,
                    label: t.insightsUnreadAlerts,
                    value: '${summary['unread_alerts'] ?? 0}',
                    color: AppTheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Records by type bar chart (from loaded records list) ───
              Text(t.insightsRecordsByType,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 14),
              _RecordsByTypeChart(),
              const SizedBox(height: 28),

              // ── Vital trends (live from API) ───────────────────────────
              Text(t.insightsVitalTrends,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              _VitalTrendCard(
                title: t.insightsBloodGlucose,
                loinc: '2345-7',
                unit: 'mg/dL',
                color: AppTheme.warning,
              ),
              const SizedBox(height: 12),
              _VitalTrendCard(
                title: t.insightsHemoglobin,
                loinc: '718-7',
                unit: 'g/dL',
                color: AppTheme.success,
              ),
              const SizedBox(height: 12),
              _VitalTrendCard(
                title: t.insightsBloodPressureSystolic,
                loinc: '8480-6',
                unit: 'mmHg',
                color: AppTheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Records by type bar chart (uses cached recordsListProvider) ─────────────

class _RecordsByTypeChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final recordsAsync = ref.watch(recordsListProvider);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(t.insightsCouldNotLoadChart,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
        data: (records) {
          final counts = {
            'lab_report': 0,
            'prescription': 0,
            'radiology': 0,
            'vaccination': 0,
            'other': 0,
          };
          for (final r in records) {
            final type = r['record_type'] as String? ?? 'other';
            if (counts.containsKey(type)) {
              counts[type] = counts[type]! + 1;
            } else {
              counts['other'] = counts['other']! + 1;
            }
          }

          final values = [
            counts['lab_report']!.toDouble(),
            counts['prescription']!.toDouble(),
            counts['radiology']!.toDouble(),
            counts['vaccination']!.toDouble(),
            counts['other']!.toDouble(),
          ];
          final maxY = values.reduce((a, b) => a > b ? a : b);

          if (maxY == 0) {
            return Center(
              child: Text(t.insightsNoRecordsYet,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            );
          }

          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxY + 2).ceilToDouble(),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final labels = [
                        t.insightsChartLabelLab,
                        t.insightsChartLabelRx,
                        t.insightsChartLabelRad,
                        t.insightsChartLabelVax,
                        t.insightsChartLabelOther,
                      ];
                      final i = value.toInt();
                      if (i >= labels.length) return const SizedBox.shrink();
                      return Text(labels[i],
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10));
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: values.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value,
                      color: AppTheme.primary,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ── Vital trend card - fetches live data from observationTrendProvider ───────

class _VitalTrendCard extends ConsumerWidget {
  const _VitalTrendCard({
    required this.title,
    required this.loinc,
    required this.unit,
    required this.color,
  });

  final String title;
  final String loinc;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final trendAsync = ref.watch(observationTrendProvider(loinc));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              trendAsync.when(
                loading: () => SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppTheme.primary)),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) {
                  final points = (data['points'] as List? ?? []);
                  if (points.isEmpty) return const SizedBox.shrink();
                  final last = (points.last['value'] as num).toDouble();
                  return Text(
                    '${last % 1 == 0 ? last.toInt() : last.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: trendAsync.when(
              loading: () => const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => Center(
                child: Text(t.insightsFailedToLoad,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
              data: (data) {
                final rawPoints = (data['points'] as List? ?? []);
                if (rawPoints.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.show_chart,
                            color: AppTheme.textMuted.withValues(alpha: 0.5),
                            size: 22),
                        const SizedBox(height: 4),
                        Text(t.insightsNoDataRecordedYet,
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  );
                }

                final spots = rawPoints.asMap().entries.map((e) {
                  final value = (e.value['value'] as num).toDouble();
                  return FlSpot(e.key.toDouble(), value);
                }).toList();

                final minY =
                    spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
                final maxY =
                    spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
                final padding = (maxY - minY) * 0.2;

                return LineChart(
                  LineChartData(
                    lineTouchData: const LineTouchData(enabled: false),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: (minY - padding).clamp(0, double.infinity),
                    maxY: maxY + padding,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: rawPoints.length <= 10,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: color,
                            strokeWidth: 0,
                            strokeColor: Colors.transparent,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared stat card ─────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(label,
                  style:
                      TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
