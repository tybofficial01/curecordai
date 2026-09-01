import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/medications_provider.dart';

List<String> _dayLabels(AppLocalizations t) =>
    [t.dayMon, t.dayTue, t.dayWed, t.dayThu, t.dayFri, t.daySat, t.daySun];

/// Shows the edit-medication form as a single, non-stepped modal - matching web's
/// EditMedicationModal, which unlike the add flow has no "who"/"source" steps
/// since the family member and origin of a reminder cannot be changed after creation.
Future<void> showEditMedicationModal(
  BuildContext context, {
  required Map<String, dynamic> reminder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditMedicationModal(reminder: reminder),
  );
}

class _EditMedicationModal extends ConsumerStatefulWidget {
  const _EditMedicationModal({required this.reminder});
  final Map<String, dynamic> reminder;

  @override
  ConsumerState<_EditMedicationModal> createState() => _EditMedicationModalState();
}

class _EditMedicationModalState extends ConsumerState<_EditMedicationModal> {
  late final _nameCtrl =
      TextEditingController(text: widget.reminder['medication_name'] as String?);
  late final _dosageCtrl =
      TextEditingController(text: widget.reminder['dosage'] as String? ?? '');
  late final _formCtrl =
      TextEditingController(text: widget.reminder['form'] as String? ?? '');
  late final _instructionsCtrl =
      TextEditingController(text: widget.reminder['instructions'] as String? ?? '');

  late String _frequencyType = widget.reminder['frequency_type'] as String;
  late List<int> _daysOfWeek = (widget.reminder['days_of_week'] as List<dynamic>?)
          ?.cast<int>()
          .toList() ??
      [0, 1, 2, 3, 4, 5, 6];
  late int _intervalDays = widget.reminder['interval_days'] as int? ?? 2;
  late List<TimeOfDay> _times = () {
    final raw = (widget.reminder['times_of_day'] as List<dynamic>? ?? [])
        .cast<String>();
    if (raw.isEmpty) return [const TimeOfDay(hour: 9, minute: 0)];
    return raw.map((t) {
      final parts = t.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();
  }();
  late DateTime _startDate = DateTime.parse(widget.reminder['start_date'] as String);
  late DateTime? _endDate = widget.reminder['end_date'] != null
      ? DateTime.parse(widget.reminder['end_date'] as String)
      : null;
  late bool _emailEnabled = widget.reminder['email_reminders_enabled'] as bool? ?? true;
  late bool _pushEnabled = widget.reminder['push_reminders_enabled'] as bool? ?? true;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _formCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final t = ref.read(appLocalizationsProvider);
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = t.medNameRequired);
      return;
    }
    if (_frequencyType == 'specific_days' && _daysOfWeek.isEmpty) {
      setState(() => _error = t.medSelectDayRequired);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(medicationsControllerProvider).update(
        widget.reminder['id'] as String,
        {
          'medication_name': _nameCtrl.text.trim(),
          'dosage': _dosageCtrl.text.trim().isEmpty ? null : _dosageCtrl.text.trim(),
          'form': _formCtrl.text.trim().isEmpty ? null : _formCtrl.text.trim(),
          'instructions':
              _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
          'frequency_type': _frequencyType,
          if (_frequencyType == 'specific_days') 'days_of_week': _daysOfWeek,
          if (_frequencyType == 'interval') 'interval_days': _intervalDays,
          'times_of_day':
              _frequencyType == 'as_needed' ? <String>[] : _times.map(_fmtTime).toList(),
          'start_date': _startDate.toIso8601String().split('T').first,
          'end_date': _endDate?.toIso8601String().split('T').first,
          'email_reminders_enabled': _emailEnabled,
          'push_reminders_enabled': _pushEnabled,
        },
      );
      ref.invalidate(medicationsListProvider);
      ref.invalidate(medicationDetailProvider(widget.reminder['id'] as String));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _error = t.medUpdateFailed;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final dayNames = _dayLabels(t);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.medEditTitle,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(t.medEditDescription,
                            style: TextStyle(
                                fontSize: 12.5, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: t.commonClose,
                    icon: Icon(Icons.close, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(t.medFieldName, _nameCtrl),
                    _field(t.medFieldDosage, _dosageCtrl, hint: t.medDosageHint),
                    _field(t.medFieldForm, _formCtrl, hint: t.medFormHint),
                    _field(t.medFieldInstructions, _instructionsCtrl, maxLines: 2),
                    Text(t.medFrequencyLabel,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    DropdownButton<String>(
                      value: _frequencyType,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: 'daily', child: Text(t.medFreqDaily)),
                        DropdownMenuItem(
                            value: 'specific_days', child: Text(t.medFreqSpecificDays)),
                        DropdownMenuItem(value: 'interval', child: Text(t.medFreqInterval)),
                        DropdownMenuItem(value: 'as_needed', child: Text(t.medFreqAsNeeded)),
                      ],
                      onChanged: (v) => setState(() => _frequencyType = v!),
                    ),
                    const SizedBox(height: 12),
                    if (_frequencyType == 'specific_days')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (i) {
                          final selected = _daysOfWeek.contains(i);
                          return ChoiceChip(
                            label: Text(dayNames[i]),
                            selected: selected,
                            onSelected: (v) => setState(() {
                              _daysOfWeek = v
                                  ? ([..._daysOfWeek, i]..sort())
                                  : _daysOfWeek.where((d) => d != i).toList();
                            }),
                          );
                        }),
                      ),
                    if (_frequencyType == 'interval') ...[
                      const SizedBox(height: 8),
                      Text(t.medEveryLabel,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(text: '$_intervalDays'),
                              onChanged: (v) =>
                                  _intervalDays = int.tryParse(v) ?? _intervalDays,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(t.medDaysUnit),
                        ],
                      ),
                    ],
                    if (_frequencyType != 'as_needed') ...[
                      const SizedBox(height: 16),
                      Text(t.medReminderTimes,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      for (var i = 0; i < _times.length; i++)
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                    context: context, initialTime: _times[i]);
                                if (picked != null) setState(() => _times[i] = picked);
                              },
                              child: Text(_fmtTime(_times[i])),
                            ),
                            if (_times.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _times.removeAt(i)),
                              ),
                          ],
                        ),
                      TextButton.icon(
                        onPressed: () => setState(
                            () => _times.add(const TimeOfDay(hour: 9, minute: 0))),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(t.medAddAnotherTime),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(t.medStartDate,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                      child: Text(_startDate.toIso8601String().split('T').first),
                    ),
                    Text(t.medEndDateOptional,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                      child: Text(_endDate?.toIso8601String().split('T').first ?? t.medOngoing),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _emailEnabled,
                      onChanged: (v) => setState(() => _emailEnabled = v ?? true),
                      title: Text(t.medEmailReminder),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: _pushEnabled,
                      onChanged: (v) => setState(() => _pushEnabled = v ?? true),
                      title: Text(t.medPushReminder),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? t.medSaving : t.medSaveChanges),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
