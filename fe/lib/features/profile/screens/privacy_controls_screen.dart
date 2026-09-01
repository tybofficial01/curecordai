import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curecordai/core/theme/app_fonts.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/profile_providers.dart';

class PrivacyControlsScreen extends ConsumerWidget {
  const PrivacyControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final privacyAsync = ref.watch(privacyProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.privacyControlsTitle,
            style: AppFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: privacyAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) =>
            Center(child: Text(t.profileFailedToLoadWith(e.toString()))),
        data: (privacy) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  children: [
                    _ToggleRow(
                      title: t.privacyControlsBiometricLockTitle,
                      subtitle: t.privacyControlsBiometricLockSubtitle,
                      value: privacy.biometricLock,
                      onChanged: (v) =>
                          ref.read(privacyProvider.notifier).applyChanges(
                                privacy.copyWith(biometricLock: v),
                              ),
                    ),
                    const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        color: Color(0xFFE5E7EB)),
                    _ToggleRow(
                      title: t.privacyControlsAppLockTitle,
                      subtitle: t.privacyControlsAppLockSubtitle,
                      value: privacy.appLockOnBackground,
                      onChanged: (v) =>
                          ref.read(privacyProvider.notifier).applyChanges(
                                privacy.copyWith(appLockOnBackground: v),
                              ),
                    ),
                    const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        color: Color(0xFFE5E7EB)),
                    _ToggleRow(
                      title: t.privacyControlsScreenshotTitle,
                      subtitle: t.privacyControlsScreenshotSubtitle,
                      value: privacy.screenshotPrevention,
                      onChanged: (v) =>
                          ref.read(privacyProvider.notifier).applyChanges(
                                privacy.copyWith(screenshotPrevention: v),
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.privacyControlsNote,
                        style: AppFonts.manrope(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppFonts.manrope(
                        fontSize: 13, color: const Color(0xFF6B7280))),
              ],
            ),
          ),
          CupertinoSwitch(
              value: value,
              activeTrackColor: AppTheme.primary,
              onChanged: onChanged),
        ],
      ),
    );
  }
}
