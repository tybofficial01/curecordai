import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/cache/file_cache_manager.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Opens the original document (image or PDF) in a full-screen in-app modal instead of
/// handing off to an external browser/app - the document is fetched and rendered inline,
/// with pinch-to-zoom, so the user never leaves the app to look at their own record.
///
/// [recordId] is used as the on-disk cache key instead of [downloadUrl] - the URL is a
/// presigned S3 link that rotates on every fetch (15-min TTL), so caching by URL alone
/// would never hit. Caching by the stable record id means the file is only downloaded
/// once per 7-day cache window regardless of how many times a fresh presigned URL is
/// generated for it.
Future<void> showDocumentViewerModal(
  BuildContext context, {
  required String recordId,
  required String downloadUrl,
  required String mimeType,
  required String title,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black,
    builder: (_) => _DocumentViewerModal(
      recordId: recordId,
      downloadUrl: downloadUrl,
      mimeType: mimeType,
      title: title,
    ),
  );
}

class _DocumentViewerModal extends StatelessWidget {
  const _DocumentViewerModal({
    required this.recordId,
    required this.downloadUrl,
    required this.mimeType,
    required this.title,
  });

  final String recordId;
  final String downloadUrl;
  final String mimeType;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: mimeType == 'application/pdf'
                ? _PdfViewer(recordId: recordId, url: downloadUrl)
                : mimeType.startsWith('image/')
                    ? _ImageViewer(recordId: recordId, url: downloadUrl)
                    : const _UnsupportedPreview(),
          ),
        ],
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.recordId, required this.url});
  final String recordId;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: recordId,
          cacheManager: RecordFileCacheManager.instance,
          fit: BoxFit.contain,
          progressIndicatorBuilder: (context, url, progress) => Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          errorWidget: (_, __, ___) => const _LoadFailedMessage(),
        ),
      ),
    );
  }
}

class _PdfViewer extends StatefulWidget {
  const _PdfViewer({required this.recordId, required this.url});
  final String recordId;
  final String url;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  PdfControllerPinch? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final File file = await RecordFileCacheManager.instance
          .getSingleFile(widget.url, key: widget.recordId);
      // PdfControllerPinch takes the Future itself (it awaits internally) -
      // do not await this here.
      final document = PdfDocument.openFile(file.path);
      if (!mounted) return;
      setState(() => _controller = PdfControllerPinch(document: document));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _LoadFailedMessage();
    if (_controller == null) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    return PdfViewPinch(controller: _controller!);
  }
}

class _UnsupportedPreview extends ConsumerWidget {
  const _UnsupportedPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              t.viewerUnsupportedFileType,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailedMessage extends ConsumerWidget {
  const _LoadFailedMessage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              t.viewerLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
