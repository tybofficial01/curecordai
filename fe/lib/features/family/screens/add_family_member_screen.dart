import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/family_provider.dart';

// ── Relationship options ─────────────────────────────────────────────────────
//
// Values are sent to the backend verbatim (a free text field with no enum
// constraint), so this list uses the same canonical English words as the web
// add form - only the label shown to the user is localized.
const _kRelationValues = [
  'Spouse',
  'Parent',
  'Father',
  'Mother',
  'Child',
  'Son',
  'Daughter',
  'Sibling',
  'Other',
];

String _relationLabel(AppLocalizations t, String value) {
  switch (value) {
    case 'Spouse':
      return t.relSpouse;
    case 'Parent':
      return t.relParent;
    case 'Father':
      return t.relFather;
    case 'Mother':
      return t.relMother;
    case 'Child':
      return t.relChild;
    case 'Son':
      return t.relSon;
    case 'Daughter':
      return t.relDaughter;
    case 'Sibling':
      return t.relSibling;
    default:
      return t.relOther;
  }
}

List<String> _kGenders(AppLocalizations t) =>
    [t.genderMale, t.genderFemale, t.genderOther];

const _kBloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

const _kRoleValues = ['dependent', 'caregiver'];

String _roleLabel(AppLocalizations t, String value) =>
    value == 'caregiver' ? t.famRoleCaregiver : t.famRoleDependent;

String _initialsFor(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}

class AddFamilyMemberScreen extends ConsumerStatefulWidget {
  const AddFamilyMemberScreen({super.key, this.editMemberId, this.initialRelation});

  /// When set, this screen edits the existing member instead of creating one.
  final String? editMemberId;

  /// Preselects a relation, used by the empty state's relation shortcut cards.
  final String? initialRelation;

  @override
  ConsumerState<AddFamilyMemberScreen> createState() =>
      _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends ConsumerState<AddFamilyMemberScreen> {
  final _nameController = TextEditingController();
  String? _relationship;
  String _role = 'dependent';
  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  bool _isSaving = false;
  bool _prefilled = false;
  String? _error;

  bool get _isEditing => widget.editMemberId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialRelation != null &&
        _kRelationValues.contains(widget.initialRelation)) {
      _relationship = widget.initialRelation;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _prefillFrom(Map<String, dynamic> member) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = member['full_name'] as String? ?? '';
    final relationship = member['relationship'] as String?;
    _relationship =
        _kRelationValues.contains(relationship) ? relationship : 'Other';
    _role = member['role'] as String? ?? 'dependent';
    final gender = member['gender'] as String?;
    if (gender != null) {
      final t = ref.read(appLocalizationsProvider);
      final genders = _kGenders(t);
      final values = ['male', 'female', 'other'];
      final index = values.indexOf(gender);
      _gender = index >= 0 ? genders[index] : null;
    }
    _bloodGroup = member['blood_group'] as String?;
    final dob = member['date_of_birth'] as String?;
    if (dob != null) _dob = DateTime.tryParse(dob);
  }

  // ── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppTheme.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final t = ref.read(appLocalizationsProvider);
    if (_nameController.text.trim().length < 2) {
      setState(() => _error = t.famValidationNameMin);
      return;
    }
    if (_relationship == null) {
      setState(() => _error = t.famValidationRelationshipRequired);
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final trimmedName = _nameController.text.trim();
    final dobValue = _dob == null
        ? null
        : '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';
    final genderValue =
        _gender == null ? null : ['male', 'female', 'other'][_kGenders(t).indexOf(_gender!)];
    try {
      final api = ref.read(apiClientProvider);
      if (_isEditing) {
        // Role is not editable after creation, matching the backend's update
        // contract, so it is intentionally left out of this payload.
        await api.patch('/family/${widget.editMemberId}', data: {
          'full_name': trimmedName,
          'relationship': _relationship,
          if (dobValue != null) 'date_of_birth': dobValue,
          if (genderValue != null) 'gender': genderValue,
          if (_bloodGroup != null) 'blood_group': _bloodGroup,
        });
      } else {
        await api.post('/family', data: {
          'full_name': trimmedName,
          'relationship': _relationship,
          'role': _role,
          'access_level': 'full',
          if (dobValue != null) 'date_of_birth': dobValue,
          if (genderValue != null) 'gender': genderValue,
          if (_bloodGroup != null) 'blood_group': _bloodGroup,
        });
      }
      await refreshFamilyMembers(ref);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? t.famUpdateSuccess(trimmedName)
              : t.famAddedSnack(trimmedName)),
        ),
      );
    } catch (_) {
      setState(() => _error = _isEditing ? t.famUpdateFailed : t.famAddFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);

    if (_isEditing) {
      final memberAsync = ref.watch(familyMemberDetailProvider(widget.editMemberId!));
      return memberAsync.when(
        loading: () => Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: Text(t.famEditMemberTitle)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: Text(t.famEditMemberTitle)),
          body: Center(child: Text(t.famUpdateFailed)),
        ),
        data: (member) {
          _prefillFrom(member);
          return _buildForm(t);
        },
      );
    }

    return _buildForm(t);
  }

  Widget _buildForm(AppLocalizations t) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEditing ? t.famEditMemberTitle : t.familyAddMemberTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? t.famEditMemberSubtitle : t.famAddSubtitle,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Photo placeholder - no upload capability yet, purely decorative.
            _PhotoUploadSection(t: t, initials: _initialsFor(_nameController.text)),

            const SizedBox(height: 24),

            // Full name
            _fieldLabel(t.famFullNameLabel),
            _textField(
              controller: _nameController,
              hint: t.famNameHintFamily,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Role - its own full width row, locked once a member exists.
            _fieldLabel(t.famRoleLabel),
            _DropdownTrigger(
              value: _roleLabel(t, _role),
              placeholder: t.famRoleLabel,
              enabled: !_isEditing,
              onTap: () => _showPicker(
                title: t.famRoleLabel,
                options: _kRoleValues.map((v) => _roleLabel(t, v)).toList(),
                current: _roleLabel(t, _role),
                onSelect: (label) => setState(() =>
                    _role = _kRoleValues.firstWhere((v) => _roleLabel(t, v) == label)),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 6),
              Text(
                t.famRoleLockedHint,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 16),

            // Relation
            _fieldLabel(t.famRelationshipLabel),
            _DropdownTrigger(
              value: _relationship == null ? null : _relationLabel(t, _relationship!),
              placeholder: t.famRelationshipPlaceholder,
              onTap: () => _showPicker(
                title: t.famSelectRelationshipTitle,
                options: _kRelationValues.map((v) => _relationLabel(t, v)).toList(),
                current: _relationship == null ? null : _relationLabel(t, _relationship!),
                onSelect: (label) => setState(() => _relationship =
                    _kRelationValues.firstWhere((v) => _relationLabel(t, v) == label)),
              ),
            ),
            const SizedBox(height: 16),

            // Date of birth
            _fieldLabel(t.famDobLabel),
            _DobTrigger(dob: _dob, onTap: _pickDob, t: t),
            const SizedBox(height: 16),

            // Gender
            _fieldLabel(t.famGenderLabel),
            _DropdownTrigger(
              value: _gender,
              placeholder: t.famGenderPlaceholder,
              onTap: () => _showPicker(
                title: t.famSelectGenderTitle,
                options: _kGenders(t),
                current: _gender,
                onSelect: (v) => setState(() => _gender = v),
              ),
            ),
            const SizedBox(height: 16),

            // Blood group
            _fieldLabel(t.famBloodGroupLabel),
            _BloodGroupGrid(
              selected: _bloodGroup,
              onSelect: (v) => setState(() => _bloodGroup = v),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
              ),
            ],

            const SizedBox(height: 32),

            // Submit button - right aligned, matching the web form.
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isEditing ? t.famSaveChanges : t.familyAddMemberTitle,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                t.famPrivacyAgreementMember,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showPicker({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String> onSelect,
  }) {
    final t = ref.read(appLocalizationsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PickerSheet(
        title: title,
        options: options,
        current: current,
        t: t,
        onSelect: (v) {
          onSelect(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary),
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 15, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.textMuted),
          filled: true,
          fillColor: AppTheme.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      );
}

// ── Photo Upload Section ─────────────────────────────────────────────────────

class _PhotoUploadSection extends StatelessWidget {
  const _PhotoUploadSection({required this.t, required this.initials});
  final AppLocalizations t;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.card, width: 2),
                  ),
                  child: Icon(Icons.add, size: 14, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.famPhotoUploadTitle,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            t.famPhotoUploadHint,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Custom Dropdown Trigger ──────────────────────────────────────────────────

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.enabled = true,
  });

  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      value != null ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
            ),
            if (enabled)
              Icon(Icons.keyboard_arrow_down, color: AppTheme.primary, size: 22)
            else
              Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── DOB Trigger ──────────────────────────────────────────────────────────────

class _DobTrigger extends StatelessWidget {
  const _DobTrigger({required this.dob, required this.onTap, required this.t});
  final DateTime? dob;
  final VoidCallback onTap;
  final AppLocalizations t;

  String get _display {
    if (dob == null) return t.famDobPlaceholder;
    return '${dob!.day.toString().padLeft(2, '0')} / '
        '${dob!.month.toString().padLeft(2, '0')} / '
        '${dob!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _display,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      dob != null ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                color: AppTheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Blood Group Grid ──────────────────────────────────────────────────────────

class _BloodGroupGrid extends StatelessWidget {
  const _BloodGroupGrid({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const gaps = 3 * 8.0;
        final cellWidth = (constraints.maxWidth - gaps) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kBloodGroups
              .map((bg) => _BloodGroupCell(
                    label: bg,
                    isSelected: selected == bg,
                    width: cellWidth,
                    onTap: () => onSelect(bg),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _BloodGroupCell extends StatelessWidget {
  const _BloodGroupCell({
    required this.label,
    required this.isSelected,
    required this.width,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Picker Bottom Sheet ───────────────────────────────────────────────────────

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.onSelect,
    required this.t,
  });
  final String title;
  final List<String> options;
  final String? current;
  final ValueChanged<String> onSelect;
  final AppLocalizations t;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late String? _temp;

  @override
  void initState() {
    super.initState();
    _temp = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
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
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: EdgeInsets.zero,
              itemCount: widget.options.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 0, thickness: 0.5, color: Color(0xFFF0F0F0)),
              itemBuilder: (_, i) {
                final opt = widget.options[i];
                final isSelected = opt == _temp;
                return InkWell(
                  onTap: () => setState(() => _temp = opt),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 15,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, color: AppTheme.primary, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (_temp != null) widget.onSelect(_temp!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  widget.t.commonDone,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
