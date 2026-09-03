import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Wraps [child] with a persistent offline indicator banner shown whenever the
/// device has no connection. Mounted once at the app root (`app.dart`) so every
/// screen - including the ones above the tab shell - gets it for free, instead
/// of every API-backed screen wiring its own connectivity check.
class OfflineBannerScope extends ConsumerWidget {
  const OfflineBannerScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    return Column(
      children: [
        if (!isOnline)
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: AppTheme.warning,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "You're offline - showing last saved data",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

/// Full-body "this needs a connection" placeholder for screens that must be
/// disabled entirely when offline (upload, AI assistant, doctor sharing) rather
/// than falling back to cached data, since they either write data or stream a
/// live response that can't be served from cache.
class OfflineBlockedNotice extends StatelessWidget {
  const OfflineBlockedNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              "You're offline",
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
