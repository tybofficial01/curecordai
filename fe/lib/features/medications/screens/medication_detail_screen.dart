import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/family_provider.dart';
import '../providers/medications_provider.dart';
import '../widgets/edit_medication_modal.dart';

String _frequencyTypeLabel(AppLocalizations t, String frequencyType) {
  switch (frequencyType) {
    case 'daily':
      return t.medFreqDaily;
    case 'specific_days':
      return t.medFreqSpecificDays;
    case 'interval':
      return t.medFreqInterval;
    case 'as_needed':
      return t.medFreqAsNeeded;
    default:
      return frequencyType;
  }
}

class MedicationDetailScreen extends ConsumerStatefulWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});
  final String medicationId;

  @override
  ConsumerState<MedicationDetailScreen> createState() =>
      _MedicationDetailScreenState();
}

class _MedicationDetailScreenState
    extends ConsumerState<MedicationDetailScreen> {
  bool _busy = false;

  Future<void> _changeStatus(String status) async {
    final t = ref.read(appLocalizationsProvider);
    setState(() => _busy = true);
    try {
      await ref
          .read(medicationsControllerProvider)
          .update(widget.medicationId, {'status': status});
      ref.invalidate(medicationDetailProvider(widget.medicationId));
      ref.invalidate(medicationsListProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.medUpdateFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final t = ref.read(appLocalizationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.medDeleteConfirmTitle),
        content: Text(t.medDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.commonDelete, style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(medicationsControllerProvider).delete(widget.medicationId);
      ref.invalidate(medicationsListProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.medDeleteFailed)),
        );
      }
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final medAsync = ref.watch(medicationDetailProvider(widget.medicationId));
    final familyAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.medDetailTitle,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          medAsync.maybeWhen(
            data: (med) => IconButton(
              icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
              tooltip: t.commonEdit,
              onPressed: () => showEditMedicationModal(context, reminder: med),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: medAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(t.medLoadFailed,
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(
                    medicationDetailProvider(widget.medicationId)),
                child: Text(t.commonRetry),
              ),
            ],
          ),
        ),
        data: (med) {
          final memberId = med['family_member_id']?.toString();
          final memberName = memberId == null
              ? t.commonYou
              : familyAsync.maybeWhen(
                  data: (members) => members.firstWhere(
                    (m) => m['id'].toString() == memberId,
                    orElse: () => {'full_name': t.medFamilyMemberFallback},
                  )['full_name'] as String,
                  orElse: () => t.medFamilyMemberFallback,
                );
          final status = med['status'] as String;
          final times = (med['times_of_day'] as List<dynamic>? ?? []).join(', ');
          final channels = [
            if (med['email_reminders_enabled'] == true) t.medReminderEmail,
            if (med['push_reminders_enabled'] == true) t.medReminderMobileAlarm,
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(med['medication_name'] as String,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(t.medForMember(memberName), style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.medRowStatus,
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    _StatusBadge(status: status, t: t),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                title: t.medSectionDetails,
                children: [
                  _Row(t.medRowDosage, med['dosage']?.toString(), t: t),
                  _Row(t.medRowForm, med['form']?.toString(), t: t),
                  _Row(t.medRowInstructions, med['instructions']?.toString(), t: t),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: t.medSectionSchedule,
                children: [
                  _Row(t.medRowFrequency, _frequencyTypeLabel(t, med['frequency_type'] as String),
                      t: t),
                  _Row(t.medRowTimes, times.isEmpty ? null : times, t: t),
                  _Row(t.medRowStartDate, med['start_date']?.toString(), t: t),
                  _Row(t.medRowEndDate, med['end_date']?.toString() ?? t.medOngoing, t: t),
                  _Row(t.medRowTimezone, med['timezone']?.toString(), t: t),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: t.medSectionNotifications,
                children: [
                  _Row(t.medRowReminders,
                      channels.isEmpty ? t.medReminderNone : channels.join(' · '), t: t),
                ],
              ),

              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (status != 'active')
                    ElevatedButton.icon(
                      onPressed: _busy ? null : () => _changeStatus('active'),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(t.medResume),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (status == 'active')
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _changeStatus('paused'),
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text(t.medPause),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                  // Mark completed gets more prominent, positive styling than Pause,
                  // matching web's filled success button vs. the neutral outlined Pause.
                  if (status != 'completed')
                    ElevatedButton.icon(
                      onPressed: _busy ? null : () => _changeStatus('completed'),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: Text(t.medMarkCompleted),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                    label: Text(t.commonDelete, style: TextStyle(color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.error)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {required this.t});
  final String label;
  final String? value;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final displayValue = (value == null || value!.isEmpty) ? t.medNotProvided : value!;
    final isMissing = value == null || value!.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMissing ? AppTheme.textMuted : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.t});
  final String status;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final label = status == 'active'
        ? t.medTabActive
        : status == 'completed'
            ? t.medTabCompleted
            : t.medTabPaused;
    final isActive = status == 'active';
    final isCompleted = status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.success.withValues(alpha: 0.12)
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive
              ? AppTheme.success
              : isCompleted
                  ? AppTheme.textSecondary
                  : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
