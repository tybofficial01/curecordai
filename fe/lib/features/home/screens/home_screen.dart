import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../insights/providers/insights_provider.dart';
import '../../medications/providers/medications_provider.dart';
import '../../records/providers/records_provider.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../records/widgets/record_preview_sheet.dart';
import '../providers/dashboard_banner_provider.dart';
import '../utils/dashboard_format.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

// Exported (not file-private) so auth_provider.dart can invalidate it on
// logout - see _invalidateCachedDataProviders there.
final homeUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>('/users/me',
      cachePolicy: CachePolicy.refreshForceCache);
  return response.data ?? {};
});

final recentRecordsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final params = <String, dynamic>{'limit': 5};
  if (memberId != null) params['family_member_id'] = memberId;
  final response = await api.get<List<dynamic>>('/records',
      queryParameters: params, cachePolicy: CachePolicy.forceCache);
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

// Active allergies from the clinical endpoint - updated by onboarding, profile
// edits, and AI prescription extraction automatically.
final homeActiveAllergiesProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final params = <String, dynamic>{'clinical_status': 'active'};
  if (memberId != null) params['family_member_id'] = memberId;
  final response = await api.get<List<dynamic>>(
    '/allergies',
    queryParameters: params,
    cachePolicy: CachePolicy.refreshForceCache,
  );
  return (response.data ?? [])
      .cast<Map<String, dynamic>>()
      .map((a) => (a['substance_name'] as String? ?? '').trim())
      .where((n) => n.isNotEmpty)
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only override the status bar (icons need to stay light over the teal
    // header image). Leaving the system navigation bar transparent keeps it
    // consistent with every other tab - forcing it opaque here painted a
    // solid bar over our own bottom nav bar until the next scroll-triggered
    // relayout revealed it again.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    final t = ref.watch(appLocalizationsProvider);
    final userAsync = ref.watch(homeUserProvider);
    final profile = ref.watch(activeProfileProvider);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      // Teal fallback - visible in the card's rounded corner zones when the
      // image scrolls out of view; matches the image colour seamlessly.
      backgroundColor: AppTheme.primary,
      body: Stack(
        children: [
          // ── Background image - Positioned so it extends behind the white
          //    card's rounded corners. CustomScrollView renders on top, so the
          //    card's transparent corner areas reveal this image layer.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              // Extra height beyond the header content so the image fills
              // the zone behind the card's 36-px rounded corners.
              height: top + 220,
              child: Image.asset(
                'assets/images/header_texture.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ── Scrollable content - transparent header lets image show through
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Transparent header: no background, image from Stack shows through.
              SliverToBoxAdapter(
                child: _HeaderBackground(
                    userAsync: userAsync, profile: profile, t: t),
              ),

              // ── White floating card ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 24,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  // Bottom padding cleared to 120 (was 40) so the last
                  // scrolled content always rests above the floating AI
                  // button (58dp button + its default 16dp margin), rather
                  // than being covered by it once scrolled into view.
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AllergyAlertCard(),
                      const _DashboardStatCards(),
                      const SizedBox(height: 20),
                      _DashboardQuickActions(t: t),
                      const SizedBox(height: 28),
                      _RecentDocumentsSection(t: t),
                      const SizedBox(height: 28),
                      _RecentConversationsSection(t: t),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Header background (texture + content) ────────────────────────────────────

class _HeaderBackground extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> userAsync;
  final ActiveProfile profile;
  final AppLocalizations t;
  const _HeaderBackground(
      {required this.userAsync, required this.profile, required this.t});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    // No background here - the Positioned image in HomeScreen's Stack
    // renders behind this widget and shows through (transparent).
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: [avatar] [greeting] [notification bell] - avatar is the
          // family profile switcher (tap to switch to a member's profile),
          // correctly on the left with the bell on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AvatarButton(userAsync: userAsync, profile: profile, t: t),
              const SizedBox(width: 12),
              Expanded(
                child: profile.isOwnerMode
                    ? _GreetingBlock(userAsync: userAsync, t: t)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              const _NotificationButton(),
            ],
          ),

          if (profile.isOwnerMode)
            // Priority nudge, then profile completion, then rotating tips -
            // tight below greeting, same slot as the old profile-only line.
            _BannerMessage(userAsync: userAsync, t: t)
          else
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.homeMemberDashboardTitle(profile.displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (profile.memberRelationship != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white70),
                      ),
                      child: Text(
                        profile.memberRelationship!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Banner message slot ───────────────────────────────────────────────────────
// One line below the greeting that shows, in priority order: an unread
// doctor instruction, a zero-documents nudge, a zero-medications nudge, the
// profile completion sentence, or - when none of those apply - a rotating
// fallback tip. Mirrors web/app/dashboard/page.tsx's priority list while
// keeping this banner's original plain-text styling (no boxed strip).
class _BannerMessage extends ConsumerStatefulWidget {
  final AsyncValue<Map<String, dynamic>> userAsync;
  final AppLocalizations t;
  const _BannerMessage({required this.userAsync, required this.t});

  @override
  ConsumerState<_BannerMessage> createState() => _BannerMessageState();
}

class _BannerMessageState extends ConsumerState<_BannerMessage> {
  static const _kRotationInterval = Duration(seconds: 9);
  static const _kRotationFade = Duration(milliseconds: 300);

  Timer? _rotationTimer;
  int _tipIndex = 0;
  bool _tipFading = false;

  void _startRotation(int tipCount, bool reducedMotion) {
    if (reducedMotion || tipCount <= 1 || _rotationTimer != null) return;
    _rotationTimer = Timer.periodic(_kRotationInterval, (_) {
      if (!mounted) return;
      setState(() => _tipFading = true);
      Future.delayed(_kRotationFade, () {
        if (!mounted) return;
        setState(() {
          _tipIndex = (_tipIndex + 1) % tipCount;
          _tipFading = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  _NudgeCopy _nudgeCopy(DashboardNudgeId id, AppLocalizations t) {
    switch (id) {
      case DashboardNudgeId.unreadDoctorInstruction:
        return _NudgeCopy(
          t.homeNudgeUnreadInstructionMessage,
          t.homeNudgeUnreadInstructionButton,
          '/share',
        );
      case DashboardNudgeId.noDocuments:
        return _NudgeCopy(
          t.homeNudgeNoDocumentsMessage,
          t.homeNudgeNoDocumentsButton,
          '/records/upload',
        );
      case DashboardNudgeId.noMedications:
        return _NudgeCopy(
          t.homeNudgeNoMedicationsMessage,
          t.homeNudgeNoMedicationsButton,
          '/medications',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final nudgeId = ref.watch(priorityNudgeIdProvider);
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    final pct = widget.userAsync.maybeWhen(
      data: (user) {
        final userProfile = user['profile'] as Map<String, dynamic>? ?? {};
        return userProfile['profile_completion_pct'] as int? ?? 0;
      },
      orElse: () => 100,
    );

    if (nudgeId != null) {
      final copy = _nudgeCopy(nudgeId, t);
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: () => context.push(copy.route),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                    children: [
                      TextSpan(text: '${copy.message} '),
                      TextSpan(
                        text: copy.buttonLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                          decorationThickness: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (pct < 100) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push('/profile/information'),
                  child: Text(
                    '${t.homeProfileCompletePrefix}$pct%.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (pct < 100) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(
          child: GestureDetector(
            onTap: () => context.push('/profile/information'),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.55,
                ),
                children: [
                  TextSpan(text: t.homeProfileCompletePrefix),
                  TextSpan(
                    text: '$pct%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: t.homeProfileCompleteSuffix),
                  TextSpan(
                    text: t.homeHereLink,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationThickness: 1.5,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final tips = [t.homeRotatingTip1, t.homeRotatingTip2, t.homeRotatingTip3];
    _startRotation(tips.length, reducedMotion);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: AnimatedOpacity(
          opacity: _tipFading ? 0 : 1,
          duration: _kRotationFade,
          child: Text(
            tips[_tipIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _NudgeCopy {
  const _NudgeCopy(this.message, this.buttonLabel, this.route);
  final String message;
  final String buttonLabel;
  final String route;
}

class _GreetingBlock extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> userAsync;
  final AppLocalizations t;
  const _GreetingBlock({required this.userAsync, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${timeBasedGreeting(DateTime.now(), t)} \u{1F44B}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 5),
        userAsync.when(
          loading: () =>
              const SizedBox(height: 30, width: 120, child: SizedBox.shrink()),
          error: (_, __) => Text(
            t.homeYourDashboard,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          data: (user) {
            final profile = user['profile'] as Map<String, dynamic>? ?? {};
            final name = profile['full_name'] as String? ?? '';
            return Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Avatar and family profile switcher: tapping opens a dropdown to switch
// between the owner's own profile and any family member's. Shows the active
// profile's uploaded photo when one exists, falling back to an initial
// letter otherwise. The small chevron badge is the dropdown affordance.
class _AvatarButton extends ConsumerWidget {
  final AsyncValue<Map<String, dynamic>> userAsync;
  final ActiveProfile profile;
  final AppLocalizations t;
  const _AvatarButton(
      {required this.userAsync, required this.profile, required this.t});

  static const _kAvatarPalette = [
    Color(0xFFFFCDD2),
    Color(0xFFC8E6C9),
    Color(0xFFBBDEFB),
    Color(0xFFFFE0B2),
    Color(0xFFD1C4E9),
    Color(0xFFB2EBF2),
  ];

  Color _paletteColor(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return _kAvatarPalette[hash % _kAvatarPalette.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyMembersProvider);

    return PopupMenuButton<void>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 56),
      color: AppTheme.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:  BorderSide(color: AppTheme.cardBorder),
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 220),
      itemBuilder: (menuContext) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(t.homeSwitchProfile,
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ),
        ),
        PopupMenuItem<void>(
          padding: EdgeInsets.zero,
          onTap: () => ref.read(activeProfileProvider.notifier).switchToOwner(),
          child: userAsync.when(
            loading: () => _ownerRow(name: '…', photoUrl: null),
            error: (_, __) => _ownerRow(name: 'Owner', photoUrl: null),
            data: (user) {
              final userProfile =
                  user['profile'] as Map<String, dynamic>? ?? {};
              final name = userProfile['full_name'] as String? ?? 'You';
              final photoUrl = userProfile['profile_photo_url'] as String?;
              return _ownerRow(name: name, photoUrl: photoUrl);
            },
          ),
        ),
        ...familyAsync.maybeWhen(
          data: (members) => members.map((m) {
            final id = m['id']?.toString();
            final isActive = !profile.isOwnerMode && profile.memberId == id;
            return PopupMenuItem<void>(
              padding: EdgeInsets.zero,
              onTap: () =>
                  ref.read(activeProfileProvider.notifier).switchToMember(m),
              child: _memberRow(member: m, isActive: isActive),
            );
          }),
          orElse: () => const Iterable<PopupMenuItem<void>>.empty(),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<void>(
          padding: EdgeInsets.zero,
          onTap: () => context.push('/family/add'),
          child: _addMemberRow(),
        ),
      ],
      child: _avatarVisual(),
    );
  }

  // ── Avatar visual (circle + dropdown chevron badge) ─────────────────────────

  Widget _avatarVisual() {
    final Widget circle;
    if (!profile.isOwnerMode) {
      circle = profile.memberPhotoUrl != null
          ? _photoCircle(profile.memberPhotoUrl!)
          : _initialsCircle(profile.initial, Colors.white);
    } else {
      circle = userAsync.when(
        loading: () =>
            _initialsCircle(null, Colors.white12, icon: Icons.person),
        error: (_, __) =>
            _initialsCircle(null, Colors.white12, icon: Icons.person),
        data: (user) {
          final userProfile = user['profile'] as Map<String, dynamic>? ?? {};
          final photoUrl = userProfile['profile_photo_url'] as String?;
          final name = userProfile['full_name'] as String? ?? '?';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          if (photoUrl != null) return _photoCircle(photoUrl);
          return _initialsCircle(initial, Colors.white);
        },
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder, width: 1),
            ),
            child:
                 Icon(Icons.keyboard_arrow_down, size: 10, color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _photoCircle(String url) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: DecorationImage(
              image: CachedNetworkImageProvider(url,
                  cacheManager: RecordFileCacheManager.instance),
              fit: BoxFit.cover),
        ),
      );

  Widget _initialsCircle(String? text, Color bg, {IconData? icon}) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white70, size: 24)
              : Text(
                  text ?? '?',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      );

  // ── Dropdown rows ────────────────────────────────────────────────────────────

  Widget _ownerRow({required String name, String? photoUrl}) {
    return _dropdownRow(
      avatar: photoUrl != null
          ? CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider(photoUrl,
                  cacheManager: RecordFileCacheManager.instance))
          : CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
      name: name,
      subtitle: t.homeOwnerYou,
      isActive: profile.isOwnerMode,
    );
  }

  Widget _memberRow(
      {required Map<String, dynamic> member, required bool isActive}) {
    final name = member['full_name'] as String? ?? 'Member';
    final relationship = member['relationship'] as String? ?? 'Family';
    final photoUrl = member['photo_url'] as String?;
    final bg = _paletteColor(member['id']?.toString() ?? name);
    return _dropdownRow(
      avatar: photoUrl != null
          ? CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider(photoUrl,
                  cacheManager: RecordFileCacheManager.instance))
          : CircleAvatar(
              radius: 16,
              backgroundColor: bg,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style:  TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
      name: name,
      subtitle: relationship,
      isActive: isActive,
    );
  }

  Widget _dropdownRow({
    required Widget avatar,
    required String name,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
        border:
             Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (isActive)  Icon(Icons.check, size: 16, color: AppTheme.primary),
        ],
      ),
    );
  }

  Widget _addMemberRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                 BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
           Text(t.homeAddFamilyMember,
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

// ── Notification button ───────────────────────────────────────────────────────

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/alerts'),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ── Quick action cards ────────────────────────────────────────────────────────
// Exactly the 4 actions the web dashboard shows (Upload Document, Ask AI,
// Share with Doctor, View Summary) - Medications now has its own stat card
// below instead of a 5th action tile, matching web's layout.

class _DashboardQuickActions extends StatelessWidget {
  final AppLocalizations t;
  const _DashboardQuickActions({required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FeatureCard(
                icon: Icons.cloud_upload_outlined,
                iconBgColor: AppTheme.primary.withValues(alpha: 0.15),
                iconColor: AppTheme.primary,
                title: t.homeUploadDocument,
                titleColor: AppTheme.textPrimary,
                subtitle: t.homeUploadDocumentSubtitle,
                onTap: () => context.push('/records/upload'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FeatureCard(
                icon: Icons.auto_awesome,
                iconBgColor: AppTheme.success.withValues(alpha: 0.15),
                iconColor: AppTheme.success,
                title: t.homeAskAi,
                titleColor: AppTheme.textPrimary,
                subtitle: t.homeAskAiSubtitle,
                onTap: () => context.go('/ai'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FeatureCard(
                icon: Icons.qr_code_2,
                iconBgColor: AppTheme.info.withValues(alpha: 0.15),
                iconColor: AppTheme.info,
                title: t.homeShareWithDoctor,
                titleColor: AppTheme.textPrimary,
                subtitle: t.homeShareWithDoctorSubtitle,
                onTap: () => context.push('/share'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FeatureCard(
                icon: Icons.description_outlined,
                iconBgColor: AppTheme.textMuted.withValues(alpha: 0.15),
                iconColor: AppTheme.textSecondary,
                title: t.homeViewSummary,
                titleColor: AppTheme.textPrimary,
                subtitle: t.homeViewSummarySubtitle,
                onTap: () => context.push('/health-summary'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FeatureCard extends StatefulWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _hovered = false;
  bool _pressed = false;

  static const _kTeal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;
    final scale = _pressed ? 1.01 : (_hovered ? 1.04 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? _kTeal : AppTheme.cardBorder,
                width: active ? 1.5 : 1.0,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _kTeal.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: widget.iconBgColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Allergy alert ─────────────────────────────────────────────────────────────
// Slim card with a left accent border, shown only when the active profile has
// recorded allergies - mirrors web's allergyNames.length > 0 condition.

class _AllergyAlertCard extends ConsumerWidget {
  const _AllergyAlertCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final allergiesAsync = ref.watch(homeActiveAllergiesProvider);

    return allergiesAsync.maybeWhen(
      data: (names) {
        if (names.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => context.push('/health-summary'),
            // A BoxDecoration cannot combine a borderRadius with a Border
            // whose sides have different colors (the left accent stripe vs
            // the other three sides) - Flutter throws "A borderRadius can
            // only be given on borders with uniform colors" at paint time,
            // which silently dropped this card. ClipRRect plus a separate
            // accent-colored bar avoids that restriction entirely.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                // IntrinsicHeight gives the Row a defined height to stretch
                // the accent bar against - without it, stretching a child
                // next to unbounded content throws "BoxConstraints forces
                // an infinite height".
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: AppTheme.error),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.warning_amber_rounded,
                                    color: AppTheme.error, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.homeActiveAllergiesAlert,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      names.join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Text(
                                  t.homeViewDetails,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── Stat cards ────────────────────────────────────────────────────────────────
// Total Documents (with a category breakdown bar) and Medications (with a
// status line), stacked single-column for mobile rather than web's 2-col grid.

class _DashboardStatCards extends StatelessWidget {
  const _DashboardStatCards();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _DocumentsStatCard(),
        SizedBox(height: 14),
        _MedicationsStatCard(),
      ],
    );
  }
}

class _StatCardShell extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _StatCardShell({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 16,
              spreadRadius: 1,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _DocumentsStatCard extends ConsumerWidget {
  const _DocumentsStatCard();

  // Uses the app's own teal/amber/green tokens rather than AppTheme.info
  // (blue), which doesn't appear anywhere else in this palette.
  static Map<String, Color> get _kSegmentColors => {
        'prescription': AppTheme.primary,
        'radiology': AppTheme.warning,
        'lab_report': AppTheme.success,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final recordsAsync = ref.watch(recordsListProvider);

    return recordsAsync.maybeWhen(
      data: (records) {
        final segments = documentCategorySegments(
          records,
          t.recordTypePrescription,
          t.recordTypeRadiology,
          t.recordTypeLabReport,
          t.recordTypeOther,
        );
        final visibleSegments =
            segments.where((s) => s.count > 0).toList();

        return _StatCardShell(
          onTap: () => context.push('/records'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.homeTotalDocuments,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${records.length}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(t.homeUploadedLabel,
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  ),
                ],
              ),
              if (records.isNotEmpty) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        for (final segment in visibleSegments)
                          Expanded(
                            flex: segment.count,
                            child: Container(
                              color: _kSegmentColors[segment.key] ??
                                  AppTheme.textMuted.withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final segment in visibleSegments)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kSegmentColors[segment.key] ??
                                  AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${segment.count} ${segment.label}',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.upload_outlined, size: 14, color: AppTheme.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.homeNudgeNoDocumentsMessage,
                          style: TextStyle(fontSize: 12, color: AppTheme.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MedicationsStatCard extends ConsumerWidget {
  const _MedicationsStatCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final summaryAsync = ref.watch(healthSummaryProvider);
    final activeMedicationsAsync = ref.watch(activeMedicationsProvider);

    return summaryAsync.maybeWhen(
      data: (summary) {
        final count = summary['active_medications'] as int? ?? 0;
        String? reviewedLabel;
        activeMedicationsAsync.whenData((medications) {
          DateTime? mostRecent;
          for (final medication in medications) {
            final updatedAt = medication['updated_at'] as String?;
            if (updatedAt == null) continue;
            final parsed = DateTime.tryParse(updatedAt);
            final current = mostRecent;
            if (parsed != null && (current == null || parsed.isAfter(current))) {
              mostRecent = parsed;
            }
          }
          final latest = mostRecent;
          if (latest != null) {
            reviewedLabel = formatRelativeTime(latest, DateTime.now());
          }
        });

        return _StatCardShell(
          onTap: () => context.push('/medications'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.homeMedications,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(t.homeActiveLabel,
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  ),
                ],
              ),
              if (count == 0) ...[
                const SizedBox(height: 4),
                Text(t.homeNoMedicationsYet,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_rounded,
                          size: 14, color: AppTheme.warningDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.homeAddMedicationsHint,
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.warningDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Slim solid bar mirroring the Documents card's breakdown bar
                // above, so both stat cards carry the same visual weight.
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Container(color: AppTheme.primary),
                  ),
                ),
                if (reviewedLabel != null) ...[
                  const SizedBox(height: 10),
                  Text(t.homeMedicationsReviewedAgo(reviewedLabel!),
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── Shared "New" tag and empty state ──────────────────────────────────────────

class _NewTag extends ConsumerWidget {
  const _NewTag();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        t.homeNewTag.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppTheme.success,
        ),
      ),
    );
  }
}


// ── Recent Documents ──────────────────────────────────────────────────────────

class _RecentDocumentsSection extends ConsumerWidget {
  final AppLocalizations t;
  const _RecentDocumentsSection({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recordsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t.homeRecentDocuments,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            GestureDetector(
              onTap: () => context.push('/records'),
              child: Text(t.homeViewAll,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        recordsAsync.maybeWhen(
          data: (records) {
            final sorted = [...records]..sort((a, b) {
                final aDate = a['uploaded_at'] as String? ?? '';
                final bDate = b['uploaded_at'] as String? ?? '';
                return bDate.compareTo(aDate);
              });
            final recent = sorted.take(3).toList();
            if (recent.isEmpty) {
              return EmptyStateCard(
                icon: Icons.upload_outlined,
                tintBg: AppTheme.primary.withValues(alpha: 0.15),
                tintColor: AppTheme.primary,
                description: t.homeNoDocumentsMessage,
                actionLabel: t.homeUploadDocument,
                onAction: () => context.push('/records/upload'),
              );
            }
            return Column(
              children: [
                for (final record in recent) _DocumentTile(record: record),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  final Map<String, dynamic> record;
  const _DocumentTile({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final type = record['record_type'] as String? ?? 'other';
      final uploadedAt = record['uploaded_at'] as String?;
      final uploadedDate =
          uploadedAt != null ? DateTime.tryParse(uploadedAt) : null;
      final isNew = uploadedDate != null &&
          isWithinHours(uploadedDate, 48, DateTime.now());
      final statusLabel = recordStatusLabel(t, record['processing_status'] as String?);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () => context.push('/records/${record['id']}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _typeTint(type).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(recordTypeIcon(type), size: 18, color: _typeTint(type)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record['title'] as String? ?? t.recordsUntitled,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                          if (isNew) ...[
                            const SizedBox(width: 6),
                            const _NewTag(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${recordTypeLabel(t, type)} · $statusLabel',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  uploadedDate != null
                      ? '${formatCompactRelativeTime(uploadedDate, DateTime.now())} ago'
                      : '',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Color _typeTint(String type) {
    switch (type) {
      case 'prescription':
        return AppTheme.info;
      case 'radiology':
        return AppTheme.warning;
      case 'lab_report':
        return AppTheme.success;
      default:
        return AppTheme.primary;
    }
  }

}

// ── Recent AI Conversations ───────────────────────────────────────────────────

class _RecentConversationsSection extends ConsumerWidget {
  final AppLocalizations t;
  const _RecentConversationsSection({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(recentChatSessionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t.homeRecentConversations,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            GestureDetector(
              onTap: () => context.go('/ai'),
              child: Text(t.homeOpenAssistant,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        sessionsAsync.maybeWhen(
          data: (sessions) {
            if (sessions.isEmpty) {
              return EmptyStateCard(
                icon: Icons.chat_bubble_outline,
                tintBg: AppTheme.success.withValues(alpha: 0.15),
                tintColor: AppTheme.success,
                description: t.homeNoConversationsMessage,
                actionLabel: t.homeAskAi,
                onAction: () => context.go('/ai'),
              );
            }
            return Column(
              children: [
                for (final session in sessions) _ConversationTile(session: session),
              ],
            );
          },
          error: (_, __) => EmptyStateCard(
            icon: Icons.cloud_off_outlined,
            tintBg: AppTheme.error.withValues(alpha: 0.15),
            tintColor: AppTheme.error,
            description: t.homeConversationsLoadFailed,
            actionLabel: t.commonRetry,
            onAction: () => ref.invalidate(recentChatSessionsProvider),
          ),
          orElse: () => const Center(
              child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )),
        ),
      ],
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Map<String, dynamic> session;
  const _ConversationTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final t = ref.watch(appLocalizationsProvider);
      final title = (session['title'] as String?)?.trim();
      final updatedAt = session['updated_at'] as String?;
      final updatedDate = updatedAt != null ? DateTime.tryParse(updatedAt) : null;
      final isNew = updatedDate != null &&
          isWithinHours(updatedDate, 48, DateTime.now());
      final messageCount = session['total_messages'] as int? ?? 0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () => context.go('/ai', extra: session['id'] as String),
          // A BoxDecoration cannot combine a borderRadius with a Border whose
          // sides have different colors (the left accent stripe vs the other
          // three sides) - Flutter throws "A borderRadius can only be given
          // on borders with uniform colors" at paint time, which silently
          // dropped this tile. ClipRRect plus a separate accent-colored bar
          // avoids that restriction entirely.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.cardBorder),
              ),
              // IntrinsicHeight gives the Row a defined height to stretch
              // the accent bar against - without it, stretching a child next
              // to unbounded content throws "BoxConstraints forces an
              // infinite height".
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: AppTheme.info),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.info.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline,
                                  size: 18, color: AppTheme.info),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          title == null || title.isEmpty
                                              ? t.chatNewConversation
                                              : title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary),
                                        ),
                                      ),
                                      if (isNew) ...[
                                        const SizedBox(width: 6),
                                        const _NewTag(),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    updatedDate != null
                                        ? '${t.homeMessagesCount(messageCount)} · '
                                            '${formatRelativeTime(updatedDate, DateTime.now())} ago'
                                        : t.homeMessagesCount(messageCount),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
