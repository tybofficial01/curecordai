import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/info_explainer_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/active_profile_provider.dart';
import '../providers/family_provider.dart';

// Small fixed palette of existing theme tokens (no new colors) so family members are
// visually distinguishable from each other in the grid rather than all sharing the
// same avatar color, mirroring the palette used on the web dashboard.
List<Color> _avatarBackgrounds() => [
      AppTheme.primary.withValues(alpha: 0.15),
      AppTheme.info.withValues(alpha: 0.15),
      AppTheme.success.withValues(alpha: 0.15),
      AppTheme.warning.withValues(alpha: 0.15),
    ];

List<Color> _avatarForegrounds() =>
    [AppTheme.primary, AppTheme.info, AppTheme.success, AppTheme.warning];

int _avatarPaletteIndex(String name) {
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % 4;
}

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final familyAsync = ref.watch(familyMembersProvider);

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.familyManagementTitle,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: () => _showFamilyInfo(context, t),
                  tooltip: t.familyInfoAria,
                  icon: Icon(Icons.info_outline, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.familyManagementSubtitle,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            familyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        color: AppTheme.textSecondary, size: 48),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => ref.refresh(familyMembersProvider),
                        child: Text(t.commonRetry)),
                  ],
                ),
              ),
              data: (members) => members.isEmpty
                  ? _EmptyFamilyState(t: t)
                  : Column(
                      children: [
                        _AddFamilyCard(
                          onTap: () => context.push('/family/add'),
                          t: t,
                        ),
                        ...members.map((m) => _MemberCard(
                              member: m,
                              t: t,
                              onTap: () {
                                ref
                                    .read(activeProfileProvider.notifier)
                                    .switchToMember(m);
                                context.push('/family-member');
                              },
                              onEdit: () => context.push('/family/add',
                                  extra: {'editId': m['id']}),
                              onDelete: () =>
                                  _showDeleteSheet(context, ref, m, t),
                            )),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.familyPrivacyPolicy,
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('  ·  ', style: TextStyle(color: AppTheme.textMuted)),
                Text(t.familyTermsOfService,
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('  ·  ', style: TextStyle(color: AppTheme.textMuted)),
                Text(t.familySupport,
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(t.familyAppVersion,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  static void _showFamilyInfo(BuildContext context, AppLocalizations t) {
    showInfoExplainerDialog(
      context,
      title: t.familyInfoModalTitle,
      gotItLabel: t.commonGotIt,
      items: [
        InfoExplainerItem(
          icon: Icons.vpn_key_outlined,
          title: t.familyInfoNoLoginTitle,
          description: t.familyInfoNoLoginDescription,
        ),
        InfoExplainerItem(
          icon: Icons.badge_outlined,
          title: t.familyInfoProfilesTitle,
          description: t.familyInfoProfilesDescription,
        ),
        InfoExplainerItem(
          icon: Icons.groups_outlined,
          title: t.familyInfoTogetherTitle,
          description: t.familyInfoTogetherDescription,
        ),
        InfoExplainerItem(
          icon: Icons.qr_code_outlined,
          title: t.familyInfoShareTitle,
          description: t.familyInfoShareDescription,
        ),
      ],
    );
  }

  static void _showDeleteSheet(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> member, AppLocalizations t) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _DeleteSheet(
        name: member['full_name'] as String? ?? t.familyMemberFallbackName,
        t: t,
        onConfirm: () async {
          Navigator.pop(sheetCtx);
          try {
            await ref.read(apiClientProvider).delete('/family/${member['id']}');
            await refreshFamilyMembers(ref);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(t.familyMemberRemoved)),
              );
            }
          } catch (_) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(t.familyMemberRemoveFailed)),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyFamilyState extends StatelessWidget {
  const _EmptyFamilyState({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
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
                child: Icon(Icons.groups_outlined,
                    color: AppTheme.primary, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                t.familyEmptyTitle,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                t.familyEmptyDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/family/add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: Text(
                    t.familyAddMemberTitle,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _RelationShortcutCard(
          icon: Icons.person_outline,
          accentBg: AppTheme.info.withValues(alpha: 0.15),
          accentFg: AppTheme.info,
          title: t.familyAddShortcutParentTitle,
          description: t.familyAddShortcutParentDescription,
          onTap: () => context.push('/family/add',
              extra: {'initialRelation': 'Parent'}),
        ),
        const SizedBox(height: 12),
        _RelationShortcutCard(
          icon: Icons.favorite_border,
          accentBg: AppTheme.primary.withValues(alpha: 0.15),
          accentFg: AppTheme.primary,
          title: t.familyAddShortcutSpouseTitle,
          description: t.familyAddShortcutSpouseDescription,
          onTap: () => context.push('/family/add',
              extra: {'initialRelation': 'Spouse'}),
        ),
        const SizedBox(height: 12),
        _RelationShortcutCard(
          icon: Icons.child_care_outlined,
          accentBg: AppTheme.success.withValues(alpha: 0.15),
          accentFg: AppTheme.success,
          title: t.familyAddShortcutChildTitle,
          description: t.familyAddShortcutChildDescription,
          onTap: () => context.push('/family/add',
              extra: {'initialRelation': 'Child'}),
        ),
      ],
    );
  }
}

class _RelationShortcutCard extends StatelessWidget {
  const _RelationShortcutCard({
    required this.icon,
    required this.accentBg,
    required this.accentFg,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color accentBg;
  final Color accentFg;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentFg, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                        fontSize: 12.5, color: AppTheme.textSecondary),
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

// ── Member Card ──────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.t,
  });

  final Map<String, dynamic> member;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppLocalizations t;

  String get _name => member['full_name'] as String? ?? t.familyMemberFallbackName;
  String get _relationship =>
      member['relationship'] as String? ?? t.familyMemberFallbackName;
  String? get _gender => member['gender'] as String?;
  String? get _bloodGroup => member['blood_group'] as String?;
  int? get _age => member['age'] as int?;

  @override
  Widget build(BuildContext context) {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final paletteIndex = _avatarPaletteIndex(_name);
    final avatarBg = _avatarBackgrounds()[paletteIndex];
    final avatarFg = _avatarForegrounds()[paletteIndex];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarBg,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: avatarFg,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _relationship,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Every card always shows all three rows, with a muted placeholder for
            // anything not provided, so cards line up at the same height regardless
            // of how much data a given family member has.
            _InfoRow(
              label: t.familyFieldGender,
              value: _gender,
              t: t,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: t.familyFieldBloodGroup,
              value: _bloodGroup,
              t: t,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: t.familyFieldAge,
              value: _age != null ? t.familyYearsOld(_age!) : null,
              t: t,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: t.commonEdit,
                    color: AppTheme.textSecondary,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: t.familyRemove,
                    color: AppTheme.error,
                    onTap: onDelete,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.t});
  final String label;
  final String? value;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
        Text(
          value ?? t.familyNotProvided,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: value != null ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        // Vertical padding brings the tappable area up toward the standard
        // 44dp touch target, without inflating the compact card layout.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Family Card ──────────────────────────────────────────────────────────

class _AddFamilyCard extends StatelessWidget {
  const _AddFamilyCard({required this.onTap, required this.t});
  final VoidCallback onTap;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              t.familyAddMemberTitle,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete Confirmation Sheet ────────────────────────────────────────────────

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet(
      {required this.name, required this.onConfirm, required this.t});
  final String name;
  final VoidCallback onConfirm;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handleBar(),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_outline, color: AppTheme.error, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            t.familyRemoveMemberTitle,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            t.familyRemoveMemberBody(name),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(color: AppTheme.cardBorder, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                t.commonCancel,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                t.familyRemove,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

Widget _handleBar() => Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.cardBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    );
