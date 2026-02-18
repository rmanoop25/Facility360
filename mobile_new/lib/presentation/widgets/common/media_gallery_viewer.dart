import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/media_model.dart';
import '../../../domain/enums/proof_type.dart';
import 'pdf_viewer_widget.dart';
import 'audio_player_widget.dart';
import 'video_player_widget.dart';

/// Full-screen media gallery viewer with swipe navigation
///
/// Supports viewing multiple media items (photos, videos, audio, PDFs) with left/right swipe navigation
class MediaGalleryViewer extends StatefulWidget {
  final List<MediaModel> mediaItems;
  final int initialIndex;

  const MediaGalleryViewer({
    super.key,
    required this.mediaItems,
    this.initialIndex = 0,
  });

  @override
  State<MediaGalleryViewer> createState() => _MediaGalleryViewerState();
}

class _MediaGalleryViewerState extends State<MediaGalleryViewer> {
  late int currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getMediaTypeLabel(MediaType type) {
    return switch (type) {
      MediaType.photo => 'common.media_photo'.tr(),
      MediaType.video => 'common.media_video'.tr(),
      MediaType.audio => 'common.media_audio'.tr(),
      MediaType.pdf => 'common.media_pdf_doc'.tr(),
    };
  }

  IconData _getMediaTypeIcon(MediaType type) {
    return switch (type) {
      MediaType.photo => Icons.photo_rounded,
      MediaType.video => Icons.videocam_rounded,
      MediaType.audio => Icons.mic_rounded,
      MediaType.pdf => Icons.picture_as_pdf_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentMedia = widget.mediaItems[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentIndex + 1} / ${widget.mediaItems.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _getMediaTypeLabel(currentMedia.type),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Media type indicator badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: AppRadius.badgeRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getMediaTypeIcon(currentMedia.type),
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  currentMedia.type.label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            itemCount: widget.mediaItems.length,
            itemBuilder: (context, index) {
              return _MediaViewer(media: widget.mediaItems[index]);
            },
          ),
          // Navigation hints (left/right arrows)
          if (widget.mediaItems.length > 1) ...[
            if (currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            if (currentIndex < widget.mediaItems.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
          ],
          // Page indicator dots at the bottom
          if (widget.mediaItems.length > 1)
            Positioned(
              bottom: AppSpacing.lg,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.mediaItems.length > 5 ? 5 : widget.mediaItems.length,
                      (index) {
                        // Show first 5 items as dots
                        if (widget.mediaItems.length <= 5) {
                          return _buildDot(index == currentIndex);
                        }
                        // For more than 5, show current position smartly
                        if (currentIndex < 3) {
                          return index < 4
                              ? _buildDot(index == currentIndex)
                              : _buildDot(false);
                        } else if (currentIndex >= widget.mediaItems.length - 2) {
                          return index == 0
                              ? _buildDot(false)
                              : _buildDot(index == 4 ? currentIndex == widget.mediaItems.length - 1 : index == 3 ? currentIndex == widget.mediaItems.length - 2 : false);
                        }
                        return _buildDot(index == 2);
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Single media viewer supporting photos, videos, audio, and PDFs
class _MediaViewer extends StatefulWidget {
  final MediaModel media;

  const _MediaViewer({required this.media});

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late TransformationController _controller;
  double _scale = 1.0;

  // Image retry state
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Key _imageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
    setState(() => _scale = 1.0);
  }

  /// Evict failed image from cache and schedule a retry after a short delay.
  /// Shows loading spinner in the meantime (like WhatsApp).
  void _scheduleRetry() {
    NetworkImage(widget.media.filePath).evict();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _retryCount++;
          _imageKey = UniqueKey();
        });
      }
    });
  }

  /// Manual retry triggered by the user — resets counter so auto-retries resume.
  void _manualRetry() {
    NetworkImage(widget.media.filePath).evict();
    setState(() {
      _retryCount = 0;
      _imageKey = UniqueKey();
    });
  }

  Widget _buildImageLoader() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildImageError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Colors.white.withOpacity(0.5),
            size: 64,
          ),
          AppSpacing.vGapMd,
          Text(
            'media.load_failed'.tr(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          AppSpacing.vGapMd,
          TextButton.icon(
            onPressed: _manualRetry,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            label: Text(
              'common.retry'.tr(),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Photos support zoom and double-tap
    if (widget.media.isPhoto) {
      return GestureDetector(
        onDoubleTap: () {
          if (_scale == 1.0) {
            // Zoom in
            _controller.value = Matrix4.identity()..scale(2.5);
            setState(() => _scale = 2.5);
          } else {
            // Zoom out
            _resetZoom();
          }
        },
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 0.8,
          maxScale: 3.0,
          onInteractionEnd: (_) {
            setState(() {
              _scale = _controller.value.getMaxScaleOnAxis();
            });
          },
          child: Center(
            child: Image.network(
              widget.media.filePath,
              key: _imageKey,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildImageLoader();
              },
              errorBuilder: (context, error, stackTrace) {
                if (_retryCount < _maxRetries) {
                  // Auto-retry: keep showing loader while scheduling retry
                  _scheduleRetry();
                  return _buildImageLoader();
                }
                // All retries exhausted — show error with manual retry button
                return _buildImageError();
              },
            ),
          ),
        ),
      );
    }

    // Video playback
    if (widget.media.isVideo) {
      return VideoPlayerWidget.network(
        networkUrl: widget.media.filePath,
        showControls: true,
      );
    }

    // Audio playback
    if (widget.media.type == MediaType.audio) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: AppRadius.cardRadius,
          ),
          child: AudioPlayerWidget.network(
            networkUrl: widget.media.filePath,
            title: 'audio.recording'.tr(),
          ),
        ),
      );
    }

    // PDF viewing
    if (widget.media.type == MediaType.pdf) {
      return PdfViewerWidget.network(
        networkUrl: widget.media.filePath,
        title: 'pdf.document'.tr(),
      );
    }

    // Fallback for unknown types
    return Center(
      child: Text(
        'media.unsupported_type'.tr(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
