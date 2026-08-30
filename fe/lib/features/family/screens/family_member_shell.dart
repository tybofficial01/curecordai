import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../ai_chat/screens/ai_chat_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../insights/screens/insights_screen.dart';
import '../../medications/screens/medications_screen.dart';
import '../../records/screens/records_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/active_profile_provider.dart';

class FamilyMemberShell extends ConsumerStatefulWidget {
  const FamilyMemberShell({super.key});

  @override
  ConsumerState<FamilyMemberShell> createState() => _FamilyMemberShellState();
}

class _FamilyMemberShellState extends ConsumerState<FamilyMemberShell> {
  int _currentTab = 0;

  // Index of the AI assistant screen in the IndexedStack below - it isn't a
  // nav bar tab any more, so it isn't part of _tabItems.
  static const _kAiScreenIndex = 5;

  // Exact mirror of MainShell tab definitions
  List<_TabDef> _tabItems(AppLocalizations t) => [
        _TabDef(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: t.navDashboard),
        _TabDef(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder,
            label: t.navRecords),
        _TabDef(
            icon: Icons.medication_outlined,
            activeIcon: Icons.medication,
            label: t.navMedications),
        _TabDef(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            label: t.navInsights),
        _TabDef(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: t.navSettings),
      ];

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final tabItems = _tabItems(t);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(activeProfileProvider.notifier).switchToOwner();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: IndexedStack(
          index: _currentTab,
          children: const [
            HomeScreen(),
            RecordsScreen(),
            MedicationsScreen(),
            InsightsScreen(),
            SettingsScreen(),
            AiChatScreen(),
          ],
        ),

        // ── Bottom nav (mirrors MainShell styling) - plain rectangular bar,
        //    no notch, no raised centre item.
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.cardBorder)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: List.generate(tabItems.length, (i) {
                  final tab = tabItems[i];
                  final isActive = i == _currentTab;

                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currentTab = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            color: isActive
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),

        // ── AI Assistant floating action button - docked bottom right,
        //    above the nav bar rather than embedded inside it.
        floatingActionButton: _AiAssistantButton(
          label: t.navAiAssistant,
          onTap: () => setState(() => _currentTab = _kAiScreenIndex),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

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

// ── Tab definition ────────────────────────────────────────────────────────────

class _TabDef {
  const _TabDef({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
