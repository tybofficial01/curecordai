import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai_chat/screens/ai_chat_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../insights/providers/insights_provider.dart';
import '../providers/records_provider.dart';
import '../widgets/document_viewer_modal.dart';
import '../widgets/record_preview_sheet.dart';

// ── Record type helpers ────────────────────────────────────────────────────────

/// Backend record_type values, in the order the type picker lists them.
/// Labels/icons come from the shared helpers in record_preview_sheet.dart so
/// a document reads the same everywhere it appears.
const _kRecordTypeIds = [
  'lab_report',
  'prescription',
  'radiology',
  'discharge_summary',
  'vaccination',
  'insurance',
  'referral',
  'other',
];

String _typeLabel(AppLocalizations t, String type) => recordTypeLabel(t, type);

IconData _typeIcon(String type) => recordTypeIcon(type);

String _formatDate(AppLocalizations t, String? iso) =>
    formatRecordDate(t, iso);

// ── Screen ─────────────────────────────────────────────────────────────────────

class RecordDetailScreen extends ConsumerStatefulWidget {
  const RecordDetailScreen({super.key, required this.recordId});
  final String recordId;

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  // ── Edit state ─────────────────────────────────────────────────────────────
  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  final _titleCtrl = TextEditingController();
  final _patientCtrl = TextEditingController();
  final _labCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  String? _editType;
  DateTime? _editDate;

  // Tracks original values to detect dirty state
  Map<String, dynamic>? _original;

