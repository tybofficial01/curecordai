import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';

final doctorInstructionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final response = await api.get<List<dynamic>>(
    '/share/instructions',
    queryParameters: memberId != null ? {'family_member_id': memberId} : null,
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

final unseenDoctorInstructionsCountProvider = Provider<int>((ref) {
  final instructions = ref.watch(doctorInstructionsProvider).valueOrNull;
  if (instructions == null) return 0;
  return instructions.where((i) => i['seen_at'] == null).length;
});

class DoctorInstructionsScreen extends ConsumerWidget {
  const DoctorInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final instructionsAsync = ref.watch(doctorInstructionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(t.shareDoctorInstructionsTitle)),
      body: instructionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(t.shareInstructionsLoadError,
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (instructions) {
          if (instructions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.shareInstructionsEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: instructions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _InstructionTile(instruction: instructions[index], t: t),
          );
        },
      ),
    );
  }
}

class _InstructionTile extends ConsumerStatefulWidget {
  const _InstructionTile({required this.instruction, required this.t});
  final Map<String, dynamic> instruction;
  final AppLocalizations t;

  @override
  ConsumerState<_InstructionTile> createState() => _InstructionTileState();
}

class _InstructionTileState extends ConsumerState<_InstructionTile> {
  bool _expanded = false;

  bool get _isUnseen => widget.instruction['seen_at'] == null;

  Future<void> _markRead() async {
    if (!_isUnseen) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/share/instructions/${widget.instruction['id']}/read');
      ref.invalidate(doctorInstructionsProvider);
    } catch (_) {
      // Non-critical - the patient has already read the content on screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final doctorName = widget.instruction['doctor_name'] ?? t.shareDoctorNameFallback;
    final institution = widget.instruction['doctor_institution'] ?? '';
    final createdAt = widget.instruction['created_at'] as String?;
    final text = widget.instruction['instructions'] ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: InkWell(
        onTap: () {
          setState(() => _expanded = !_expanded);
          if (_expanded) _markRead();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isUnseen)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    t.shareDoctorInstructionRow(doctorName, institution),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              createdAt != null ? _formatDate(createdAt) : '',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(
                text,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
