import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../family/providers/family_provider.dart';

// These four are exported (not file-private) so auth_provider.dart can
// invalidate them on logout - see _invalidateCachedDataProviders there.
final emergencySettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final response = await api.get<Map<String, dynamic>>(
    '/emergency/settings',
    queryParameters: memberId != null ? {'family_member_id': memberId} : null,
    cachePolicy: CachePolicy.refreshForceCache,
  );
  return response.data ?? {};
});

final emergencyContactsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final response = await api.get<List<dynamic>>(
    '/emergency/contacts',
    queryParameters: memberId != null ? {'family_member_id': memberId} : null,
    cachePolicy: CachePolicy.refreshForceCache,
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

/// Real blood group for the active profile (owner's own `/users/me`, or the active family
/// member's record) - the emergency settings response only ever holds the display toggles,
/// never the underlying health data, so the preview card must fetch this separately.
final activeBloodGroupProvider = FutureProvider<String?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  if (memberId != null) {
    final member = await ref.watch(familyMemberDetailProvider(memberId).future);
    return member['blood_group'] as String?;
  }
  final response = await api.get<Map<String, dynamic>>('/users/me',
      cachePolicy: CachePolicy.refreshForceCache);
  return response.data?['blood_group'] as String?;
});

/// Active allergies for the active profile - used to show a real substance on the preview
/// card instead of the Figma placeholder ("Penicillin").
final emergencyActiveAllergiesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final response = await api.get<List<dynamic>>(
    '/allergies',
    queryParameters: {
      'clinical_status': 'active',
      if (memberId != null) 'family_member_id': memberId,
    },
    cachePolicy: CachePolicy.refreshForceCache,
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  // Lock screen widget toggles - hydrated from the backend once settings load (see
  // _hydrateFromSettings), not hardcoded - defaults here only cover the brief loading window.
  bool _showBloodGroup = true;
  bool _showAllergies = true;
  bool _showEmergencyContact = true;
  bool _showChronicConditions = false;
  bool _lockScreenWidgetEnabled = true;
  bool _isSaving = false;
  bool _settingsHydrated = false;

  // Add contact
  bool _isAddingContact = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _contactRelation = 'Family';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _hydrateFromSettings(Map<String, dynamic> settings) {
    if (_settingsHydrated || settings.isEmpty) return;
    _settingsHydrated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showBloodGroup = settings['show_blood_group'] as bool? ?? true;
        _showAllergies = settings['show_allergies'] as bool? ?? true;
        _showEmergencyContact =
            settings['show_emergency_contacts'] as bool? ?? true;
        _showChronicConditions =
            settings['show_chronic_conditions'] as bool? ?? false;
        _lockScreenWidgetEnabled =
            settings['lock_screen_widget_enabled'] as bool? ?? true;
      });
    });
  }

  Future<void> _saveSettings() async {
    final t = ref.read(appLocalizationsProvider);
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      final memberId = ref.read(activeMemberIdProvider);
      await api.patch('/emergency/settings', data: {
        'show_blood_group': _showBloodGroup,
        'show_allergies': _showAllergies,
        'show_emergency_contacts': _showEmergencyContact,
        'show_chronic_conditions': _showChronicConditions,
        'lock_screen_widget_enabled': _lockScreenWidgetEnabled,
        if (memberId != null) 'family_member_id': memberId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.emergencySettingsSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.emergencySettingsSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addContact() async {
    final t = ref.read(appLocalizationsProvider);
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    try {
      final api = ref.read(apiClientProvider);
      final memberId = ref.read(activeMemberIdProvider);
      await api.post('/emergency/contacts', data: {
        'full_name': _nameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
        'relationship': _contactRelation,
        if (memberId != null) 'family_member_id': memberId,
      });
      _nameCtrl.clear();
      _phoneCtrl.clear();
      setState(() => _isAddingContact = false);
      ref.invalidate(emergencyContactsProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg =
          (e.response?.data is Map ? e.response!.data['detail'] : null) ??
              t.emergencyAddContactFailed;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.emergencyAddContactFailed)));
    }
  }

  Future<void> _deleteContact(String contactId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/emergency/contacts/$contactId');
      ref.invalidate(emergencyContactsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final settingsAsync = ref.watch(emergencySettingsProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final bloodGroupAsync = ref.watch(activeBloodGroupProvider);
    final allergiesAsync = ref.watch(emergencyActiveAllergiesProvider);
    final profile = ref.watch(activeProfileProvider);

    // Switching the active family profile means these toggles/contacts belong to a different
    // person - re-hydrate local state from that profile's own settings instead of keeping
    // whichever profile's values were loaded first.
    ref.listen<ActiveProfile>(activeProfileProvider, (previous, next) {
      if (previous?.memberId != next.memberId ||
          previous?.isOwnerMode != next.isOwnerMode) {
        setState(() => _settingsHydrated = false);
      }
    });

    settingsAsync.whenData(_hydrateFromSettings);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(profile.isOwnerMode
            ? t.emergencyInfoTitle
            : t.emergencyInfoTitleFor(profile.displayName)),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.emergencyWidgetSetupTitle,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              t.emergencyWidgetSetupSubtitle,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Lock screen preview card - matching Figma
            _LockScreenPreview(
              t: t,
              bloodGroup: bloodGroupAsync.asData?.value,
              topAllergy: (allergiesAsync.asData?.value ?? []).isNotEmpty
                  ? (allergiesAsync.asData!.value.firstWhere(
                      (a) => a['criticality'] == 'high',
                      orElse: () => allergiesAsync.asData!.value.first,
                    )['substance_name'] as String?)
                  : null,
              showBloodGroup: _showBloodGroup,
              showAllergies: _showAllergies,
              showContact: _showEmergencyContact,
              contacts: contactsAsync.asData?.value ?? [],
            ),
            const SizedBox(height: 24),

            // Toggle list
            _ToggleTile(
              label: t.emergencyToggleBloodGroupTitle,
              subtitle: t.emergencyToggleBloodGroupSubtitle,
              value: _showBloodGroup,
              onChanged: (v) => setState(() => _showBloodGroup = v),
            ),
            _ToggleTile(
              label: t.emergencyToggleAllergiesTitle,
              subtitle: t.emergencyToggleAllergiesSubtitle,
              value: _showAllergies,
              onChanged: (v) => setState(() => _showAllergies = v),
            ),
            _ToggleTile(
              label: t.emergencyToggleContactTitle,
              subtitle: t.emergencyToggleContactSubtitle,
              value: _showEmergencyContact,
              onChanged: (v) => setState(() => _showEmergencyContact = v),
            ),
            _ToggleTile(
              label: t.emergencyToggleChronicTitle,
              subtitle: t.emergencyToggleChronicSubtitle,
              value: _showChronicConditions,
              onChanged: (v) => setState(() => _showChronicConditions = v),
            ),

            const SizedBox(height: 16),
            Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 16),

            // Enable Lock Screen Widget master toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.emergencyEnableWidgetTitle,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        SizedBox(height: 3),
                        Text(t.emergencyEnableWidgetSubtitle,
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _lockScreenWidgetEnabled,
                    onChanged: (v) =>
                        setState(() => _lockScreenWidgetEnabled = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Emergency contacts section
            Row(
              children: [
                Text(t.emergencyContactsSectionTitle,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                        letterSpacing: 1)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _isAddingContact = !_isAddingContact),
                  icon: Icon(_isAddingContact ? Icons.close : Icons.add,
                      size: 14),
                  label: Text(_isAddingContact ? t.commonCancel : t.commonAdd),
                  style:
                      TextButton.styleFrom(foregroundColor: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isAddingContact)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                          hintText: t.emergencyContactNameHint,
                          prefixIcon: const Icon(Icons.person_outline, size: 18)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                          hintText: t.emergencyContactPhoneHint,
                          prefixIcon: const Icon(Icons.phone_outlined, size: 18)),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _contactRelation,
                      dropdownColor: AppTheme.card,
                      style: TextStyle(color: AppTheme.textPrimary),
                      items: {
                        'Family': t.emergencyRelFamily,
                        'Friend': t.emergencyRelFriend,
                        'Doctor': t.emergencyRelDoctor,
                        'Nurse': t.emergencyRelNurse,
                        'Other': t.relOther,
                      }
                          .entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _contactRelation = v!),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: _addContact,
                          child: Text(t.emergencyAddContactButton)),
                    ),
                  ],
                ),
              ),

            contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(t.emergencyNoContacts,
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  );
                }
                return Column(
                  children: contacts
                      .map((c) => _ContactTile(
                          contact: c,
                          t: t,
                          onDelete: () => _deleteContact(c['id'])))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 28),

            // Save Settings button - matching Figma
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text(t.emergencySaveSettingsButton),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LockScreenPreview extends StatelessWidget {
  const _LockScreenPreview({
    required this.t,
    required this.bloodGroup,
    required this.topAllergy,
    required this.showBloodGroup,
    required this.showAllergies,
    required this.showContact,
    required this.contacts,
  });

  final AppLocalizations t;
  final String? bloodGroup;
  final String? topAllergy;
  final bool showBloodGroup;
  final bool showAllergies;
  final bool showContact;
  final List<Map<String, dynamic>> contacts;

  @override
  Widget build(BuildContext context) {
    final contact = contacts.isNotEmpty ? contacts.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          // Lock screen mock time
          const Text('09:41',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w300)),
          Text(t.emergencyLockScreenHint,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 16),

          // Emergency info widget
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_services,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Text(t.emergencyInfoLabel,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.local_hospital,
                          color: Colors.white, size: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (showBloodGroup)
                  Row(children: [
                    Text('${t.emergencyBloodGroupLabel}  ',
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                    Text(bloodGroup ?? t.emergencyNotSet,
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 20),
                    if (showAllergies) ...[
                      Text('${t.emergencyAllergiesLabel}  ',
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                      Text(topAllergy ?? t.emergencyNoneKnown,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ]),
                if (showContact && contact != null) ...[
                  const Divider(color: Colors.white12, height: 16),
                  Text(t.emergencyContactLabel,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                          '${contact['full_name']} (${contact['relationship']})',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  Text(contact['phone_number'] ?? '',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile(
      {required this.label,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppTheme.primary),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile(
      {required this.contact, required this.t, required this.onDelete});
  final Map<String, dynamic> contact;
  final AppLocalizations t;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.error.withValues(alpha: 0.12),
            child: Icon(Icons.person_outline, color: AppTheme.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact['full_name'] ?? t.commonUnknown,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(contact['phone_number'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    if (contact['relationship'] != null) ...[
                      Text(' · ', style: TextStyle(color: AppTheme.textMuted)),
                      Text(contact['relationship'],
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon:
                Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 18),
          ),
        ],
      ),
    );
  }
}
