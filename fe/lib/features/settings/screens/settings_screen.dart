import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_providers.dart';
import '../../family/providers/active_profile_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final profileAsync = ref.watch(profileProvider);
    final prefs = ref.watch(preferencesProvider);
    final profile = ref.watch(activeProfileProvider);
    final isMember = !profile.isOwnerMode;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: AppTheme.background,
              title: const Text('CurecordAI'),
              pinned: true,
              actions: [
                IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/alerts')),
              ],
            ),

            // Profile header - shows member info in member mode, owner info otherwise
            SliverToBoxAdapter(
              child: isMember
                  ? _MemberProfileHeader(profile: profile, t: t)
                  : profileAsync.when(
                      loading: () => const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator())),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (profile) {
                        final name = profile.fullName ?? t.commonUser;
                        final initial =
                            name.isNotEmpty ? name[0].toUpperCase() : 'U';
                        final patientId = profile.patientId ?? '#MF-00000';
                        final pct = profile.completionPct;
                        final photoUrl = profile.profilePhotoUrl;

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            children: [
                              // Avatar - tappable for image upload
                              GestureDetector(
                                onTap: _isUploadingAvatar
                                    ? null
                                    : () => _pickAvatar(context),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 44,
                                      backgroundColor: AppTheme.primary,
                                      backgroundImage: photoUrl != null
                                          ? CachedNetworkImageProvider(
                                              photoUrl,
                                              cacheKey: 'avatar_${profile.id}',
                                              cacheManager: RecordFileCacheManager
                                                  .instance,
                                            )
                                          : null,
                                      child: photoUrl == null
                                          ? Text(initial,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w700))
                                          : null,
                                    ),
                                    if (_isUploadingAvatar)
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.45),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppTheme.background,
                                              width: 2),
                                        ),
                                        child: const Icon(Icons.edit,
                                            color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => context.push('/profile'),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(name,
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary)),
                                        const SizedBox(width: 6),
                                        Icon(Icons.verified,
                                            color: AppTheme.primary, size: 18),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(patientId,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Profile completion card - tappable. Goes to the real profile
                              // editor (not the /profile-completion onboarding wizard, which
                              // only ever persists health-details and silently drops physical
                              // metrics when entered outside the initial signup flow).
                              GestureDetector(
                                onTap: () =>
                                    context.push('/profile/information'),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(t.settingsProfileCompletion,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppTheme.textSecondary)),
                                          const Spacer(),
                                          Text('$pct%',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.primary)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: pct / 100,
                                        color: AppTheme.primary,
                                        backgroundColor: AppTheme.cardBorder,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        t.settingsProfileCompletionHint,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            if (!isMember) ...[
              // ACCOUNT section
              _SliverSectionHeader(t.settingsSectionAccount),
              _sliverTile(
                  icon: Icons.person_outline,
                  label: t.settingsProfileInformation,
                  subtitle: t.settingsProfileInformationSubtitle,
                  onTap: () => context.push('/profile/information')),
              _sliverTile(
                  icon: Icons.people_outline,
                  label: t.settingsFamilyManagement,
                  subtitle: t.settingsFamilyManagementSubtitle,
                  onTap: () => context.push('/family')),

              // PREFERENCES section
              _SliverSectionHeader(t.settingsSectionPreferences),
              // Language toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.translate_outlined,
                            color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.settingsLanguage,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary)),
                              Text(t.settingsLanguageSubtitle,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LangChip(
                                label: t.langEnglish,
                                isActive: prefs.language == 'en',
                                onTap: () => ref
                                    .read(preferencesProvider.notifier)
                                    .setLanguage('en'),
                              ),
                              _LangChip(
                                label: t.langUrdu,
                                isActive: prefs.language == 'ur',
                                onTap: () => ref
                                    .read(preferencesProvider.notifier)
                                    .setLanguage('ur'),
                              ),
                              _LangChip(
                                label: t.langRomanUrdu,
                                isActive: prefs.language == 'roman_ur',
                                onTap: () => ref
                                    .read(preferencesProvider.notifier)
                                    .setLanguage('roman_ur'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              // Theme toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.dark_mode_outlined,
                            color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.settingsTheme,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary)),
                              Text(
                                prefs.isDarkTheme
                                    ? t.settingsThemeCurrentDark
                                    : t.settingsThemeCurrentLight,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: prefs.isDarkTheme,
                          activeTrackColor: AppTheme.primary,
                          onChanged: (v) => ref
                              .read(preferencesProvider.notifier)
                              .setTheme(v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // MEDICAL section
            _SliverSectionHeader(t.settingsSectionMedical),
            _sliverTile(
              icon: Icons.badge_outlined,
              label: t.settingsEmergencyCard,
              subtitle: t.settingsEmergencyCardSubtitle,
              onTap: () => context.push('/emergency'),
            ),

            // PRIVACY & DATA section
            _SliverSectionHeader(t.settingsSectionPrivacyData),
            _sliverTile(
              icon: Icons.lock_outline,
              label: t.settingsDataPrivacy,
              subtitle: t.settingsDataPrivacySubtitle,
              onTap: () => context.push('/profile/privacy-policy'),
            ),
            _sliverTile(
              icon: Icons.download_outlined,
              label: t.settingsExportData,
              subtitle: t.settingsExportDataSubtitle,
              onTap: () => _requestDataExport(context, t),
            ),
            _sliverTile(
              icon: Icons.shield_outlined,
              label: t.settingsConsentManagement,
              subtitle: t.settingsConsentManagementSubtitle,
              onTap: () => context.push('/consent'),
            ),

            // Log Out
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.card,
                        title: Text(t.settingsLogOutConfirmTitle,
                            style: TextStyle(color: AppTheme.textPrimary)),
                        content: Text(t.settingsLogOutConfirmBody,
                            style: TextStyle(color: AppTheme.textSecondary)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.commonCancel)),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(t.settingsLogOut,
                                style: TextStyle(color: AppTheme.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/auth/login');
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Center(
                      child: Text(t.settingsLogOut,
                          style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FooterLink(
                            label: t.settingsPrivacyPolicy,
                            onTap: () =>
                                context.push('/profile/privacy-policy')),
                        Text('  ·  ',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        _FooterLink(
                            label: t.settingsTermsOfService, onTap: () {}),
                        Text('  ·  ',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        _FooterLink(label: t.settingsSupport, onTap: () {}),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(t.settingsAppVersion,
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestDataExport(BuildContext context, AppLocalizations t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(t.settingsExportDataTitle,
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          t.settingsExportDataBody,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.settingsRequestExport,
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/consent/data-export', data: {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.settingsExportRequestedSnack)),
        );
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      final msg = e.response?.statusCode == 409
          ? t.settingsExportInProgressError
          : t.settingsExportFailedError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final t = ref.read(appLocalizationsProvider);
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(profileProvider.notifier).uploadAvatar(file.path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.settingsAvatarUploadFailed)));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }
}

// ── Member profile header (shown in settings when viewing a family member) ────

class _MemberProfileHeader extends StatelessWidget {
  const _MemberProfileHeader({required this.profile, required this.t});
  final ActiveProfile profile;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppTheme.primary,
            child: Text(
              profile.initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          if (profile.memberRelationship != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary, width: 1.5),
              ),
              child: Text(
                profile.memberRelationship!,
                style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t.settingsManagedByYou,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SliverSectionHeader extends StatelessWidget {
  const _SliverSectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
                letterSpacing: 1)),
      ),
    );
  }
}

SliverToBoxAdapter _sliverTile({
  required IconData icon,
  required String label,
  String? subtitle,
  Widget? trailing,
  required VoidCallback onTap,
}) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textPrimary)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right,
                      color: AppTheme.textMuted, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LangChip extends StatelessWidget {
  const _LangChip(
      {required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    );
  }
}
