import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/progress_step_bar.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../family/providers/family_provider.dart';
import '../providers/medications_provider.dart';

enum _Step { who, member, source, document, details, schedule }

/// The step indicator's total count depends on the path taken, matching web's
/// stepsForPath - a family member path inserts a "member" selection step, and
/// importing from a document inserts a "document" selection step.
List<_Step> _stepsForPath(bool isFamilyPath, String source) => [
      _Step.who,
      if (isFamilyPath) _Step.member,
      _Step.source,
      if (source == 'document') _Step.document,
      _Step.details,
      _Step.schedule,
    ];

List<String> _dayLabels(AppLocalizations t) =>
    [t.dayMon, t.dayTue, t.dayWed, t.dayThu, t.dayFri, t.daySat, t.daySun];

/// Returned when a medication was successfully created, so the caller can show
/// a success toast with its name (and who it was added for) after the sheet closes.
class AddMedicationResult {
  const AddMedicationResult({required this.medicationName, this.familyMemberName});
  final String medicationName;
  final String? familyMemberName;
}

/// Shows the add-medication flow as a single modal with a fixed header and step
/// indicator, matching web's AddMedicationModal, instead of a separate routed page.
Future<void> showAddMedicationModal(BuildContext context, WidgetRef ref) async {
  final t = ref.read(appLocalizationsProvider);
  final result = await showModalBottomSheet<AddMedicationResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddMedicationModal(),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.familyMemberName != null
          ? t.medAddedForMember(result.medicationName, result.familyMemberName!)
          : t.medAddedSnack(result.medicationName)),
    ));
  }
}

class _AddMedicationModal extends ConsumerStatefulWidget {
  const _AddMedicationModal();

  @override
  ConsumerState<_AddMedicationModal> createState() => _AddMedicationModalState();
}

class _AddMedicationModalState extends ConsumerState<_AddMedicationModal> {
  _Step _step = _Step.who;
  String? _defaultFamilyMemberId;
  String? _familyMemberId;
  bool _showNoFamilyMembers = false;

