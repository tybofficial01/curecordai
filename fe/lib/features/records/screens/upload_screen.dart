import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../home/screens/home_screen.dart';
import '../providers/records_provider.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key, this.initialFolderId});

  /// Set when opened from a specific folder card on the Records screen - pre-selects that
  /// folder so documents added from there land in the right place without an extra tap.
  final String? initialFolderId;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  Uint8List? _fileBytes;
  String? _fileName;
  int? _fileSize;
  String? _fileMimeType;
  String? _selectedFolderId;
  bool _isUploading = false;
  bool _isVerifying = false;
  double _uploadProgress = 0;
  String _uploadStage = '';
  String? _error;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
  }

  // Matches web's ALLOWED_MIME_TYPES (web/app/dashboard/upload/page.tsx) -
  // PDF, JPG, PNG, WebP, and DICOM.
  static const _mimeTypes = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'dcm': 'application/dicom',
  };
  static const _kMaxFileSizeBytes = 50 * 1024 * 1024;

  String? _getMimeType(String ext) => _mimeTypes[ext.toLowerCase()];

  void _setFile({
    required String name,
    required int size,
    required String ext,
    required Uint8List bytes,
  }) {
    setState(() {
      _fileName = name;
      _fileSize = size;
      _fileBytes = bytes;
      _fileMimeType = _getMimeType(ext);
      _error = null;
    });
  }

  Future<void> _pickFromGallery() async {
    if (_isUploading) return;
    final t = ref.read(appLocalizationsProvider);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'dcm'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.size > _kMaxFileSizeBytes) {
        setState(() => _error = t.uploadFileTooLarge);
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _error = t.uploadFileReadFailed);
        return;
      }
      if (_getMimeType(file.extension ?? '') == null) {
        setState(() => _error = t.uploadUnsupportedType);
        return;
      }
      _setFile(
          name: file.name,
          size: file.size,
          ext: file.extension ?? '',
          bytes: bytes);
    } catch (_) {
      setState(() => _error = t.uploadFilePickerFailed);
    }
  }

  Future<void> _pickFromCamera() async {
    if (_isUploading) return;
    final t = ref.read(appLocalizationsProvider);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      if (bytes.length > _kMaxFileSizeBytes) {
        setState(() => _error = t.uploadImageTooLarge);
        return;
      }
      final ext = xfile.path.split('.').last.toLowerCase();
      final name = xfile.name.isNotEmpty ? xfile.name : 'photo.jpg';
      _setFile(name: name, size: bytes.length, ext: ext, bytes: bytes);
    } catch (_) {
      setState(() => _error = t.uploadCameraFailed);
    }
  }

  // How long the post-confirm poll waits between checks, and how many times -
  // matches web's DOCUMENT_CHECK_POLL_INTERVAL_MS / DOCUMENT_CHECK_MAX_ATTEMPTS
  // (web/app/dashboard/upload/page.tsx), which cover both the "not a medical
  // document" and "patient name mismatch" AI checks - both only resolve once
  // the pipeline reaches a final processing_status.
  static const _pollInterval = Duration(milliseconds: 1500);
  static const _maxPollAttempts = 30;

  void _cancelUpload() {
    _cancelToken?.cancel();
  }

  Future<void> _upload() async {
    final t = ref.read(appLocalizationsProvider);
    final bytes = _fileBytes;
    final name = _fileName;
    final size = _fileSize;
    if (bytes == null || name == null || size == null) {
      setState(() => _error = t.uploadSelectFileFirst);
      return;
    }

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    String? recordId;
    final api = ref.read(apiClientProvider);

    setState(() {
      _isUploading = true;
      _isVerifying = false;
      _uploadProgress = 0;
      _uploadStage = t.uploadStagePreparing;
      _error = null;
    });

    try {
      final mimeType = _fileMimeType ?? 'application/octet-stream';
      final memberId = ref.read(activeMemberIdProvider);
      final fileHash = sha256.convert(bytes).toString();

      // ── Step 1: Init - AI will auto-detect title & type ───────────────────
      final initResponse = await api.post(
        '/records/upload/init',
        data: {
          'title': 'Untitled',
          'record_type': 'other',
          'file_name': name,
          'file_mime_type': mimeType,
          'file_size_bytes': size,
          if (_selectedFolderId != null) 'folder_id': _selectedFolderId,
          if (memberId != null) 'family_member_id': memberId,
        },
        cancelToken: cancelToken,
      );

      recordId = initResponse.data['record_id'] as String;
      final uploadUrl = initResponse.data['upload_url'] as String;
      final uploadFields =
          Map<String, String>.from(initResponse.data['upload_fields'] as Map);

      // ── Step 2: POST directly to S3 (presigned POST, not PUT) ─────────────
      // S3 enforces the content-length-range policy condition baked into uploadFields -
      // it rejects the upload outright if the actual bytes exceed the server's size limit,
      // unlike a plain PUT URL which carried no server-verified size enforcement at all.
      if (mounted) setState(() => _uploadStage = t.uploadStageUploading);

      final s3Dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 2),
      ));

      // S3 requires every policy field before "file", and "file" must be the last field -
      // Dio's FormData.finalize() always serializes fields before files regardless of add
      // order, so this ordering is safe by construction, not by coincidence.
      final formData = FormData()
        ..fields.addAll(uploadFields.entries)
        ..files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(bytes, filename: name),
        ));

      await s3Dio.post<void>(
        uploadUrl,
        data: formData,
        cancelToken: cancelToken,
        options: Options(validateStatus: (s) => s != null && s < 400),
        onSendProgress: (sent, total) {
          final totalBytes = total > 0 ? total : size;
          if (mounted) {
            setState(() => _uploadProgress = (sent / totalBytes) * 0.7);
          }
        },
      );

      // ── Step 3: Confirm - triggers AI extraction + analysis pipeline ───────
      // Sending the client-computed hash lets the backend reject an exact
      // duplicate of an already-uploaded document with a 409, handled below.
      if (mounted) {
        setState(() {
          _uploadStage = t.uploadStageAnalysing;
          _uploadProgress = 0.75;
        });
      }
      await api.post(
        '/records/$recordId/upload/confirm',
        data: {
          'file_hash': fileHash,
          if (memberId != null) 'family_member_id': memberId,
        },
        cancelToken: cancelToken,
      );

      // ── Step 4: Poll until the AI pipeline reaches a final status ─────────
      // Without this, a document the AI later flags as "not a medical
      // document" or "wrong patient" would already have been shown to the
      // user as a successful upload by the time either check resolves.
      if (mounted) setState(() => _isVerifying = true);
      String finalStatus = 'processing';
      String? processingError;
      for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
        await Future.delayed(_pollInterval);
        if (!mounted) return;
        // No explicit isCancelled check needed here - the api.get call below
        // throws a DioExceptionType.cancel as soon as it starts if the token
        // was cancelled during the delay, routing through the same cleanup
        // path as every other cancellation point.
        final recordResponse = await api.get(
          '/records/$recordId',
          cancelToken: cancelToken,
        );
        final status = recordResponse.data['processing_status'] as String;
        if (status == 'completed' || status == 'failed') {
          finalStatus = status;
          processingError = recordResponse.data['processing_error'] as String?;
          break;
        }
      }

      if (!mounted) return;

      if (finalStatus == 'failed') {
        // Best-effort cleanup so a rejected document doesn't leave a ghost
        // record in the vault - mirrors web's deleteRecord on this path.
        try {
          await api.delete('/records/$recordId');
        } catch (_) {
          // Nothing more useful to do - the record just stays as "failed"
          // and the user can delete it manually from the vault later.
        }
        await api.clearCachePath('/records');
        ref.invalidate(recordsListProvider);
        ref.invalidate(recentRecordsProvider);
        setState(() {
          _isUploading = false;
          _isVerifying = false;
          _fileBytes = null;
          _fileName = null;
          _fileSize = null;
          _fileMimeType = null;
        });
        if (mounted) {
          _showRejectionDialog(processingError ?? t.uploadCouldNotVerify);
        }
        return;
      }

      setState(() => _uploadProgress = 1.0);

      // Per the security/caching rule: a successful upload clears the health
      // vault's forceCache entries immediately so the record list and folders
      // reflect the new document on the very next fetch instead of serving a
      // still-live cached response for up to 5 more minutes.
      await api.clearCachePath('/records');
      ref.invalidate(recordsListProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(recentRecordsProvider);

      // Land on the new record itself (it shows a live "processing" state and
      // polls until the AI pipeline finishes, if it's not "completed" yet)
      // instead of just popping back to wherever the user came from with no
      // visible confirmation.
      if (mounted) context.pushReplacement('/records/$recordId');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // User cancelled - best-effort cleanup of the pending record row,
        // no error message shown, matching web's silent AbortError handling.
        if (recordId != null) {
          try {
            await api.delete('/records/$recordId');
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _isUploading = false;
            _isVerifying = false;
          });
        }
        return;
      }
      if (e.response?.statusCode == 409) {
        if (recordId != null) {
          try {
            await api.delete('/records/$recordId');
          } catch (_) {}
        }
        if (mounted) setState(() => _error = t.uploadDuplicateMessage);
      } else {
        if (recordId != null) {
          try {
            await api.delete('/records/$recordId');
          } catch (_) {}
        }
        final detail = e.response?.data is Map
            ? ((e.response!.data as Map)['detail'] ?? t.uploadFailedShort)
            : t.uploadFailedConnection;
        if (mounted) setState(() => _error = detail.toString());
      }
    } catch (_) {
      if (recordId != null) {
        try {
          await api.delete('/records/$recordId');
        } catch (_) {}
      }
      if (mounted) setState(() => _error = t.uploadFailedRetry);
    } finally {
      _cancelToken = null;
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _showRejectionDialog(String reason) async {
    final t = ref.read(appLocalizationsProvider);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.uploadRejectedTitle,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.uploadRejectedBody,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(reason,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(t.uploadTryAgain),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final foldersAsync = ref.watch(foldersProvider);
    final profile = ref.watch(activeProfileProvider);
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    if (!isOnline) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(t.uploadTitle),
          backgroundColor: AppTheme.background,
        ),
        body: OfflineBlockedNotice(
          message: t.uploadOfflineNotice,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(profile.isOwnerMode
            ? t.uploadTitle
            : t.uploadTitleForMember(profile.displayName)),
        backgroundColor: AppTheme.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.isOwnerMode
                  ? t.uploadSubtitle
                  : t.uploadSubtitleForMember(profile.displayName),
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),

            // ── Upload zone ───────────────────────────────────────────────────
            GestureDetector(
              onTap: _isUploading ? null : _pickFromGallery,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _fileBytes != null
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.4),
                    width: 1.5,
                    // dashed look via a custom painter would be ideal, but
                    // solid teal border with low opacity matches the design closely enough
                  ),
                ),
                child: _fileBytes != null
                    ? _FileSelectedContent(name: _fileName!, size: _fileSize!)
                    : const _UploadPlaceholder(),
              ),
            ),
            const SizedBox(height: 14),

            // ── Camera / Gallery buttons ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: t.uploadCamera,
                    onTap: _isUploading ? null : _pickFromCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_library_outlined,
                    label: t.uploadGallery,
                    onTap: _isUploading ? null : _pickFromGallery,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Folder selector ───────────────────────────────────────────────
            Text(
              t.uploadSelectFolder,
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            foldersAsync.when(
              loading: () => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (folders) => Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedFolderId,
                    isExpanded: true,
                    hint: Text(t.uploadGeneralRecords,
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(t.uploadGeneralRecords,
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      ...folders.map((f) => DropdownMenuItem<String?>(
                            value: f['id'] as String,
                            child: Text(f['name'] as String? ?? '',
                                style: TextStyle(color: AppTheme.textPrimary)),
                          )),
                    ],
                    onChanged: _isUploading
                        ? null
                        : (v) => setState(() => _selectedFolderId = v),
                  ),
                ),
              ),
            ),

            // ── Error ─────────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: AppTheme.error, fontSize: 13))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Progress ──────────────────────────────────────────────────────
            if (_isUploading) ...[
              Row(
                children: [
                  Expanded(
                      child: Text(_uploadStage,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13))),
                  if (!_isVerifying)
                    Text(
                      '${(_uploadProgress * 100).round()}%',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  // Indeterminate while waiting on the AI verification poll -
                  // there's no meaningful percentage for that phase.
                  value: _isVerifying
                      ? null
                      : (_uploadProgress > 0 ? _uploadProgress : null),
                  backgroundColor: AppTheme.cardBorder,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _cancelUpload,
                  child: Text(t.uploadCancel,
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Upload button ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 10),
                          Text(t.uploadProcessing,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.upload_outlined,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(t.homeUploadDocument,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Privacy note ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppTheme.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.uploadPrivacyFirst,
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(t.uploadPrivacyNote,
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadPlaceholder extends ConsumerWidget {
  const _UploadPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          color: AppTheme.primary.withValues(alpha: 0.7),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          t.uploadTakePhotoOrChooseFile,
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          t.uploadFileTypesHint,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _FileSelectedContent extends StatelessWidget {
  const _FileSelectedContent({required this.name, required this.size});
  final String name;
  final int size;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: AppTheme.success, size: 40),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            name,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatSize(size),
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
