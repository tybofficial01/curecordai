import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

final _alertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/alerts');
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final alertsAsync = ref.watch(_alertsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.alertCenterTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(t.alertCenterSubtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        toolbarHeight: 60,
        actions: [
          TextButton(
            onPressed: () async {
              final api = ref.read(apiClientProvider);
              await api.post('/alerts/read-all');
              ref.invalidate(_alertsProvider);
            },
            child: Text(t.alertMarkAllRead,
                style: TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: OutlinedButton(
              onPressed: () => ref.invalidate(_alertsProvider),
              child: Text(t.commonRetry)),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      color: AppTheme.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text(t.alertEmptyTitle,
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Text(t.alertEmptySubtitle,
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            );
          }

          // Group by day
          final today = <Map<String, dynamic>>[];
          final yesterday = <Map<String, dynamic>>[];
          final older = <Map<String, dynamic>>[];
          final now = DateTime.now();

          for (final alert in alerts) {
            final createdAt = alert['created_at'] as String?;
            if (createdAt == null) {
              today.add(alert);
              continue;
            }
            try {
              final dt = DateTime.parse(createdAt).toLocal();
              final diff = now.difference(dt);
              if (diff.inHours < 24) {
                today.add(alert);
              } else if (diff.inHours < 48) {
                yesterday.add(alert);
              } else {
                older.add(alert);
              }
            } catch (_) {
              today.add(alert);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...today.map((a) => _AlertTile(
                    alert: a,
                    t: t,
                    onMarkRead: () async {
                      final api = ref.read(apiClientProvider);
                      await api.post('/alerts/${a['id']}/read');
                      ref.invalidate(_alertsProvider);
                    },
                    onDismiss: () async {
                      final api = ref.read(apiClientProvider);
                      await api.delete('/alerts/${a['id']}');
                      ref.invalidate(_alertsProvider);
                    },
                  )),
              if (yesterday.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(t.alertYesterday,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                ),
                ...yesterday.map((a) => _AlertTile(
                      alert: a,
                      t: t,
                      onMarkRead: () async {
                        final api = ref.read(apiClientProvider);
                        await api.post('/alerts/${a['id']}/read');
                        ref.invalidate(_alertsProvider);
                      },
                      onDismiss: () async {
                        final api = ref.read(apiClientProvider);
                        await api.delete('/alerts/${a['id']}');
                        ref.invalidate(_alertsProvider);
                      },
                    )),
              ],
              if (older.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(t.alertEarlier,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                ),
                ...older.map((a) => _AlertTile(
                      alert: a,
                      t: t,
                      onMarkRead: () async {
                        final api = ref.read(apiClientProvider);
                        await api.post('/alerts/${a['id']}/read');
                        ref.invalidate(_alertsProvider);
                      },
                      onDismiss: () async {
                        final api = ref.read(apiClientProvider);
                        await api.delete('/alerts/${a['id']}');
                        ref.invalidate(_alertsProvider);
                      },
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile(
      {required this.alert,
      required this.t,
      required this.onMarkRead,
      required this.onDismiss});
  final Map<String, dynamic> alert;
  final AppLocalizations t;
  final VoidCallback onMarkRead;
  final VoidCallback onDismiss;

  IconData _iconFor(String? type) {
    switch (type) {
      case 'medication_reminder':
        return Icons.medication_outlined;
      case 'document_processed':
        return Icons.description_outlined;
      case 'ai_insight':
        return Icons.auto_awesome_outlined;
      case 'appointment_reminder':
        return Icons.calendar_today_outlined;
      case 'share_scanned':
        return Icons.qr_code_scanner_outlined;
      case 'drug_interaction':
        return Icons.warning_amber_outlined;
      case 'high_glucose':
        return Icons.show_chart_outlined;
      case 'emergency_flag':
        return Icons.medical_services_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'medication_reminder':
      case 'drug_interaction':
        return AppTheme.error;
      case 'ai_insight':
        return AppTheme.primary;
      case 'appointment_reminder':
        return const Color(0xFF6B8EFF);
      case 'share_scanned':
        return const Color(0xFFFF9F45);
      case 'high_glucose':
        return const Color(0xFFFF9F45);
      case 'emergency_flag':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  // Priority chip label - matching Figma
  String? _priorityLabel(String? type) {
    switch (type) {
      case 'drug_interaction':
        return t.alertPriorityHigh;
      case 'high_glucose':
        return t.alertPriorityAttention;
      case 'emergency_flag':
        return t.alertPrioritySystemUpdate;
      default:
        return null;
    }
  }

  // Category chip label - matching Figma
  String? _categoryLabel(String? type) {
    switch (type) {
      case 'drug_interaction':
        return t.alertCategoryMedication;
      case 'high_glucose':
        return t.alertCategoryVitals;
      case 'emergency_flag':
        return t.alertCategoryProfile;
      case 'document_processed':
        return t.alertCategoryRecords;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = alert['is_read'] as bool? ?? false;
    final alertType = alert['alert_type'] as String?;
    final color = _colorFor(alertType);
    final priority = _priorityLabel(alertType);
    final category = _categoryLabel(alertType);
    final timeStr = _formatTime(alert['created_at'] as String?);

    return Dismissible(
      key: Key(alert['id']?.toString() ??
          Object.hash(alert['title'], alert['created_at']).toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: AppTheme.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: isRead ? null : onMarkRead,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isRead ? AppTheme.cardBorder : color.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconFor(alertType), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'] as String? ?? t.alertDefaultTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (alert['body'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            alert['body'] as String,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Timestamp chip - matching Figma
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(timeStr,
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
              if (priority != null || category != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (priority != null)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(priority,
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    if (category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(category,
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    if (!isRead)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return t.alertTimeMinutesAgo(diff.inMinutes);
      if (diff.inHours < 24) return t.alertTimeHoursAgo(diff.inHours);
      return t.alertTimeDaysAgo(diff.inDays);
    } catch (_) {
      return '';
    }
  }
}
