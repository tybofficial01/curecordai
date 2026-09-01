import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/profile_models.dart';
import '../providers/profile_providers.dart';
import '../utils/avatar_crop.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../family/providers/family_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (!activeProfile.isOwnerMode) {
      return _MemberProfileScreen(profile: activeProfile);
    }

    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          // Safe pop - this screen can be reached from Settings (pushed, poppable) but also
          // directly via a deep link with nothing on the stack, in which case pop() alone
          // is a silent no-op and the back button appears "broken".
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          t.profileMyProfileTitle,
          style: AppFonts.manrope(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push('/profile/information'),
            child: Text(
              t.commonEdit,
              style: AppFonts.manrope(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => _ProfileShimmer(),
        error: (e, _) =>
            _ErrorView(t: t, onRetry: () => ref.refresh(profileProvider)),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + name + patient ID ─────────────────────────────
              Center(
                child: Column(
                  children: [
                    _AvatarWidget(profile: profile),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile.fullName ?? t.commonUser,
                          style: AppFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.verified, color: AppTheme.primary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.profilePatientId(profile.patientId ?? ' - '),
                      style: AppFonts.manrope(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Completion card ────────────────────────────────────────
              _CompletionCard(pct: profile.completionPct, t: t),
              const SizedBox(height: 24),

              // ── Personal Details ───────────────────────────────────────
              _SectionLabel(t.profileSectionPersonalDetails),
              const SizedBox(height: 8),
              _InfoCard(rows: [
                _InfoRow(
                    label: t.profileLabelDob,
                    value: _formatDate(profile.dateOfBirth)),
                _InfoRow(
                    label: t.profileLabelGender,
                    value: _displayGender(t, profile.gender)),
                _InfoRow(
                    label: t.profileLabelPhone,
                    value: profile.phoneNumber ?? ' - '),
              ]),
              const SizedBox(height: 20),

              // ── Physical Metrics ───────────────────────────────────────
              _SectionLabel(t.profileSectionPhysicalMetrics),
              const SizedBox(height: 8),
              _InfoCard(rows: [
                _InfoRow(
                  label: t.profileLabelHeight,
                  value: profile.heightCm != null
                      ? '${profile.heightCm!.toStringAsFixed(0)} cm'
                      : ' - ',
                ),
                _InfoRow(
                  label: t.profileLabelWeight,
                  value: profile.weightKg != null
                      ? '${profile.weightKg!.toStringAsFixed(1)} kg'
                      : ' - ',
                ),
                _InfoRow(
                    label: t.profileLabelBloodGroup,
                    value: profile.bloodGroup ?? ' - '),
                if (profile.heightCm != null && profile.weightKg != null)
                  _InfoRow(
                    label: t.profileLabelBmi,
                    value: _bmiLabel(t, profile.heightCm!, profile.weightKg!),
                    valueColor: _bmiColor(profile.heightCm!, profile.weightKg!),
                  ),
              ]),
              const SizedBox(height: 20),

              // ── Health Details ─────────────────────────────────────────
              _SectionLabel(t.profileSectionHealthDetails),
              const SizedBox(height: 8),
              _HealthCard(
                  allergies: profile.allergies,
                  conditions: profile.conditions,
                  t: t),
              const SizedBox(height: 20),

              const SizedBox(height: 32),

              // ── Log Out ────────────────────────────────────────────────
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side:  BorderSide(color: AppTheme.cardBorder),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppTheme.surface,
                ),
                onPressed: () => _showLogoutDialog(context, ref, t),
                child: Text(
                  t.settingsLogOut,
                  style: AppFonts.manrope(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(String? raw) {
    if (raw == null) return ' - ';
    try {
      return DateFormat('d MMM yyyy')
          .format(DateFormat('yyyy-MM-dd').parse(raw));
    } catch (_) {
      return raw;
    }
  }

  static String _displayGender(AppLocalizations t, String? g) {
    switch (g) {
      case 'male':
        return t.genderMale;
      case 'female':
        return t.genderFemale;
      case 'unknown':
        return t.genderPreferNotToSay;
      default:
        return ' - ';
    }
  }

  static double _bmi(double h, double w) => w / ((h / 100) * (h / 100));

  static String _bmiLabel(AppLocalizations t, double h, double w) {
    final b = _bmi(h, w);
    final cat = b < 18.5
        ? t.profileBmiUnderweight
        : b < 25
            ? t.profileBmiNormal
            : b < 30
                ? t.profileBmiOverweight
                : t.profileBmiObese;
    return '${b.toStringAsFixed(1)} · $cat';
  }

  static Color _bmiColor(double h, double w) {
    final b = _bmi(h, w);
    if (b < 18.5 || b >= 30) return AppTheme.error;
    if (b >= 25) return AppTheme.warning;
    return AppTheme.primary;
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.settingsLogOutConfirmTitle,
            style: AppFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text(
          t.settingsLogOutConfirmBody,
          style: AppFonts.manrope(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.commonCancel,
                style: AppFonts.manrope(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/auth/login');
            },
            child: Text(
              t.settingsLogOut,
              style: AppFonts.manrope(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar (tappable for upload) ──────────────────────────────────────────────

class _AvatarWidget extends ConsumerWidget {
  const _AvatarWidget({required this.profile});
  final FullProfileResponse profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _pickAvatar(context, ref),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.primary,
            backgroundImage: profile.profilePhotoUrl != null
                ? CachedNetworkImageProvider(
                    profile.profilePhotoUrl!,
                    cacheKey: 'avatar_${profile.id}',
                    cacheManager: RecordFileCacheManager.instance,
                  )
                : null,
            child: profile.profilePhotoUrl == null
                ? Text(
                    (profile.fullName ?? 'U').substring(0, 1).toUpperCase(),
                    style: AppFonts.manrope(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    if (!context.mounted) return;
    final croppedPath = await cropAvatarImage(
      context,
      file.path,
      title: ref.read(appLocalizationsProvider).profileCropPhotoTitle,
    );
    if (croppedPath == null) return;
    try {
      await ref.read(profileProvider.notifier).uploadAvatar(croppedPath);
    } catch (_) {
      if (context.mounted) {
        final t = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.profileFailedUploadPhoto)),
        );
      }
    }
  }
}

// ── Completion card ───────────────────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.pct, required this.t});
  final int pct;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile/information'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  t.profileCompletionTitle,
                  style: AppFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary),
                ),
                const Spacer(),
                Text(
                  '$pct%',
                  style: AppFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                backgroundColor: AppTheme.cardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            if (pct < 100) ...[
              const SizedBox(height: 8),
              Text(
                t.profileCompletionTapToComplete,
                style: AppFonts.manrope(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppFonts.manrope(
        color: AppTheme.primary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Info card (rows of label → value) ────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
               Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  color: AppTheme.cardBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    rows[i].label,
                    style: AppFonts.manrope(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    rows[i].value,
                    style: AppFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: rows[i].valueColor ?? AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
}

// ── Health details card ───────────────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard(
      {required this.allergies, required this.conditions, required this.t});
  final String? allergies;
  final List<String> conditions;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final hasAllergies = allergies != null && allergies!.isNotEmpty;
    final hasConditions = conditions.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.profileAllergiesLabel,
            style: AppFonts.manrope(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            hasAllergies ? allergies! : t.profileNoneRecorded,
            style: AppFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasAllergies
                  ? AppTheme.textPrimary
                  : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),
           Divider(height: 1, thickness: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 14),
          Text(
            t.profileConditionsLabel,
            style: AppFonts.manrope(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          if (hasConditions) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conditions
                  .map(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        c,
                        style: AppFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              t.profileNoneRecorded,
              style: AppFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Editable info tile (label/value/icon, optional tap-to-edit) ──────────────
// Used by _MemberProfileScreen - distinct from _InfoCard(rows:) above, which
// renders the account owner's own read-only grouped rows.

class _EditableInfoTile extends StatelessWidget {
  const _EditableInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 16),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

// ── Member profile (viewing/editing a family member, not the account owner) ──

class _MemberProfileScreen extends ConsumerWidget {
  const _MemberProfileScreen({required this.profile});
  final ActiveProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final memberId = profile.memberId;
    if (memberId == null) {
      return Scaffold(
          body: Center(child: Text(t.profileNoMemberSelected)));
    }
    final detailAsync = ref.watch(familyMemberDetailProvider(memberId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(t.profileMemberTitleFor(profile.displayName))),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.refresh(familyMemberDetailProvider(memberId)),
                child: Text(t.commonRetry),
              ),
            ],
          ),
        ),
        data: (member) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: member['photo_url'] != null
                        ? CachedNetworkImageProvider(
                            member['photo_url'] as String,
                            cacheKey: 'avatar_${member['id']}',
                            cacheManager: RecordFileCacheManager.instance,
                          )
                        : null,
                    child: member['photo_url'] == null
                        ? Text(profile.initial,
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 36,
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  member['full_name'] as String? ?? profile.displayName,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                if (member['relationship'] != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary, width: 1.5),
                    ),
                    child: Text(
                      member['relationship'],
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _EditableInfoTile(
                  label: t.profileLabelDob,
                  value: member['date_of_birth'] as String? ?? ' - ',
                  icon: Icons.cake_outlined,
                  onTap: () => _editDateOfBirth(context, ref, memberId, member),
                ),
                const SizedBox(height: 10),
                _EditableInfoTile(
                  label: t.profileLabelGender,
                  value: member['gender'] as String? ?? ' - ',
                  icon: Icons.person_outline,
                  onTap: () => _editGender(context, ref, memberId, member, t),
                ),
                const SizedBox(height: 10),
                _EditableInfoTile(
                  label: t.profileLabelBloodGroup,
                  value: member['blood_group'] as String? ?? ' - ',
                  icon: Icons.bloodtype_outlined,
                  onTap: () => _editBloodGroup(context, ref, memberId, member, t),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _patchMember(
      WidgetRef ref, String memberId, Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    await api.patch('/family/$memberId', data: data);
    ref.invalidate(familyMemberDetailProvider(memberId));
    await refreshFamilyMembers(ref);
  }

  Future<void> _editDateOfBirth(BuildContext context, WidgetRef ref,
      String memberId, Map<String, dynamic> member) async {
    final currentDob =
        DateTime.tryParse(member['date_of_birth'] as String? ?? '');
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await _patchMember(ref, memberId, {'date_of_birth': iso});
  }

  Future<void> _editGender(BuildContext context, WidgetRef ref, String memberId,
      Map<String, dynamic> member, AppLocalizations t) async {
    final options = {
      'Male': t.genderMale,
      'Female': t.genderFemale,
      'Other': t.genderOther,
    };
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.profileSelectGenderTitle),
        children: options.entries
            .map((o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o.key),
                  child: Text(o.value),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    await _patchMember(ref, memberId, {'gender': selected.toLowerCase()});
  }

  Future<void> _editBloodGroup(BuildContext context, WidgetRef ref,
      String memberId, Map<String, dynamic> member, AppLocalizations t) async {
    const options = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.profileSelectBloodGroupTitle),
        children: options
            .map((o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o),
                  child: Text(o),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    await _patchMember(ref, memberId, {'blood_group': selected});
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.t});
  final VoidCallback onRetry;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: AppTheme.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(t.profileFailedLoad,
              style: AppFonts.manrope(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(t.commonRetry)),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _ProfileShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.cardBorder,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(radius: 52, backgroundColor: AppTheme.surfaceVariant),
            const SizedBox(height: 12),
            Container(
                height: 22,
                width: 160,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(
                height: 14,
                width: 120,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            Container(
                height: 72,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 20),
            Container(
                height: 130,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 20),
            Container(
                height: 130,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 20),
            Container(
                height: 100,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 20),
            Container(
                height: 90,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16))),
          ],
        ),
      ),
    );
  }
}