  String _source = 'manual';
  String? _selectedRecordId;
  List<Map<String, dynamic>> _recordMedications = [];
  bool _loadingRecordMeds = false;
  String? _medicationRequestId;

  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _formCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  String _frequencyType = 'daily';
  List<int> _daysOfWeek = [0, 1, 2, 3, 4, 5, 6];
  int _intervalDays = 2;
  List<TimeOfDay> _times = [const TimeOfDay(hour: 9, minute: 0)];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _emailEnabled = true;
  bool _pushEnabled = true;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _defaultFamilyMemberId = ref.read(activeMemberIdProvider);
    _familyMemberId = _defaultFamilyMemberId;
  }

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

  bool get _isFamilyPath => _step == _Step.member || _familyMemberId != null;

  void _goBack() {
    setState(() {
      _error = null;
      switch (_step) {
        case _Step.member:
          _step = _Step.who;
          break;
        case _Step.source:
          _step = _familyMemberId == null ? _Step.who : _Step.member;
          break;
        case _Step.document:
          if (_selectedRecordId != null) {
            _selectedRecordId = null;
          } else {
            _step = _Step.source;
          }
          break;
        case _Step.details:
          _step = _source == 'document' ? _Step.document : _Step.source;
          break;
        case _Step.schedule:
          _step = _Step.details;
          break;
        case _Step.who:
          break;
      }
    });
  }

  Future<void> _selectDocument(String recordId) async {
    setState(() {
      _selectedRecordId = recordId;
      _loadingRecordMeds = true;
      _error = null;
    });
    try {
      final meds = await ref.read(recordMedicationsProvider(recordId).future);
      if (mounted) setState(() => _recordMedications = meds);
    } catch (_) {
      final t = ref.read(appLocalizationsProvider);
      if (mounted) setState(() => _error = t.medCouldNotLoadMedications);
    } finally {
      if (mounted) setState(() => _loadingRecordMeds = false);
    }
  }

  void _pickExtractedMedication(Map<String, dynamic> med) {
    setState(() {
      _medicationRequestId = med['id']?.toString();
      _nameCtrl.text = med['medication_name_raw']?.toString() ?? '';
      _dosageCtrl.text = med['dose_quantity']?.toString() ?? '';
      _instructionsCtrl.text = med['dosage_instruction']?.toString() ?? '';
      _step = _Step.details;
    });
  }

  Future<void> _submit() async {
    final t = ref.read(appLocalizationsProvider);
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = t.medNameRequired);
      return;
    }
    if (_frequencyType != 'as_needed' && _times.isEmpty) {
      setState(() => _error = t.medSelectDayRequired);
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
      String timezone = 'UTC';
      try {
        timezone = await FlutterTimezone.getLocalTimezone();
      } catch (_) {
        // Falls back to UTC - the on-device alarm still fires at the right local
        // time regardless, this only affects reminder email wording server-side.
      }
      final created = await ref.read(medicationsControllerProvider).create({
        'family_member_id': _familyMemberId,
        'source': _source,
        if (_source == 'document') 'medication_request_id': _medicationRequestId,
        if (_source == 'document') 'source_record_id': _selectedRecordId,
        'medication_name': _nameCtrl.text.trim(),
        if (_dosageCtrl.text.trim().isNotEmpty) 'dosage': _dosageCtrl.text.trim(),
        if (_formCtrl.text.trim().isNotEmpty) 'form': _formCtrl.text.trim(),
        if (_instructionsCtrl.text.trim().isNotEmpty)
          'instructions': _instructionsCtrl.text.trim(),
        'frequency_type': _frequencyType,
        if (_frequencyType == 'specific_days') 'days_of_week': _daysOfWeek,
        if (_frequencyType == 'interval') 'interval_days': _intervalDays,
        'times_of_day':
            _frequencyType == 'as_needed' ? <String>[] : _times.map(_fmtTime).toList(),
        'timezone': timezone,
        'start_date': _startDate.toIso8601String().split('T').first,
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T').first,
        'email_reminders_enabled': _emailEnabled,
        'push_reminders_enabled': _pushEnabled,
      });
      ref.invalidate(medicationsListProvider);
      String? memberName;
      if (_familyMemberId != null) {
        final members = await ref.read(familyMembersProvider.future);
        memberName = members.firstWhere(
          (m) => m['id'].toString() == _familyMemberId,
          orElse: () => const {},
        )['full_name'] as String?;
      }
      if (!mounted) return;
      Navigator.of(context).pop(AddMedicationResult(
        medicationName: created['medication_name'] as String,
        familyMemberName: memberName,
      ));
    } catch (_) {
      setState(() {
        _error = t.medSaveFailed;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final steps = _stepsForPath(_isFamilyPath, _source);
    final stepIndex = steps.indexOf(_step) + 1;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Fixed header - back arrow (hidden on the first step), title,
            // subtitle, and a close button, matching web's modal header.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_step != _Step.who)
                    IconButton(
                      onPressed: _goBack,
                      tooltip: t.medBackStep,
                      icon: Icon(Icons.arrow_back, color: AppTheme.textSecondary),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.medAddTitle,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(t.medAddDescription,
                              style: TextStyle(
                                  fontSize: 12.5, color: AppTheme.textSecondary)),
                        ],
                      ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ProgressStepBar(currentStep: stepIndex, totalSteps: steps.length),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _buildStep(t),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations t) {
    switch (_step) {
      case _Step.who:
        return _whoStep(t);
      case _Step.member:
        return _memberStep(t);
      case _Step.source:
        return _sourceStep(t);
      case _Step.document:
        return _documentStep(t);
      case _Step.details:
        return _detailsStep(t);
      case _Step.schedule:
        return _scheduleStep(t);
    }
  }

  Widget _whoStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.medWhoIsFor,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        _choiceTile(
          title: _defaultFamilyMemberId == null
              ? '${t.medMyself} · ${t.medCurrentlySelected}'
              : t.medMyself,
          subtitle: t.medMyselfHint,
          icon: Icons.person_outline,
          onTap: () => setState(() {
            _familyMemberId = null;
            _showNoFamilyMembers = false;
            _step = _Step.source;
          }),
        ),
        _choiceTile(
          title: t.medFamilyMemberTileTitle,
          subtitle: t.medFamilyMemberHint,
          icon: Icons.groups_outlined,
          onTap: () {
            final members = ref.read(familyMembersProvider).value ?? [];
            if (members.isEmpty) {
              setState(() => _showNoFamilyMembers = true);
              return;
            }
            setState(() {
              _showNoFamilyMembers = false;
              _step = _Step.member;
            });
          },
        ),
        if (_showNoFamilyMembers)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.medNoFamilyMembersYet,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/family/add');
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(t.familyAddMemberTitle),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _memberStep(AppLocalizations t) {
    final familyAsync = ref.watch(familyMembersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.medSelectFamilyMemberPrompt,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...familyAsync.maybeWhen(
          data: (members) => members.map((m) {
            final id = m['id'].toString();
            final isCurrent = _defaultFamilyMemberId == id;
            final subtitle = isCurrent
                ? '${m['relationship']} · ${t.medCurrentlySelected}'
                : '${m['relationship']}';
            return _choiceTile(
              title: m['full_name'] as String,
              subtitle: subtitle,
              selected: _familyMemberId == id,
              onTap: () => setState(() {
                _familyMemberId = id;
                _step = _Step.source;
              }),
            );
          }),
          orElse: () => const <Widget>[],
        ),
      ],
    );
  }

  Widget _sourceStep(AppLocalizations t) {
    final memberName = _familyMemberId == null
        ? null
        : (ref.watch(familyMembersProvider).value ?? [])
            .firstWhere((m) => m['id'].toString() == _familyMemberId,
                orElse: () => const {})['full_name'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (memberName != null) ...[
          Text(t.medForMember(memberName),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
        ],
        Text(t.medHowToAdd,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        _choiceTile(
          title: t.medSelectFromDocument,
          subtitle: t.medSelectFromDocumentSubtitle,
          icon: Icons.description_outlined,
          onTap: () => setState(() {
            _source = 'document';
            _step = _Step.document;
          }),
        ),
        _choiceTile(
          title: t.medAddManually,
          subtitle: t.medAddManuallySubtitle,
          icon: Icons.edit_outlined,
          onTap: () => setState(() {
            _source = 'manual';
            _medicationRequestId = null;
            _selectedRecordId = null;
            _step = _Step.details;
          }),
        ),
      ],
    );
  }

  Widget _documentStep(AppLocalizations t) {
    if (_selectedRecordId == null) {
      final recordsAsync = ref.watch(recordsForMedicationProvider(_familyMemberId));
      return recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(t.medCouldNotLoadDocuments)),
        data: (records) {
          if (records.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.upload_file_outlined, color: AppTheme.info),
                ),
                const SizedBox(height: 14),
                Text(t.medNoDocumentsUploaded,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/records/upload');
                  },
                  child: Text(t.homeUploadDocument),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.medSelectDocument,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              for (final r in records)
                _choiceTile(
                  title: r['title'] as String,
                  subtitle: (r['uploaded_at'] as String).split('T').first,
                  onTap: () => _selectDocument(r['id'].toString()),
                ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.medSelectMedicationFromDocument,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        if (_loadingRecordMeds)
          const Center(child: CircularProgressIndicator())
        else if (_recordMedications.isEmpty)
          Text(t.medNoMedicationsExtracted, style: TextStyle(color: AppTheme.textSecondary))
        else
          for (final med in _recordMedications)
            _choiceTile(
              title: med['medication_name_raw'] as String? ?? t.medUnknownMedication,
              subtitle: () {
                final summary = [med['dose_quantity'], med['dose_frequency']]
                    .where((e) => e != null)
                    .join(' · ');
                return summary.isEmpty ? t.medNoDosageDetails : summary;
              }(),
              onTap: () => _pickExtractedMedication(med),
            ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _selectedRecordId = null),
          child: Text(t.medChooseDifferentDocument),
        ),
      ],
    );
  }

  Widget _detailsStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(t.medFieldName, _nameCtrl),
        _field(t.medFieldDosage, _dosageCtrl, hint: t.medDosageHint),
        _field(t.medFieldForm, _formCtrl, hint: t.medFormHint),
        _field(t.medFieldInstructions, _instructionsCtrl, maxLines: 2),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _nameCtrl.text.trim().isEmpty
              ? null
              : () => setState(() => _step = _Step.schedule),
          child: Text(t.medContinueToSchedule),
        ),
      ],
    );
  }

  Widget _scheduleStep(AppLocalizations t) {
    final dayNames = _dayLabels(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.medFrequencyLabel,
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        DropdownButton<String>(
          value: _frequencyType,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'daily', child: Text(t.medFreqDaily)),
            DropdownMenuItem(value: 'specific_days', child: Text(t.medFreqSpecificDays)),
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
                  _daysOfWeek =
                      v ? ([..._daysOfWeek, i]..sort()) : _daysOfWeek.where((d) => d != i).toList();
                }),
              );
            }),
          ),
        if (_frequencyType == 'interval') ...[
          const SizedBox(height: 8),
          Text(t.medEveryLabel,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Row(
            children: [
              SizedBox(
                width: 70,
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: '$_intervalDays'),
                  onChanged: (v) => _intervalDays = int.tryParse(v) ?? _intervalDays,
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
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          for (var i = 0; i < _times.length; i++)
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _times[i]);
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
            onPressed: () =>
                setState(() => _times.add(const TimeOfDay(hour: 9, minute: 0))),
            icon: const Icon(Icons.add, size: 18),
            label: Text(t.medAddAnotherTime),
          ),
        ],
        const SizedBox(height: 12),
        Text(t.medStartDate,
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
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
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
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
            child: Text(_submitting ? t.medSaving : t.medSaveReminder),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _choiceTile({
    required String title,
    String? subtitle,
    IconData? icon,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppTheme.primary : AppTheme.cardBorder),
      ),
      child: ListTile(
        leading: icon != null ? Icon(icon, color: AppTheme.primary) : null,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        onTap: onTap,
      ),
    );
  }
}
