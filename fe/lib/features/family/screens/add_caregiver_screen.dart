import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/family_provider.dart';

List<String> _kTypes(AppLocalizations t) => [
      t.caregiverTypeDoctor,
      t.caregiverTypeNurse,
      t.caregiverTypeHomeAide,
      t.caregiverTypeSpecialist,
      t.caregiverTypeTherapist,
      t.caregiverTypeOther,
    ];

class AddCaregiverScreen extends ConsumerStatefulWidget {
  const AddCaregiverScreen({super.key});

  @override
  ConsumerState<AddCaregiverScreen> createState() => _AddCaregiverScreenState();
}

class _AddCaregiverScreenState extends ConsumerState<AddCaregiverScreen> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  String? _type;
  String _accessLevel = 'full';
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = ref.read(appLocalizationsProvider);
    if (_nameController.text.trim().length < 2) {
      setState(() => _error = t.famValidationNameMin);
      return;
    }
    if (_type == null) {
      setState(() => _error = t.caregiverValidationTypeRequired);
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final rel = _relationController.text.trim();
      await api.post('/family', data: {
        'full_name': _nameController.text.trim(),
        'relationship': rel.isNotEmpty ? rel : _type,
        'role': 'caregiver',
        'access_level': _accessLevel,
      });
      await refreshFamilyMembers(ref);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.caregiverAddedSnack)),
      );
    } catch (_) {
      setState(() => _error = t.caregiverAddFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/alerts'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.caregiverAddTitle,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              t.caregiverAddSubtitle,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Photo upload
            _PhotoUploadSection(t: t),

            const SizedBox(height: 24),

            // Full Name
            _fieldLabel(t.famFullNameLabel),
            _textField(
              controller: _nameController,
              hint: t.caregiverNameHint,
            ),
            const SizedBox(height: 16),

            // Type
            _fieldLabel(t.caregiverTypeLabel),
            _DropdownTrigger(
              value: _type,
              placeholder: t.caregiverTypePlaceholder,
              onTap: () => _showPicker(
                title: t.caregiverSelectTypeTitle,
                options: _kTypes(t),
                current: _type,
                onSelect: (v) => setState(() => _type = v),
              ),
            ),
            const SizedBox(height: 16),

            // Relationship (optional)
            _fieldLabel(t.caregiverRelationshipLabel),
            _textField(
              controller: _relationController,
              hint: t.caregiverRelationshipHint,
            ),
            const SizedBox(height: 24),

            // Access permission section
            Text(
              t.caregiverAccessPermissionTitle,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              t.caregiverAccessPermissionSubtitle,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            _AccessCard(
              title: t.caregiverAccessFullTitle,
              subtitle: t.caregiverAccessFullSubtitle,
              value: 'full',
              groupValue: _accessLevel,
              onTap: () => setState(() => _accessLevel = 'full'),
            ),
            const SizedBox(height: 10),
            _AccessCard(
              title: t.caregiverAccessVitalsTitle,
              subtitle: t.caregiverAccessVitalsSubtitle,
              value: 'vitals_only',
              groupValue: _accessLevel,
              onTap: () => setState(() => _accessLevel = 'vitals_only'),
            ),
            const SizedBox(height: 10),
            _AccessCard(
              title: t.caregiverAccessReadOnlyTitle,
              subtitle: t.caregiverAccessReadOnlySubtitle,
              value: 'read_only',
              groupValue: _accessLevel,
              onTap: () => setState(() => _accessLevel = 'read_only'),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
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
                        t.caregiverAddTitle,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                t.caregiverPrivacyAgreement,
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
  }) =>
      TextField(
        controller: controller,
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

// ── Access Permission Card ────────────────────────────────────────────────────

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final VoidCallback onTap;

  bool get _isSelected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isSelected ? AppTheme.primary : AppTheme.cardBorder,
            width: _isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isSelected ? AppTheme.primary : AppTheme.textMuted,
                  width: _isSelected ? 0 : 1.5,
                ),
                color: _isSelected ? AppTheme.primary : Colors.transparent,
              ),
              child: _isSelected
                  ? Center(
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: AppTheme.surface,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          _isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isSelected
                          ? AppTheme.textSecondary
                          : AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo Upload Section ──────────────────────────────────────────────────────

class _PhotoUploadSection extends StatelessWidget {
  const _PhotoUploadSection({required this.t});
  final AppLocalizations t;

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
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2F1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline,
                    color: AppTheme.primary, size: 40),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 14, color: Colors.white),
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

// ── Custom Dropdown Trigger ───────────────────────────────────────────────────

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.value,
    required this.placeholder,
    required this.onTap,
  });
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

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
                value ?? placeholder,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      value != null ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: AppTheme.primary, size: 22),
          ],
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
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
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
