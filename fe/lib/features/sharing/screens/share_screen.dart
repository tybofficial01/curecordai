import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';
import 'doctor_instructions_screen.dart';

final shareSessionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final response = await api.get<List<dynamic>>(
    '/share/sessions',
    queryParameters: memberId != null ? {'family_member_id': memberId} : null,
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

// Scope option values matching Figma order - labels are resolved via
// AppLocalizations at build time (see _scopeLabel below).
const _kScopeValues = [
  'last_1_year',
  'last_6_months',
  'full',
  'emergency_only',
];

String _scopeLabel(AppLocalizations t, String value) {
  switch (value) {
    case 'last_1_year':
      return t.shareScopeLast1Year;
    case 'last_6_months':
      return t.shareScopeLast6Months;
    case 'emergency_only':
      return t.shareScopeEmergencyOnly;
    case 'full':
    default:
      return t.shareScopeFullHistory;
  }
}

class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key});

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  String? _qrUrl;
  bool _isGenerating = false;
  String _selectedScope = 'full';
  bool _showQr = false;
  Timer? _validityTimer;
  int _validitySeconds =
      600; // fallback default; replaced by the backend's actual TTL on generate

  @override
  void dispose() {
    _validityTimer?.cancel();
    super.dispose();
  }

  void _startValidityTimer(int totalSeconds) {
    _validityTimer?.cancel();
    _validitySeconds = totalSeconds;
    _validityTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_validitySeconds > 0) {
          _validitySeconds--;
        } else {
          t.cancel();
          _qrUrl = null;
          _showQr = false;
        }
      });
    });
  }

  Future<void> _generateQr() async {
    setState(() {
      _isGenerating = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      final memberId = ref.read(activeMemberIdProvider);
      final response = await api.post<Map<String, dynamic>>('/share/qr', data: {
        'share_scope': _selectedScope,
        if (memberId != null) 'family_member_id': memberId,
      });
      setState(() {
        _qrUrl = response.data?['qr_url'];
        _showQr = true;
      });
      final expiresInSeconds =
          response.data?['expires_in_seconds'] as int? ?? 600;
      _startValidityTimer(expiresInSeconds);
      ref.invalidate(shareSessionsProvider);
    } catch (_) {
      if (!mounted) return;
      final t = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.shareFailedGenerateQr)),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final profile = ref.watch(activeProfileProvider);
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    if (!isOnline) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(t.shareRecordsTitle),
        ),
        body: OfflineBlockedNotice(
          message: t.shareOfflineMessage,
        ),
      );
    }
    if (_showQr && _qrUrl != null) {
      return _QrDisplayScreen(
        t: t,
        qrUrl: _qrUrl!,
        validitySeconds: _validitySeconds,
        onRegenerate: () {
          setState(() {
            _showQr = false;
            _qrUrl = null;
          });
          _validityTimer?.cancel();
          _generateQr();
        },
        onDone: () {
          setState(() {
            _showQr = false;
          });
          _validityTimer?.cancel();
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(profile.isOwnerMode
            ? t.shareRecordsTitle
            : t.shareRecordsTitleFor(profile.displayName)),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final unseenCount = ref.watch(unseenDoctorInstructionsCountProvider);
              return IconButton(
                tooltip: t.shareDoctorInstructionsTitle,
                onPressed: () => context.push('/share/instructions'),
                icon: Badge(
                  isLabelVisible: unseenCount > 0,
                  label: Text('$unseenCount'),
                  child: const Icon(Icons.mail_outline),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.isOwnerMode
                  ? t.shareSubtitleOwner
                  : t.shareSubtitleFor(profile.displayName),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Scope options - full-width radio rows matching Figma
            ..._kScopeValues.map((scopeValue) {
              final isSelected = _selectedScope == scopeValue;
              return GestureDetector(
                onTap: () => setState(() => _selectedScope = scopeValue),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected ? AppTheme.primary : AppTheme.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _scopeLabel(t, scopeValue),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.cardBorder,
                            width: 2,
                          ),
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.black, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Generate QR button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateQr,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.qr_code_2, size: 20),
                label: Text(_isGenerating
                    ? t.shareGeneratingButton
                    : t.shareGenerateQrButton),
              ),
            ),

            const SizedBox(height: 16),

            // Encrypted info note - matching Figma bottom note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppTheme.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.shareEncryptedNote,
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Active sessions
            Text(t.shareActiveSessionsTitle,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final sessionsAsync = ref.watch(shareSessionsProvider);
                return sessionsAsync.when(
                  loading: () => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return Text(t.shareNoActiveSessions,
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 13));
                    }
                    return Column(
                      children: sessions
                          .map((s) => _SessionTile(
                              session: s,
                              t: t,
                              onRevoke: () async {
                                try {
                                  final api = ref.read(apiClientProvider);
                                  await api
                                      .delete('/share/sessions/${s['id']}');
                                  ref.invalidate(shareSessionsProvider);
                                } catch (_) {}
                              }))
                          .toList(),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _QrDisplayScreen extends StatelessWidget {
  const _QrDisplayScreen({
    required this.t,
    required this.qrUrl,
    required this.validitySeconds,
    required this.onRegenerate,
    required this.onDone,
  });

  final AppLocalizations t;
  final String qrUrl;
  final int validitySeconds;
  final VoidCallback onRegenerate;
  final VoidCallback onDone;

  String get _validityText {
    if (validitySeconds <= 0) return t.shareValidityExpired;
    final mins = validitySeconds ~/ 60;
    final secs = validitySeconds % 60;
    if (mins > 0) {
      return t.shareValidityMinSec(mins, secs.toString().padLeft(2, '0'));
    }
    return t.shareValiditySeconds(secs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.appName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: onDone,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              t.shareShowDoctorTitle,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.shareShowDoctorSubtitle,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),

            // QR code card with teal background - matching Figma
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: qrUrl,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Validity timer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined,
                    color: AppTheme.textSecondary, size: 16),
                const SizedBox(width: 6),
                Text(
                  validitySeconds > 0
                      ? t.shareValidFor(_validityText)
                      : t.shareCodeExpired,
                  style: TextStyle(
                    color: validitySeconds > 60
                        ? AppTheme.textSecondary
                        : AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Regenerate link
            GestureDetector(
              onTap: onRegenerate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, color: AppTheme.primary, size: 16),
                  SizedBox(width: 4),
                  Text(t.shareRegenerateCode,
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            const Spacer(),

            // Copy link
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qrUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.shareLinkCopied)),
                );
              },
              icon: const Icon(Icons.copy, size: 14),
              label: Text(t.shareCopyLink),
            ),
            const SizedBox(height: 12),

            // Done button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                child: Text(t.commonDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile(
      {required this.session, required this.t, required this.onRevoke});
  final Map<String, dynamic> session;
  final AppLocalizations t;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scopeLabel(t, session['share_scope'] ?? 'full'),
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  t.shareScanned((session['scan_count'] ?? 0) as int),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRevoke,
            child: Text(t.shareRevoke,
                style: TextStyle(color: AppTheme.error, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
