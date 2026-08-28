import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  List<_TabItem> _tabs(AppLocalizations t) => [
        _TabItem(
          path: '/home',
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view,
          label: t.navDashboard,
        ),
        _TabItem(
          path: '/records',
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: t.navRecords,
        ),
        _TabItem(
          path: '/medications',
          icon: Icons.medication_outlined,
          activeIcon: Icons.medication,
          label: t.navMedications,
        ),
        _TabItem(
          path: '/insights',
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart,
          label: t.navInsights,
        ),
        _TabItem(
          path: '/settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: t.navSettings,
        ),
      ];

  // -1 when on a shell screen that isn't one of the tabs (e.g. the AI
  // assistant, opened from the floating button) - no tab is highlighted then.
  int _currentIndex(BuildContext context, List<_TabItem> tabs) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].path)) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final tabs = _tabs(t);
    final currentIndex = _currentIndex(context, tabs);
    // Redundant on the AI assistant screen itself, and it overlaps the chat
    // input bar there, so hide it only on that screen.
    final onAiScreen =
        GoRouterState.of(context).matchedLocation.startsWith('/ai');

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(
        tabs: tabs,
        currentIndex: currentIndex,
        onTap: (path) => context.go(path),
      ),
      floatingActionButton: onAiScreen
          ? null
          : _AiAssistantButton(
              label: t.navAiAssistant,
              onTap: () => context.go('/ai'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ── AI Assistant floating action button ───────────────────────────────────────
// A regular floating action button docked bottom right, sitting above the nav
// bar rather than embedded inside it - Scaffold's endFloat location keeps it
// clear of the bar automatically.

class _AiAssistantButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AiAssistantButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────
// Plain straight rectangular bar - no notch, no cutout, no raised centre item.

class _BottomNavBar extends StatelessWidget {
  final List<_TabItem> tabs;
  final int currentIndex;
  final void Function(String path) onTap;

  const _BottomNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 64,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final isActive = i == currentIndex;

            return Expanded(
              child: _NavTab(
                tab: tab,
                isActive: isActive,
                onTap: () => onTap(tab.path),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Regular tab item ──────────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? tab.activeIcon : tab.icon,
              key: ValueKey(isActive),
              color: isActive ? AppTheme.primary : AppTheme.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tab.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? AppTheme.primary : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab model ─────────────────────────────────────────────────────────────────

class _TabItem {
  const _TabItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
