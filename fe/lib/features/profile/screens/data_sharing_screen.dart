import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/profile_models.dart';
import '../providers/profile_providers.dart';

class DataSharingScreen extends ConsumerWidget {
  const DataSharingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final sharingAsync = ref.watch(dataSharingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.dataSharingTitle,
            style: AppFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              t.dataSharingSubtitle,
              style: AppFonts.manrope(
                  fontSize: 13, color: const Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: sharingAsync.when(
              loading: () => Center(
                  child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) =>
                  Center(child: Text(t.profileFailedToLoadWith(e.toString()))),
              data: (entries) {
                if (entries.isEmpty) {
                  return _EmptyState(t: t);
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _SharingCard(
                    entry: entries[i],
                    t: t,
                    onRevoke: () => _confirmRevoke(context, ref, entries[i], t),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(t.dataSharingAddNewAccess,
                  style: AppFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white)),
              onPressed: () => _showAddSheet(context, ref),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRevoke(BuildContext context, WidgetRef ref,
      DataSharingSchema entry, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.dataSharingRevokeAccessTitle,
            style: AppFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text(
          t.dataSharingRevokeAccessConfirm(entry.name),
          style: AppFonts.manrope(color: const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.commonCancel,
                style: AppFonts.manrope(color: const Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dataSharingProvider.notifier).revoke(entry.id);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.dataSharingRevokeFailed)),
                  );
                }
              }
            },
            child: Text(t.dataSharingRevoke,
                style: AppFonts.manrope(
                    color: AppTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddAccessSheet(ref: ref),
    );
  }
}

class _SharingCard extends StatelessWidget {
  const _SharingCard(
      {required this.entry, required this.onRevoke, required this.t});
  final DataSharingSchema entry;
  final VoidCallback onRevoke;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final isFullAccess = entry.accessType.toLowerCase() == 'full';
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: AppFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isFullAccess
                            ? const Color(0xFFE8F5F4)
                            : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isFullAccess
                            ? t.dataSharingAccessFull
                            : t.dataSharingAccessRead,
                        style: AppFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isFullAccess
                              ? AppTheme.primary
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    if (entry.grantedUntil != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        t.dataSharingUntil(entry.grantedUntil ?? ''),
                        style: AppFonts.manrope(
                            fontSize: 12, color: const Color(0xFF6B7280)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            onPressed: onRevoke,
            child: Text(t.dataSharingRevoke,
                style: AppFonts.manrope(
                    color: AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.share_outlined, size: 64, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(t.dataSharingEmptyTitle,
              style: AppFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text(t.dataSharingEmptyBody,
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                  fontSize: 13, color: const Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _AddAccessSheet extends StatefulWidget {
  const _AddAccessSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_AddAccessSheet> createState() => _AddAccessSheetState();
}

class _AddAccessSheetState extends State<_AddAccessSheet> {
  final _nameCtrl = TextEditingController();
  String _accessType = 'read';
  DateTime? _grantedUntil;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final t = widget.ref.read(appLocalizationsProvider);
    setState(() => _isLoading = true);
    try {
      await widget.ref.read(dataSharingProvider.notifier).add(DataSharingSchema(
            id: '',
            name: _nameCtrl.text.trim(),
            accessType: _accessType,
            grantedUntil: _grantedUntil != null
                ? DateFormat('yyyy-MM-dd').format(_grantedUntil!)
                : null,
          ));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.dataSharingAddFailed)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _grantedUntil = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ref.watch(appLocalizationsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.dataSharingAddNewAccess,
              style: AppFonts.manrope(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Text(t.dataSharingDoctorHospitalName,
              style: AppFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
              controller: _nameCtrl,
              decoration:
                  InputDecoration(hintText: t.dataSharingEnterName)),
          const SizedBox(height: 14),
          Text(t.dataSharingAccessType,
              style: AppFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _accessType,
            items: [
              DropdownMenuItem(
                  value: 'read', child: Text(t.dataSharingAccessRead)),
              DropdownMenuItem(
                  value: 'full', child: Text(t.dataSharingAccessFull)),
            ],
            onChanged: (v) => setState(() => _accessType = v ?? 'read'),
          ),
          const SizedBox(height: 14),
          Text(t.dataSharingGrantedUntilOptional,
              style: AppFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _grantedUntil != null
                          ? DateFormat('dd / MM / yyyy').format(_grantedUntil!)
                          : t.dataSharingNoExpiry,
                      style: AppFonts.manrope(
                          color: _grantedUntil != null
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF9CA3AF),
                          fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF6B7280), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: _isLoading ? null : _grant,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(t.dataSharingGrantAccess,
                      style: AppFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