  // ── Polling ────────────────────────────────────────────────────────────────
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _titleCtrl.dispose();
    _patientCtrl.dispose();
    _labCtrl.dispose();
    _doctorCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final record = ref.read(recordFullProvider(widget.recordId)).value;
      if (record == null) return;
      if (record['processing_status'] != 'processing') {
        _pollTimer?.cancel();
        _pollTimer = null;
        // Analysis just finished - refresh the Dashboard's recent-activity
        // list and stats so they pick up the new record/extracted data
        // instead of showing whatever was cached before this record's
        // pipeline completed.
        await ref.read(apiClientProvider).clearCachePath('/records');
        ref.invalidate(recentRecordsProvider);
        ref.invalidate(recordsListProvider);
        ref.invalidate(healthSummaryProvider);
        return;
      }
      // Bust the /records HTTP cache too - recordsListProvider uses
      // CachePolicy.forceCache, so without this ref.invalidate() below just
      // re-serves the same stale cached response for up to its 5-minute
      // maxStale window and the Records screen never sees this record leave
      // "processing".
      await ref.read(apiClientProvider).clearCachePath('/records');
      ref.invalidate(recordFullProvider(widget.recordId));
      ref.invalidate(recordsListProvider);
    });
  }

  void _onDataLoaded(Map<String, dynamic> record) {
    if (record['processing_status'] == 'processing' && _pollTimer == null) {
      _startPolling();
    }
    if (record['processing_status'] != 'processing') {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  // ── Enter / exit edit mode ─────────────────────────────────────────────────
  void _enterEditMode(Map<String, dynamic> record) {
    _original = record;
    _titleCtrl.text = record['title'] as String? ?? '';
    _patientCtrl.text = record['patient_name_on_doc'] as String? ?? '';
    _labCtrl.text = record['laboratory_name'] as String? ?? '';
    _doctorCtrl.text = record['referring_doctor'] as String? ?? '';
    _editType = record['record_type'] as String?;
    final dateStr = record['record_date'] as String?;
    _editDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
    setState(() => _editing = true);
  }

  void _cancelEdit() => setState(() => _editing = false);

  Future<void> _saveEdit() async {
    final t = ref.read(appLocalizationsProvider);
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{};
      final title = _titleCtrl.text.trim();
      if (title.isNotEmpty && title != (_original?['title'] ?? ''))
        body['title'] = title;
      if (_editType != null && _editType != _original?['record_type'])
        body['record_type'] = _editType;
      if (_editDate != null) {
        final iso = _editDate!.toIso8601String().split('T').first;
        if (iso != (_original?['record_date'] ?? '')) body['record_date'] = iso;
      }
      final patient = _patientCtrl.text.trim();
      if (patient != (_original?['patient_name_on_doc'] ?? ''))
        body['patient_name_on_doc'] = patient;
      final lab = _labCtrl.text.trim();
      if (lab != (_original?['laboratory_name'] ?? ''))
        body['laboratory_name'] = lab;
      final doctor = _doctorCtrl.text.trim();
      if (doctor != (_original?['referring_doctor'] ?? ''))
        body['referring_doctor'] = doctor;

      if (body.isNotEmpty) {
        final api = ref.read(apiClientProvider);
        await api.patch('/records/${widget.recordId}', data: body);
        await api.clearCachePath('/records');
        ref.invalidate(recordFullProvider(widget.recordId));
        ref.invalidate(recordsListProvider);
      }
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg =
          (e.response?.data is Map ? e.response!.data['detail'] : null) ??
              t.errorSaveChangesFailed;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final t = ref.read(appLocalizationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(t.recordsDeleteTitle,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        content: Text(
          t.recordDeletePermanentBody,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.commonCancel,
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.commonDelete,
                  style: TextStyle(
                      color: AppTheme.error, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/records/${widget.recordId}');
      await RecordFileCacheManager.instance.removeFile(widget.recordId);
      await api.clearCachePath('/records');
      ref.invalidate(recordsListProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.recordsDeleteFailed)));
      }
    }
  }

  // ── Open document ──────────────────────────────────────────────────────────
  Future<void> _openDocument(String? url, String mimeType, String title) async {
    final t = ref.read(appLocalizationsProvider);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.recordDocumentLinkUnavailable)));
      return;
    }
    await showDocumentViewerModal(
      context,
      recordId: widget.recordId,
      downloadUrl: url,
      mimeType: mimeType,
      title: title,
    );
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _editDate ?? now,
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _editDate = picked);
  }

  // ── Type picker ────────────────────────────────────────────────────────────
  Future<void> _pickType() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TypePickerSheet(current: _editType ?? 'other'),
    );
    if (picked != null) setState(() => _editType = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final recordAsync = ref.watch(recordFullProvider(widget.recordId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(t.recordDetailsTitle),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: t.commonEdit,
              onPressed: () {
                final record = recordAsync.value;
                if (record != null) _enterEditMode(record);
              },
            ),
          if (_deleting)
            Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.error)),
            )
          else
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppTheme.error),
              tooltip: t.commonDelete,
              onPressed: _editing ? null : _confirmDelete,
            ),
        ],
      ),
      body: recordAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(t.recordLoadFailed,
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.refresh(recordFullProvider(widget.recordId)),
                child: Text(t.commonRetry),
              ),
            ],
          ),
        ),
        data: (record) {
          // Side-effect: start/stop polling based on processing status
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onDataLoaded(record);
          });

          final status = record['processing_status'] as String? ?? '';
          final hasAnalysis = record['ai_analysis'] != null;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, _editing ? 96 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Processing banner ──────────────────────────────────
                    if (status == 'processing') const _ProcessingBanner(),

                    if (status == 'failed')
                      _FailedBanner(
                          error: record['processing_error'] as String?),

                    // ── AI Summary text ─────────────────────────────────────
                    if (record['ai_summary'] != null) ...[
                      _AiSummaryCard(summary: record['ai_summary'] as String),
                      const SizedBox(height: 16),
                    ],

                    // ── Quick actions ──────────────────────────────────────
                    _QuickActions(
                      downloadUrl: record['download_url'] as String?,
                      hasAnalysis: hasAnalysis,
                      record: record,
                      onDownload: () => _openDocument(
                        record['download_url'] as String?,
                        record['file_mime_type'] as String? ?? '',
                        record['title'] as String? ?? t.recordDocumentWord,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Document details (editable) ────────────────────────
                    _SectionHeader(
                      title: t.recordDocumentDetails,
                      editing: _editing,
                      onEdit: () => _enterEditMode(record),
                      onCancel: _cancelEdit,
                    ),
                    const SizedBox(height: 8),
                    _DetailCard(
                      child: Column(
                        children: [
                          _editing
                              ? _EditField(
                                  label: t.fieldTitle,
                                  controller: _titleCtrl,
                                  icon: Icons.title,
                                )
                              : _ReadRow(
                                  label: t.fieldTitle,
                                  value: record['title'] as String? ?? ' - ',
                                  icon: Icons.title,
                                ),
                          const _Divider(),
                          _editing
                              ? _TappableRow(
                                  label: t.fieldType,
                                  value: _typeLabel(t, _editType ?? 'other'),
                                  icon: _typeIcon(_editType ?? 'other'),
                                  onTap: _pickType,
                                  trailing: Icon(Icons.chevron_right,
                                      size: 16, color: AppTheme.textMuted),
                                )
                              : _ReadRow(
                                  label: t.fieldType,
                                  value: _typeLabel(
                                      t,
                                      record['record_type'] as String? ??
                                          'other'),
                                  icon: _typeIcon(
                                      record['record_type'] as String? ??
                                          'other'),
                                ),
                          const _Divider(),
                          _editing
                              ? _TappableRow(
                                  label: t.fieldDate,
                                  value: _editDate != null
                                      ? _formatDate(
                                          t, _editDate!.toIso8601String())
                                      : t.commonTapToSet,
                                  icon: Icons.calendar_today_outlined,
                                  onTap: _pickDate,
                                  trailing: Icon(Icons.chevron_right,
                                      size: 16, color: AppTheme.textMuted),
                                )
                              : _ReadRow(
                                  label: t.fieldDate,
                                  value: _formatDate(
                                      t, record['record_date'] as String?),
                                  icon: Icons.calendar_today_outlined,
                                ),
                          const _Divider(),
                          _editing
                              ? _EditField(
                                  label: t.fieldPatientName,
                                  controller: _patientCtrl,
                                  icon: Icons.person_outlined,
                                )
                              : _ReadRow(
                                  label: t.fieldPatientName,
                                  value: record['patient_name_on_doc']
                                          as String? ??
                                      ' - ',
                                  icon: Icons.person_outlined,
                                ),
                          const _Divider(),
                          _editing
                              ? _EditField(
                                  label: t.fieldIssuingLabOrg,
                                  controller: _labCtrl,
                                  icon: Icons.business_outlined,
                                )
                              : _ReadRow(
                                  label: t.fieldIssuingLabOrg,
                                  value: record['laboratory_name'] as String? ??
                                      record['issuing_organization']
                                          as String? ??
                                      ' - ',
                                  icon: Icons.business_outlined,
                                ),
                          const _Divider(),
                          _editing
                              ? _EditField(
                                  label: t.fieldReferringDoctor,
                                  controller: _doctorCtrl,
                                  icon: Icons.medical_information_outlined,
                                )
                              : _ReadRow(
                                  label: t.fieldReferringDoctor,
                                  value:
                                      record['referring_doctor'] as String? ??
                                          ' - ',
                                  icon: Icons.medical_information_outlined,
                                ),
                          const _Divider(),
                          _ReadRow(
                            label: t.fieldFile,
                            value: record['file_name'] as String? ?? ' - ',
                            icon: Icons.attach_file_outlined,
                          ),
                          const _Divider(),
                          _ReadRow(
                            label: t.fieldStatus,
                            value: _statusLabel(t, status),
                            icon: _statusIcon(status),
                            valueColor: _statusColor(status),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Clinical data sections ─────────────────────────────
                    if (status == 'completed')
                      _ClinicalDataSection(
                        recordId: widget.recordId,
                        clinical: (record['clinical']
                                as Map<String, dynamic>?) ??
                            const {},
                      ),
                  ],
                ),
              ),

              // ── Floating save bar ──────────────────────────────────────────
              if (_editing)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _SaveBar(
                    saving: _saving,
                    onSave: _saveEdit,
                    onCancel: _cancelEdit,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Banners ────────────────────────────────────────────────────────────────────

class _ProcessingBanner extends ConsumerWidget {
  const _ProcessingBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.info)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(t.recordAiExtracting,
                style: TextStyle(color: AppTheme.info, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _FailedBanner extends ConsumerWidget {
  const _FailedBanner({this.error});
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error != null && error!.isNotEmpty
                  ? t.recordProcessingFailedWithReason(error!)
                  : t.recordAiProcessingFailed,
              style: TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ──────────────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  const _QuickActions({
    required this.downloadUrl,
    required this.hasAnalysis,
    required this.record,
    required this.onDownload,
  });
  final String? downloadUrl;
  final bool hasAnalysis;
  final Map<String, dynamic> record;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final recordId = record['id'] as String;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.open_in_new_outlined, size: 16),
                label: Text(t.recordViewOriginal),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (hasAnalysis) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/records/$recordId/summary'),
                  icon: const Icon(Icons.auto_awesome,
                      size: 16, color: Colors.white),
                  label: Text(t.recordsAiSummary),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go(
              '/ai',
              extra: AiChatAttachment(
                recordId: recordId,
                title: record['title'] as String? ?? t.recordWord,
                recordType: record['record_type'] as String? ?? 'other',
                recordDate: record['record_date'] as String?,
                familyMemberId: record['family_member_id'] as String?,
              ),
            ),
            icon: const Icon(Icons.chat_outlined, size: 16),
            label: Text(t.recordsExplainWithAi),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends ConsumerWidget {
  const _SectionHeader({
    required this.title,
    this.editing = false,
    this.onEdit,
    this.onCancel,
  });
  final String title;
  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const Spacer(),
        if (!editing && onEdit != null)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 13),
            label: Text(t.commonEdit, style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          ),
        if (editing && onCancel != null)
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(t.commonCancel, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

// ── Detail card ────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(color: AppTheme.cardBorder, height: 1, indent: 16);
}

// ── Read-only row ──────────────────────────────────────────────────────────────

class _ReadRow extends StatelessWidget {
  const _ReadRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: valueColor ?? AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Editable field ─────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
  });
  final String label;
  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                border: OutlineInputBorder(),
                constraints: BoxConstraints(minHeight: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable row (for date/type pickers) ──────────────────────────────────────

class _TappableRow extends StatelessWidget {
  const _TappableRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.trailing,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.end),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

// ── Floating save bar ──────────────────────────────────────────────────────────

class _SaveBar extends ConsumerWidget {
  const _SaveBar(
      {required this.saving, required this.onSave, required this.onCancel});
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : onCancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(t.commonCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(t.commonSaveChanges),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI summary text card ───────────────────────────────────────────────────────

class _AiSummaryCard extends ConsumerWidget {
  const _AiSummaryCard({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primary, size: 15),
              const SizedBox(width: 7),
              Text(t.recordsAiSummary,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(summary,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
        ],
      ),
    );
  }
}

// ── Clinical data section ──────────────────────────────────────────────────────

class _ClinicalDataSection extends ConsumerWidget {
  const _ClinicalDataSection({required this.recordId, required this.clinical});
  final String recordId;
  final Map<String, dynamic> clinical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final observations =
        (clinical['observations'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final conditions =
        (clinical['conditions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final medications =
        (clinical['medications'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final allergies =
        (clinical['allergies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final encounters =
        (clinical['encounters'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (observations.isEmpty &&
        conditions.isEmpty &&
        medications.isEmpty &&
        allergies.isEmpty &&
        encounters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (observations.isNotEmpty) ...[
          _ClinicalBlock(
            title: t.clinicalLabResultsVitals,
            icon: Icons.science_outlined,
            children: observations
                .map((o) => GestureDetector(
                      onTap: () => _showEditEntitySheet(
                          context, ref, recordId, _EntityKind.observation, o),
                      child: _ObservationRow(o),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (conditions.isNotEmpty) ...[
          _ClinicalBlock(
            title: t.clinicalConditions,
            icon: Icons.monitor_heart_outlined,
            children: conditions
                .map((c) => GestureDetector(
                      onTap: () => _showEditEntitySheet(
                          context, ref, recordId, _EntityKind.condition, c),
                      child: _ConditionRow(c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (medications.isNotEmpty) ...[
          _ClinicalBlock(
            title: t.clinicalMedications,
            icon: Icons.medication_outlined,
            children: medications
                .map((m) => GestureDetector(
                      onTap: () => _showEditEntitySheet(
                          context, ref, recordId, _EntityKind.medication, m),
                      child: _MedicationRow(m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (allergies.isNotEmpty) ...[
          _ClinicalBlock(
            title: t.fieldAllergies,
            icon: Icons.warning_amber_outlined,
            children: allergies
                .map((a) => GestureDetector(
                      onTap: () => _showEditEntitySheet(
                          context, ref, recordId, _EntityKind.allergy, a),
                      child: _AllergyRow(a),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (encounters.isNotEmpty) ...[
          _ClinicalBlock(
            title: t.clinicalVisitsEncounters,
            icon: Icons.local_hospital_outlined,
            children: encounters
                .map((e) => GestureDetector(
                      onTap: () => _showEditEntitySheet(
                          context, ref, recordId, _EntityKind.encounter, e),
                      child: _EncounterRow(e),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ── Editable clinical entities ─────────────────────────────────────────────────
// Every AI-extracted clinical field (conditions, medications, observations, allergies,
// encounters) is user-editable - tapping any row opens a small entity-specific edit sheet
// that PATCHes the corresponding clinical endpoint and refreshes the record's clinical data.

enum _EntityKind { condition, medication, observation, allergy, encounter }

String _apiPathFor(_EntityKind kind) {
  switch (kind) {
    case _EntityKind.condition:
      return '/conditions';
    case _EntityKind.medication:
      return '/medications';
    case _EntityKind.observation:
      return '/observations';
    case _EntityKind.allergy:
      return '/allergies';
    case _EntityKind.encounter:
      return '/encounters';
  }
}

String _sheetTitleFor(AppLocalizations t, _EntityKind kind) {
  switch (kind) {
    case _EntityKind.condition:
      return t.clinicalEditCondition;
    case _EntityKind.medication:
      return t.clinicalEditMedication;
    case _EntityKind.observation:
      return t.clinicalEditObservation;
    case _EntityKind.allergy:
      return t.clinicalEditAllergy;
    case _EntityKind.encounter:
      return t.clinicalEditVisit;
  }
}

class _FieldSpec {
  _FieldSpec({
    required this.key,
    required this.label,
    this.initialValue,
    this.options,
    this.keyboardType,
  });
  final String key;
  final String label;
  final String? initialValue;
  final List<String>? options; // non-null => rendered as a dropdown
  final TextInputType? keyboardType;
}

List<_FieldSpec> _fieldsFor(
    AppLocalizations t, _EntityKind kind, Map<String, dynamic> item) {
  String? s(String key) => item[key]?.toString();
  switch (kind) {
    case _EntityKind.condition:
      return [
        _FieldSpec(
            key: 'condition_name',
            label: t.clinicalConditionField,
            initialValue: s('condition_name')),
        _FieldSpec(
          key: 'clinical_status',
          label: t.fieldStatus,
          initialValue: s('clinical_status'),
          options: const [
            'active',
            'recurrence',
            'relapse',
            'inactive',
            'remission',
            'resolved'
          ],
        ),
        _FieldSpec(
          key: 'severity',
          label: t.clinicalSeverity,
          initialValue: s('severity'),
          options: const ['mild', 'moderate', 'severe'],
        ),
      ];
    case _EntityKind.medication:
      return [
        _FieldSpec(
            key: 'medication_name_raw',
            label: t.clinicalMedicationField,
            initialValue: s('medication_name_raw')),
        _FieldSpec(
            key: 'dosage_instruction',
            label: t.clinicalDosage,
            initialValue: s('dosage_instruction')),
        _FieldSpec(
            key: 'dose_frequency',
            label: t.clinicalFrequency,
            initialValue: s('dose_frequency')),
        _FieldSpec(
          key: 'status',
          label: t.fieldStatus,
          initialValue: s('status'),
          options: const [
            'active',
            'on-hold',
            'cancelled',
            'completed',
            'stopped',
            'draft',
            'unknown'
          ],
        ),
      ];
    case _EntityKind.observation:
      final hasQuantity = item['value_quantity'] != null;
      return [
        _FieldSpec(
            key: 'observation_name',
            label: t.clinicalTestVitalName,
            initialValue: s('observation_name')),
        if (hasQuantity)
          _FieldSpec(
            key: 'value_quantity',
            label: t.clinicalValue,
            initialValue: s('value_quantity'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          )
        else
          _FieldSpec(
              key: 'value_string',
              label: t.clinicalValue,
              initialValue: s('value_string')),
        _FieldSpec(
            key: 'value_unit',
            label: t.clinicalUnit,
            initialValue: s('value_unit')),
        _FieldSpec(
          key: 'interpretation',
          label: t.clinicalInterpretation,
          initialValue: s('interpretation'),
          options: const ['N', 'L', 'H', 'LL', 'HH', 'A', 'AA'],
        ),
      ];
    case _EntityKind.allergy:
      return [
        _FieldSpec(
            key: 'substance_name',
            label: t.clinicalSubstance,
            initialValue: s('substance_name')),
        _FieldSpec(
          key: 'criticality',
          label: t.clinicalCriticality,
          initialValue: s('criticality'),
          options: const ['low', 'high', 'unable-to-assess'],
        ),
        _FieldSpec(
            key: 'reaction_description',
            label: t.clinicalReaction,
            initialValue: s('reaction_description')),
      ];
    case _EntityKind.encounter:
      return [
        _FieldSpec(key: 'title', label: t.fieldTitle, initialValue: s('title')),
        _FieldSpec(
            key: 'practitioner_name',
            label: t.recordDoctor,
            initialValue: s('practitioner_name')),
        _FieldSpec(
            key: 'organization_name',
            label: t.clinicalHospitalClinic,
            initialValue: s('organization_name')),
        _FieldSpec(
          key: 'encounter_type',
          label: t.clinicalVisitType,
          initialValue: s('encounter_type'),
          options: const [
            'ambulatory',
            'emergency',
            'inpatient',
            'home-health',
            'virtual',
            'observation',
            'vaccination'
          ],
        ),
      ];
  }
}

Future<void> _showEditEntitySheet(
  BuildContext context,
  WidgetRef ref,
  String recordId,
  _EntityKind kind,
  Map<String, dynamic> item,
) async {
  final id = item['id'] as String;
  final t = ref.read(appLocalizationsProvider);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditEntitySheet(
      recordId: recordId,
      kind: kind,
      entityId: id,
      fields: _fieldsFor(t, kind, item),
    ),
  );
}

class _EditEntitySheet extends ConsumerStatefulWidget {
  const _EditEntitySheet({
    required this.recordId,
    required this.kind,
    required this.entityId,
    required this.fields,
  });
  final String recordId;
  final _EntityKind kind;
  final String entityId;
  final List<_FieldSpec> fields;

  @override
  ConsumerState<_EditEntitySheet> createState() => _EditEntitySheetState();
}

class _EditEntitySheetState extends ConsumerState<_EditEntitySheet> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields)
      if (f.options == null)
        f.key: TextEditingController(text: f.initialValue ?? ''),
  };
  late final Map<String, String?> _dropdownValues = {
    for (final f in widget.fields)
      if (f.options != null) f.key: f.initialValue,
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(appLocalizationsProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{};
      for (final f in widget.fields) {
        if (f.options != null) {
          body[f.key] = _dropdownValues[f.key];
        } else {
          final text = _controllers[f.key]!.text.trim();
          if (f.key == 'value_quantity') {
            body[f.key] = text.isEmpty ? null : double.tryParse(text);
          } else {
            body[f.key] = text.isEmpty ? null : text;
          }
        }
      }
      final api = ref.read(apiClientProvider);
      await api.patch('${_apiPathFor(widget.kind)}/${widget.entityId}',
          data: body);
      ref.invalidate(recordFullProvider(widget.recordId));
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final msg =
          (e.response?.data is Map ? e.response!.data['detail'] : null) ??
              t.errorSaveChangesFailed;
      if (mounted) {
        setState(() {
          _saving = false;
          _error = msg.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = t.errorSaveChangesFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(_sheetTitleFor(t, widget.kind),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(t.clinicalAiExtractedHint,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 18),
            for (final f in widget.fields) ...[
              Text(f.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              if (f.options != null)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _dropdownValues[f.key],
                      isExpanded: true,
                      hint: Text(t.commonNotSet,
                          style: TextStyle(color: AppTheme.textMuted)),
                      dropdownColor: AppTheme.surface,
                      style:
                          TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      items: f.options!
                          .map((o) => DropdownMenuItem<String?>(
                              value: o, child: Text(o)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _dropdownValues[f.key] = v),
                    ),
                  ),
                )
              else
                TextFormField(
                  controller: _controllers[f.key],
                  keyboardType: f.keyboardType,
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              const SizedBox(height: 14),
            ],
            if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(color: AppTheme.error, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(t.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(t.commonSaveChanges),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalBlock extends StatelessWidget {
  const _ClinicalBlock({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        _DetailCard(
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [
                  children[i],
                  if (i < children.length - 1) const _Divider(),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Clinical row widgets ───────────────────────────────────────────────────────

class _ObservationRow extends ConsumerWidget {
  const _ObservationRow(this.obs);
  final Map<String, dynamic> obs;

  Color get _interpColor {
    final interp = obs['interpretation'] as String? ?? '';
    if (['H', 'HH'].contains(interp)) return AppTheme.error;
    if (['L', 'LL'].contains(interp)) return AppTheme.info;
    if (interp == 'A' || interp == 'AA') return AppTheme.warning;
    return AppTheme.success;
  }

  String _interpLabel(AppLocalizations t) {
    switch (obs['interpretation']) {
      case 'N':
        return t.interpNormal;
      case 'L':
        return t.interpLow;
      case 'H':
        return t.interpHigh;
      case 'LL':
        return t.interpCriticalLow;
      case 'HH':
        return t.interpCriticalHigh;
      case 'A':
        return t.interpAbnormal;
      case 'AA':
        return t.interpVeryAbnormal;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final interpLabel = _interpLabel(t);
    final name = obs['observation_name'] as String? ?? ' - ';
    final qty = obs['value_quantity'];
    final unit = obs['value_unit'] as String? ?? '';
    final valueStr = obs['value_string'] as String?;
    final value = qty != null ? '$qty $unit'.trim() : (valueStr ?? ' - ');
    final refLow = obs['reference_range_low'];
    final refHigh = obs['reference_range_high'];
    final refRange = (refLow != null && refHigh != null)
        ? '$refLow–$refHigh $unit'.trim()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (refRange != null)
                  Text(t.clinicalRefRange(refRange),
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              if (interpLabel.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _interpColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(interpLabel,
                      style: TextStyle(
                          color: _interpColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConditionRow extends ConsumerWidget {
  const _ConditionRow(this.cond);
  final Map<String, dynamic> cond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final name = cond['condition_name'] as String? ?? ' - ';
    final status = cond['clinical_status'] as String? ?? '';
    final code = cond['icd11_code'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (code != null)
                  Text(t.recordDetailIcd11Code(code),
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          _StatusChip(
              label: status,
              color: status == 'active' ? AppTheme.error : AppTheme.success),
        ],
      ),
    );
  }
}

class _MedicationRow extends ConsumerWidget {
  const _MedicationRow(this.med);
  final Map<String, dynamic> med;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final name = med['medication_name_raw'] as String? ?? ' - ';
    final dosage = med['dosage_instruction'] as String?;
    final freq = med['dose_frequency'] as String?;
    final detail =
        [dosage, freq].where((s) => s != null && s.isNotEmpty).join(' · ');
    // Only true once the user has added this medication as an active reminder -
    // being mentioned in a document never makes it active on its own.
    final hasActiveReminder = med['has_active_reminder'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (detail.isNotEmpty)
                  Text(detail,
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (hasActiveReminder)
            _StatusChip(label: t.commonActive, color: AppTheme.success),
        ],
      ),
    );
  }
}

class _AllergyRow extends StatelessWidget {
  const _AllergyRow(this.allergy);
  final Map<String, dynamic> allergy;

  @override
  Widget build(BuildContext context) {
    final substance = allergy['substance_name'] as String? ?? ' - ';
    final criticality = allergy['criticality'] as String?;
    final reaction = allergy['reaction_description'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(substance,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (reaction != null && reaction.isNotEmpty)
                  Text(reaction,
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (criticality != null)
            _StatusChip(
              label: criticality,
              color: criticality == 'high' ? AppTheme.error : AppTheme.warning,
            ),
        ],
      ),
    );
  }
}

class _EncounterRow extends ConsumerWidget {
  const _EncounterRow(this.enc);
  final Map<String, dynamic> enc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final type = enc['encounter_type'] as String? ?? ' - ';
    final practitioner = enc['practitioner_name'] as String?;
    final org = enc['organization_name'] as String?;
    final dateRaw = enc['start_datetime'] as String?;
    final date = _formatDate(t, dateRaw);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_capitalise(type),
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (practitioner != null)
                  Text(t.clinicalDoctorPrefix(practitioner),
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                if (org != null)
                  Text(org,
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(date,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Type picker sheet ──────────────────────────────────────────────────────────

class _TypePickerSheet extends ConsumerWidget {
  const _TypePickerSheet({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(t.recordTypeSheetTitle,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
        ),
        const SizedBox(height: 8),
        ..._kRecordTypeIds.map((id) => ListTile(
              leading: Icon(_typeIcon(id),
                  color:
                      current == id ? AppTheme.primary : AppTheme.textSecondary),
              title: Text(_typeLabel(t, id),
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight:
                          current == id ? FontWeight.w600 : FontWeight.w400)),
              trailing: current == id
                  ? Icon(Icons.check, color: AppTheme.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(context, id),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Status helpers ─────────────────────────────────────────────────────────────

String _statusLabel(AppLocalizations t, String s) {
  switch (s) {
    case 'pending':
      return t.statusPending;
    case 'processing':
      return t.statusProcessing;
    case 'completed':
      return t.statusCompleted;
    case 'failed':
      return t.statusFailed;
    default:
      return s;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'completed':
      return Icons.check_circle_outline;
    case 'processing':
      return Icons.hourglass_top_outlined;
    case 'failed':
      return Icons.error_outline;
    default:
      return Icons.schedule_outlined;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'completed':
      return AppTheme.success;
    case 'processing':
      return AppTheme.info;
    case 'failed':
      return AppTheme.error;
    default:
      return AppTheme.textMuted;
  }
}
