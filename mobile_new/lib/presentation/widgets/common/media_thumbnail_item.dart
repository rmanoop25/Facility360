import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/media_model.dart';

/// 100×100 media thumbnail with auto-retry for network photo images.
///
/// - Photo (local file): shows File image, error icon on failure
/// - Photo (network): spinning loader while loading; auto-retries up to 3×
///   on failure (WhatsApp-style); shows broken-image + refresh tap after that
/// - Video / Audio / PDF: static type-icon placeholder (no network load)
class MediaThumbnailItem extends StatefulWidget {
  final MediaModel media;
  final double size;

  const MediaThumbnailItem({
    super.key,
    required this.media,
    this.size = 100,
  });

  @override
  State<MediaThumbnailItem> createState() => _MediaThumbnailItemState();
}

class _MediaThumbnailItemState extends State<MediaThumbnailItem> {
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Key _imageKey = UniqueKey();

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

  void _manualRetry() {
    NetworkImage(widget.media.filePath).evict();
    setState(() {
      _retryCount = 0;
      _imageKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    if (widget.media.isPhoto) {
      final isLocalFile = widget.media.localPath != null ||
          widget.media.filePath.startsWith('/') ||
          widget.media.filePath.startsWith('file://');

      if (isLocalFile && widget.media.filePath.isNotEmpty) {
        return ClipRRect(
          borderRadius: AppRadius.thumbnailRadius,
          child: Image.file(
            File(widget.media.localPath ?? widget.media.filePath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildTypePlaceholder(context, Icons.image_rounded, 'IMG', size),
          ),
        );
      }

      // Network photo with auto-retry
      return ClipRRect(
        borderRadius: AppRadius.thumbnailRadius,
        child: Image.network(
          widget.media.filePath,
          key: _imageKey,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoader(context, size);
          },
          errorBuilder: (context, error, stackTrace) {
            if (_retryCount < _maxRetries) {
              _scheduleRetry();
              return _buildLoader(context, size);
            }
            return _buildRetryError(context, size);
          },
        ),
      );
    }

    // Non-photo: static icon placeholder
    final IconData icon;
    final String label;
    if (widget.media.isVideo) {
      icon = Icons.videocam_rounded;
      label = 'common.media_video'.tr();
    } else if (widget.media.type.name == 'audio') {
      icon = Icons.audio_file_rounded;
      label = 'common.media_audio'.tr();
    } else if (widget.media.type.name == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      label = 'common.media_pdf'.tr();
    } else {
      icon = Icons.attachment_rounded;
      label = 'common.media_file'.tr();
    }
    return _buildTypePlaceholder(context, icon, label, size);
  }

  Widget _buildLoader(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.thumbnailRadius,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.primary,
        ),
      ),
    );
  }

  Widget _buildRetryError(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.thumbnailRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 24,
            color: context.colors.textTertiary,
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _manualRetry,
            child: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePlaceholder(
    BuildContext context,
    IconData icon,
    String label,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.thumbnailRadius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 40, color: context.colors.textTertiary),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: AppRadius.badgeRadius,
              ),
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
