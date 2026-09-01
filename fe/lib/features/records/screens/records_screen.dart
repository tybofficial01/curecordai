import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/records_provider.dart';
import '../widgets/record_preview_sheet.dart';

List<String> _tabLabels(AppLocalizations t) => [
      t.recordsTabAll,
      t.recordsTabPrescriptions,
      t.recordsTabMedicalReports,
      t.recordsTabXRays,
      t.recordsTabLab,
      t.recordsTabOther,
    ];
const _kTabTypes = [
  'all',
  'prescription',
  'discharge_summary',
  'radiology',
  'lab_report',
  'other'
];

// Icon keys stored in backend and their Flutter equivalents
const _folderIcons = {
  'heart': Icons.favorite_outlined,
  'dental': Icons.medical_services_outlined,
  'eye': Icons.visibility_outlined,
  'medicine': Icons.medication_outlined,
  'folder': Icons.folder_outlined,
  'neurology': Icons.psychology_outlined,
  'orthopedics': Icons.accessibility_new_outlined,
};

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  String _selectedType = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Which tab buckets have at least one matching document - matches web's
  /// availableTypes filtering (only categories the user actually has
  /// documents in are shown, instead of a fixed always-on set).
  bool _bucketHasRecords(String bucket, List<Map<String, dynamic>> records) {
    if (bucket == 'all') return true;
    final presentTypes =
        records.map((r) => r['record_type'] as String? ?? 'other').toSet();
    switch (bucket) {
      case 'discharge_summary':
        return presentTypes.contains('discharge_summary') ||
            presentTypes.contains('referral');
      case 'other':
        return presentTypes.contains('vaccination') ||
            presentTypes.contains('insurance') ||
            presentTypes.contains('other');
      default:
        return presentTypes.contains(bucket);
    }
  }

  void _handlePolling(List<Map<String, dynamic>> records) {
    final hasProcessing =
        records.any((r) => r['processing_status'] == 'processing');
    if (hasProcessing && _pollingTimer == null) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        final data = ref.read(recordsListProvider).value;
        final stillProcessing =
            data?.any((r) => r['processing_status'] == 'processing') ?? false;
        if (stillProcessing) {
          // Bust the HTTP-level cache too - without this, ref.invalidate()
          // just re-triggers the same forceCache-served stale response for
          // up to its 5-minute maxStale window, so the list never sees the
          // record flip out of "processing".
          await ref.read(apiClientProvider).clearCachePath('/records');
          ref.invalidate(recordsListProvider);
        } else {
          _pollingTimer?.cancel();
          _pollingTimer = null;
        }
      });
    } else if (!hasProcessing) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  void _showCreateFolderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateFolderSheet(
        onCreated: () => ref.invalidate(foldersProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final tabs = _tabLabels(t);
    final foldersAsync = ref.watch(foldersProvider);
    final recordsAsync = ref.watch(recordsListProvider);
    final records = recordsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.appName),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/alerts'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: t.recordsSearchPlaceholder,
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _AddFolderChip(onTap: _showCreateFolderSheet),
                  ),
                  for (var i = 0; i < tabs.length; i++)
                    if (records == null ||
                        _bucketHasRecords(_kTabTypes[i], records))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: tabs[i],
                          selected: _selectedType == _kTabTypes[i],
                          onTap: () =>
                              setState(() => _selectedType = _kTabTypes[i]),
                        ),
                      ),
                  ...foldersAsync.maybeWhen(
                    data: (folders) => folders
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FolderChip(folder: f),
                            ))
                        .toList(),
                    orElse: () => const <Widget>[],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppTheme.cardBorder, height: 1),
          Expanded(
            child: _RecordsList(
              recordType: _selectedType,
              searchQuery: _searchQuery,
            ),
          ),
        ],
      ),
      // Right-aligned like the default endFloat spot, but raised enough to
      // clear the global AI floating button centered in the bottom nav bar.
      floatingActionButtonLocation: const _AboveAiEndFloatLocation(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/records/upload'),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Standard endFloat x-position, but raised an extra 40px so the button
// clears the global AI floating button in the bottom nav bar instead of
// sitting right next to it.
class _AboveAiEndFloatLocation extends FloatingActionButtonLocation {
  const _AboveAiEndFloatLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final endFloatOffset =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return Offset(endFloatOffset.dx, endFloatOffset.dy - 40);
  }
}

