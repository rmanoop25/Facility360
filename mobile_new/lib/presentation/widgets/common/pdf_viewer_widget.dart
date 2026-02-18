import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// PDF viewer widget for displaying PDF documents
///
/// Supports:
/// - Network PDFs (pre-downloaded via Dio to avoid byte-range issues with PHP dev server)
/// - Local PDFs (from File)
/// - Zoom, pan, page navigation
/// - Page counter
class PdfViewerWidget extends StatefulWidget {
  /// Network URL for PDF (if loading from network)
  final String? networkUrl;

  /// Local file for PDF (if loading from file system)
  final File? file;

  /// Title to show in app bar
  final String? title;

  const PdfViewerWidget.network({
    super.key,
    required this.networkUrl,
    this.title,
  }) : file = null;

  const PdfViewerWidget.file({
    super.key,
    required this.file,
    this.title,
  }) : networkUrl = null;

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _localPath;
  String? _downloadError;

  // Download auto-retry
  int _downloadRetryCount = 0;
  static const int _maxDownloadRetries = 3;

  // SfPdfViewer render retry (OS write-buffer race)
  int _sfRetryCount = 0;
  static const int _maxSfRetries = 5;

  @override
  void initState() {
    super.initState();
    if (widget.networkUrl != null) {
      _downloadPdf(widget.networkUrl!);
    } else {
      _isLoading = false;
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last.split('?').first;
      final file = File('${tempDir.path}/$fileName');

      // Use RandomAccessFile with explicit flush to ensure the OS write
      // buffers are committed before SfPdfViewer opens the file via JNI.
      // Without flush(), SfPdfViewer can race against the kernel page cache
      // and fail with onDocumentLoadFailed on the first attempt.
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.writeFrom(response.data!);
        await raf.flush();
      } finally {
        await raf.close();
      }

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _isLoading = false;
          _downloadRetryCount = 0;
        });
      }
    } catch (e) {
      debugPrint('PdfViewerWidget._downloadPdf error (attempt ${_downloadRetryCount + 1}): $e');
      if (_downloadRetryCount < _maxDownloadRetries) {
        _downloadRetryCount++;
        // Auto-retry after a short delay — keep spinner showing
        Future.delayed(Duration(milliseconds: 800 * _downloadRetryCount), () {
          if (mounted) _downloadPdf(url);
        });
      } else {
        if (mounted) {
          setState(() {
            _downloadError = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handleSfLoadFailed() {
    // Retry up to _maxSfRetries — SfPdfViewer failures are usually OS
    // write-buffer race conditions that resolve on retry.
    if (_sfRetryCount >= _maxSfRetries) {
      setState(() {
        _downloadError = 'SF render failed after $_maxSfRetries retries';
        _isLoading = false;
      });
      return;
    }
    _sfRetryCount++;
    setState(() {
      _localPath = null;
      _isLoading = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _downloadPdf(widget.networkUrl ?? '');
      }
    });
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title ?? 'pdf.document'.tr()),
        actions: [
          // Page counter
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer - uses pre-downloaded file for network URLs
          if (_downloadError != null)
            Center(
              child: Padding(
                padding: AppSpacing.allXl,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    AppSpacing.vGapLg,
                    Text(
                      'errors.load_failed'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (kDebugMode && _downloadError != null) ...[
                      AppSpacing.vGapSm,
                      Text(
                        _downloadError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    AppSpacing.vGapMd,
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _downloadError = null;
                          _localPath = null;
                          _downloadRetryCount = 0;
                          _sfRetryCount = 0;
                        });
                        _downloadPdf(widget.networkUrl!);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            )
          else if (_localPath != null)
            SfPdfViewer.file(
              File(_localPath!),
              controller: _pdfViewerController,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                setState(() {
                  _totalPages = details.document.pages.count;
                });
              },
              onPageChanged: (PdfPageChangedDetails details) {
                setState(() {
                  _currentPage = details.newPageNumber;
                });
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                _handleSfLoadFailed();
              },
            )
          else if (widget.file != null)
            SfPdfViewer.file(
              widget.file!,
              controller: _pdfViewerController,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                setState(() {
                  _totalPages = details.document.pages.count;
                  _isLoading = false;
                });
              },
              onPageChanged: (PdfPageChangedDetails details) {
                setState(() {
                  _currentPage = details.newPageNumber;
                });
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                setState(() {
                  _downloadError = details.error;
                  _isLoading = false;
                });
              },
            ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    AppSpacing.vGapMd,
                    Text(
                      _downloadRetryCount > 0
                          ? 'common.retrying'.tr()
                          : 'common.loading'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_downloadRetryCount > 0) ...[
                      AppSpacing.vGapXs,
                      Text(
                        '$_downloadRetryCount / $_maxDownloadRetries',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _totalPages > 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Previous page
                FloatingActionButton.small(
                  heroTag: 'pdf_prev',
                  onPressed: _currentPage > 1
                      ? () => _pdfViewerController.previousPage()
                      : null,
                  backgroundColor: _currentPage > 1
                      ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                      : Theme.of(context).cardColor,
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: _currentPage > 1
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                // Next page
                FloatingActionButton.small(
                  heroTag: 'pdf_next',
                  onPressed: _currentPage < _totalPages
                      ? () => _pdfViewerController.nextPage()
                      : null,
                  backgroundColor: _currentPage < _totalPages
                      ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                      : Theme.of(context).cardColor,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _currentPage < _totalPages
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// Simple PDF preview thumbnail widget
class PdfThumbnailWidget extends StatelessWidget {
  final String? networkUrl;
  final File? file;
  final double? width;
  final double? height;

  const PdfThumbnailWidget.network({
    super.key,
    required this.networkUrl,
    this.width,
    this.height,
  }) : file = null;

  const PdfThumbnailWidget.file({
    super.key,
    required this.file,
    this.width,
    this.height,
  }) : networkUrl = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 100,
      height: height ?? 120,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 40,
            color: Colors.red.shade700,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'common.media_pdf'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
