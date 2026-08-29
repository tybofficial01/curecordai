import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/info_explainer_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/family_provider.dart';
import '../providers/medications_provider.dart';
import '../widgets/add_medication_modal.dart';
import '../widgets/edit_medication_modal.dart';

const _kStatusTabs = ['active', 'paused', 'completed', 'all'];

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  String _statusTab = 'active';
  String? _rowError;
  String? _busyId;

  static void _showMedicationsInfo(BuildContext context, AppLocalizations t) {
    showInfoExplainerDialog(
      context,
      title: t.medicationsInfoModalTitle,
      gotItLabel: t.commonGotIt,
      items: [
        InfoExplainerItem(
          icon: Icons.person_outline,
          title: t.medicationsInfoWhoTitle,
          description: t.medicationsInfoWhoDescription,
        ),
        InfoExplainerItem(
          icon: Icons.assignment_outlined,
          title: t.medicationsInfoAddTitle,
          description: t.medicationsInfoAddDescription,
        ),
        InfoExplainerItem(
          icon: Icons.check_circle_outline,
          title: t.medicationsInfoTrackTitle,
          description: t.medicationsInfoTrackDescription,
        ),
      ],
    );
  }

  String _tabLabel(AppLocalizations t, String tab) {
    switch (tab) {
      case 'active':
        return t.medTabActive;
      case 'paused':
        return t.medTabPaused;
      case 'completed':
        return t.medTabCompleted;
      default:
        return t.medTabAll;
    }
  }

  Future<void> _delete(Map<String, dynamic> medication, AppLocalizations t) async {
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
    final id = medication['id'] as String;
    setState(() {
      _busyId = id;
      _rowError = null;
    });
    try {
      await ref.read(medicationsControllerProvider).delete(id);
      ref.invalidate(medicationsListProvider);
    } catch (_) {
      if (mounted) setState(() => _rowError = t.medDeleteFailed);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final medsAsync = ref.watch(medicationsListProvider);
    final familyAsync = ref.watch(familyMembersProvider);
    final hasAnyMedications = (medsAsync.value?.length ?? 0) > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.medicationsTitle,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppTheme.textMuted),
            tooltip: t.medicationsInfoAria,
            onPressed: () => _showMedicationsInfo(context, t),
          ),
          if (hasAnyMedications)
            IconButton(
              icon: const Icon(Icons.add_circle, size: 26),
              color: AppTheme.primary,
              onPressed: () => showAddMedicationModal(context, ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(medicationsListProvider),
        child: medsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      color: AppTheme.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text(t.medicationsLoadFailed,
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(medicationsListProvider),
                    child: Text(t.commonRetry),
                  ),
                ],
              ),
            ),
          ]),
          data: (medications) {
            final filtered = _statusTab == 'all'
                ? medications
                : medications.where((m) => m['status'] == _statusTab).toList();

            final counts = <String, int>{'active': 0, 'paused': 0, 'completed': 0};
            for (final m in medications) {
              final status = m['status'] as String;
              counts[status] = (counts[status] ?? 0) + 1;
            }
            final otherStatuses = ['active', 'paused', 'completed']
                .where((s) => s != _statusTab && (counts[s] ?? 0) > 0)
                .toList();

            final familyById = <String, Map<String, dynamic>>{
              for (final m in familyAsync.value ?? <Map<String, dynamic>>[])
                m['id'].toString(): m,
            };
            final groups = <String, List<Map<String, dynamic>>>{};
            for (final med in filtered) {
              final key = med['family_member_id']?.toString() ?? 'self';
              groups.putIfAbsent(key, () => []).add(med);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tab in _kStatusTabs)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _StatusTabChip(
                            label: _tabLabel(t, tab),
                            selected: _statusTab == tab,
                            onTap: () => setState(() => _statusTab = tab),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_rowError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_rowError!, style: TextStyle(color: AppTheme.error, fontSize: 13)),
                  ),
                if (!hasAnyMedications)
                  _ZeroMedicationsState(t: t)
                else if (filtered.isEmpty)
                  _TabEmptyState(
                    t: t,
                    status: _statusTab,
                    otherStatuses: otherStatuses,
                    counts: counts,
                    tabLabelOf: (s) => _tabLabel(t, s),
                  )
                else
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                        ),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          entry.key == 'self'
                              ? t.commonYou
                              : (familyById[entry.key]?['full_name'] as String?) ??
                                  t.medFamilyMemberFallback,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    for (final med in entry.value)
                      _MedicationCard(
                        medication: med,
                        t: t,
                        busy: _busyId == med['id'],
                        onEdit: () => showEditMedicationModal(context, reminder: med),
                        onDelete: () => _delete(med, t),
                      ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Status filter chip ───────────────────────────────────────────────────────

class _StatusTabChip extends StatelessWidget {
  const _StatusTabChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Zero medications state ───────────────────────────────────────────────────

class _ZeroMedicationsState extends ConsumerWidget {
  const _ZeroMedicationsState({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medication_outlined, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(height: 14),
              Text(t.medicationsEmptyTitle,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(
                t.medicationsEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => showAddMedicationModal(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t.medicationsAddButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ExplainerCard(
                icon: Icons.warning_amber_rounded,
                accent: AppTheme.warning,
                title: t.medExplainerAllergiesTitle,
                description: t.medExplainerAllergiesDescription,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ExplainerCard(
                icon: Icons.description_outlined,
                accent: AppTheme.info,
                title: t.medExplainerDocumentsTitle,
                description: t.medExplainerDocumentsDescription,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(description,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Tab-specific (lightweight) empty state ───────────────────────────────────

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({
    required this.t,
    required this.status,
    required this.otherStatuses,
    required this.counts,
    required this.tabLabelOf,
  });
  final AppLocalizations t;
  /// Raw status ("active"/"paused"/"completed") - never "all" when this
  /// widget is shown, see MedicationsScreen.
  final String status;
  final List<String> otherStatuses;
  final Map<String, int> counts;
  final String Function(String) tabLabelOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Text(
            _noMedicationsMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          if (otherStatuses.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              t.medOtherTabsNote(otherStatuses
                  .map((s) => '${counts[s]} ${tabLabelOf(s)}')
                  .join(', ')),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String get _noMedicationsMessage {
    if (status == 'paused') return t.medNoPausedMedications;
    if (status == 'completed') return t.medNoCompletedMedications;
    return t.medNoActiveMedications;
  }
}

// ── Medication row card ──────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.t,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> medication;
  final AppLocalizations t;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _frequencySummary {
    final freq = medication['frequency_type'] as String;
    final times = (medication['times_of_day'] as List<dynamic>? ?? []);
    if (freq == 'as_needed') return t.medFreqAsNeededSummary;
    final timesLabel = times.isNotEmpty ? times.join(', ') : '';
    switch (freq) {
      case 'daily':
        return t.medFreqDailySummary(timesLabel);
      case 'interval':
        return t.medFreqIntervalSummary(
            '${medication['interval_days']}', timesLabel);
      case 'specific_days':
        return timesLabel;
      default:
        return timesLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = medication['status'] as String;
    final isActive = status == 'active';
    final isPaused = status == 'paused';
    final isCompleted = status == 'completed';
    final dosage = medication['dosage'] as String?;
    final form = medication['form'] as String?;

    return Opacity(
      opacity: isPaused ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: AppTheme.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/medications/${medication['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.surfaceVariant,
                  child: Icon(Icons.medication, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication['medication_name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(_frequencySummary,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 3),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          children: [
                            TextSpan(text: '${t.medRowDosage}: '),
                            TextSpan(
                              text: dosage ?? t.medNotProvided,
                              style: TextStyle(color: dosage == null ? AppTheme.textMuted : null),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(text: '${t.medRowForm}: '),
                            TextSpan(
                              text: form ?? t.medNotProvided,
                              style: TextStyle(color: form == null ? AppTheme.textMuted : null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.success.withValues(alpha: 0.12)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive
                            ? t.medTabActive
                            : isCompleted
                                ? t.medTabCompleted
                                : t.medTabPaused,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive ? AppTheme.success : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        InkWell(
                          onTap: onEdit,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.edit_outlined,
                                size: 18, color: AppTheme.textMuted),
                          ),
                        ),
                        InkWell(
                          onTap: busy ? null : onDelete,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: busy
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppTheme.error),
                                  )
                                : Icon(Icons.delete_outline,
                                    size: 18, color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