// ── Filter chips (record type + folders, in a single row) ───────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AddFolderChip extends ConsumerWidget {
  const _AddFolderChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(t.recordsFolder,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({required this.folder});
  final Map<String, dynamic> folder;

  IconData get _icon {
    final key = folder['icon'] as String? ?? '';
    return _folderIcons[key] ?? Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // No dedicated folder-detail view yet - jump straight to Upload with this
        // folder pre-selected so documents added from here land in the right place.
        context.push('/records/upload', extra: folder['id'] as String?);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 15, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              folder['name'] as String? ?? '',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create folder bottom sheet ─────────────────────────────────────────────────

class _CreateFolderSheet extends ConsumerStatefulWidget {
  const _CreateFolderSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends ConsumerState<_CreateFolderSheet> {
  final _nameController = TextEditingController();
  String _selectedIcon = 'heart';
  bool _isCreating = false;
  String? _error;

  static const _iconOptions = [
    ('dental', Icons.medical_services_outlined),
    ('eye', Icons.visibility_outlined),
    ('heart', Icons.favorite_outlined),
    ('medicine', Icons.medication_outlined),
    ('folder', Icons.folder_outlined),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final t = ref.read(appLocalizationsProvider);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t.recordsFolderNameRequired);
      return;
    }
    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      await createFolder(ref, name: name, icon: _selectedIcon);
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _error = t.recordsCreateFolderFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
          const SizedBox(height: 20),
          Text(t.recordsCreateNewFolder,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(t.recordsCreateFolderSubtitle,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Text(t.recordsFolderName,
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: t.recordsFolderNameHint,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: AppTheme.error, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          Text(t.recordsSelectIcon,
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _iconOptions.map((opt) {
              final isSelected = _selectedIcon == opt.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = opt.$1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color:
                          isSelected ? AppTheme.primary : AppTheme.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    opt.$2,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    size: 22,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _create,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(t.recordsCreateFolder),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.commonCancel,
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Records list ───────────────────────────────────────────────────────────────

class _RecordsList extends ConsumerWidget {
  const _RecordsList({required this.recordType, required this.searchQuery});
  final String recordType;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final recordsAsync = ref.watch(recordsListProvider);

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(t.recordsLoadFailed,
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => ref.refresh(recordsListProvider),
                child: Text(t.commonRetry)),
          ],
        ),
      ),
      data: (records) {
        // Kick off polling whenever processing records are present
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final state =
                context.findAncestorStateOfType<_RecordsScreenState>();
            state?._handlePolling(records);
          }
        });

        final query = searchQuery.trim().toLowerCase();
        final filtered = records.where((r) {
          final type = r['record_type'] as String? ?? '';
          final matchesType = switch (recordType) {
            'all' => true,
            'discharge_summary' =>
              type == 'discharge_summary' || type == 'referral',
            'other' =>
              type == 'vaccination' || type == 'insurance' || type == 'other',
            _ => type == recordType,
          };
          if (!matchesType) return false;
          if (query.isEmpty) return true;
          final title = (r['title'] as String? ?? '').toLowerCase();
          return title.contains(query);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyStateCard(
                icon: Icons.folder_open_outlined,
                tintBg: AppTheme.primary.withValues(alpha: 0.12),
                tintColor: AppTheme.primary,
                description: t.recordsEmptyDescription,
                actionLabel: t.homeUploadRecord,
                onAction: () => context.push('/records/upload'),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
          itemCount: filtered.length,
          itemBuilder: (_, index) => _RecordTile(record: filtered[index]),
        );
      },
    );
  }
}

// ── Record tile ────────────────────────────────────────────────────────────────

class _RecordTile extends ConsumerWidget {
  const _RecordTile({required this.record});
  final Map<String, dynamic> record;

  bool get _hasAnalysis => record['ai_analysis'] != null;
  bool get _isProcessing => record['processing_status'] == 'processing';

  String _formatDate(AppLocalizations t, String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${shortMonthName(t, dt.month)} '
          '${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final type = record['record_type'] as String? ?? 'other';
    final status = record['processing_status'] as String?;
    return GestureDetector(
      onTap: () => context.push('/records/${record['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(recordTypeIcon(type), color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record['title'] ?? t.recordsUntitled,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppFonts.isUrdu ? 6 : 3),
                  Text(
                    '${recordTypeLabel(t, type)} · ${recordStatusLabel(t, status)} · '
                    '${_formatDate(t, record['created_at'] as String?)}',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      if (_hasAnalysis) {
                        context.push('/records/${record['id']}/summary');
                      } else {
                        context.go('/ai');
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isProcessing)
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppTheme.primary),
                          )
                        else
                          Icon(Icons.auto_awesome,
                              color: AppTheme.primary, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          _isProcessing
                              ? t.recordsAnalysing
                              : _hasAnalysis
                                  ? t.recordsViewAiSummary
                                  : t.recordsExplainWithAi,
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _RecordMenu(record: record),
          ],
        ),
      ),
    );
  }
}

// ── Three-dot record menu ──────────────────────────────────────────────────────

class _RecordMenu extends ConsumerWidget {
  const _RecordMenu({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) async {
        if (value == 'view') {
          context.push('/records/${record['id']}');
        } else if (value == 'summary') {
          context.push('/records/${record['id']}/summary');
        } else if (value == 'chat') {
          context.go('/ai');
        } else if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: Text(t.recordsDeleteTitle,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              content: Text(
                t.recordsDeleteBody,
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
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          );
          if (confirmed == true) {
            try {
              final api = ref.read(apiClientProvider);
              final recordId = record['id'].toString();
              await api.delete('/records/$recordId');
              // Explicit delete - per the caching plan, evict its file-cache entry
              // now rather than waiting for the 7-day stale period to expire.
              await RecordFileCacheManager.instance.removeFile(recordId);
              await api.clearCachePath('/records');
              ref.invalidate(recordsListProvider);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.recordsDeleteFailed)),
                );
              }
            }
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'view',
            child: Row(children: [
              Icon(Icons.open_in_new, size: 16, color: AppTheme.textSecondary),
              SizedBox(width: 10),
              Text(t.recordsViewDetails,
                  style: TextStyle(color: AppTheme.textPrimary)),
            ])),
        if (record['ai_analysis'] != null)
          PopupMenuItem(
              value: 'summary',
              child: Row(children: [
                Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                SizedBox(width: 10),
                Text(t.recordsAiSummary,
                    style: TextStyle(color: AppTheme.textPrimary)),
              ])),
        PopupMenuItem(
            value: 'chat',
            child: Row(children: [
              Icon(Icons.chat_outlined,
                  size: 16, color: AppTheme.textSecondary),
              SizedBox(width: 10),
              Text(t.homeAskAi, style: TextStyle(color: AppTheme.textPrimary)),
            ])),
        PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
              SizedBox(width: 10),
              Text(t.commonDelete, style: TextStyle(color: AppTheme.error)),
            ])),
      ],
    );
  }
}
