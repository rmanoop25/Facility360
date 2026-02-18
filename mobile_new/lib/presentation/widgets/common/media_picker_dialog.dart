import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/enums/proof_type.dart';

/// Result from media picker containing file and its type
class MediaPickerResult {
  final File file;
  final ProofType type;

  const MediaPickerResult({
    required this.file,
    required this.type,
  });
}

/// Media picker dialog for selecting photos, videos, PDFs, or audio
///
/// Supports:
/// - Camera (photo/video)
/// - Gallery (photo/video)
/// - File picker (PDF/audio)
/// - Audio recorder
///
/// Returns [MediaPickerResult] with file and detected type
class MediaPickerDialog extends StatelessWidget {
  /// Whether to show video options (camera video, gallery video)
  final bool allowVideo;

  /// Whether to show audio options (audio file, record audio)
  final bool allowAudio;

  /// Whether to show PDF option
  final bool allowPdf;

  const MediaPickerDialog({
    super.key,
    this.allowVideo = true,
    this.allowAudio = true,
    this.allowPdf = true,
  });

  /// Show media picker dialog
  static Future<MediaPickerResult?> show(
    BuildContext context, {
    bool allowVideo = true,
    bool allowAudio = true,
    bool allowPdf = true,
  }) {
    return showModalBottomSheet<MediaPickerResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MediaPickerDialog(
        allowVideo: allowVideo,
        allowAudio: allowAudio,
        allowPdf: allowPdf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.bottomSheetRadius,
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: AppSpacing.horizontalLg,
            child: Text(
              'common.select_media'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // Options
          _PickerOption(
            icon: Icons.camera_alt_rounded,
            label: 'common.camera'.tr(),
            onTap: () => _pickFromCamera(context),
          ),
          _PickerOption(
            icon: Icons.photo_library_rounded,
            label: 'common.gallery'.tr(),
            onTap: () => _pickFromGallery(context),
          ),
          if (allowPdf)
            _PickerOption(
              icon: Icons.picture_as_pdf_rounded,
              label: 'common.pdf_file'.tr(),
              onTap: () => _pickPdf(context),
            ),
          if (allowAudio)
            _PickerOption(
              icon: Icons.audiotrack_rounded,
              label: 'common.audio_file'.tr(),
              onTap: () => _pickAudio(context),
            ),

          SizedBox(height: AppSpacing.sm),

          // Cancel button
          Padding(
            padding: AppSpacing.horizontalLg,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile != null && context.mounted) {
        final result = MediaPickerResult(
          file: File(pickedFile.path),
          type: ProofType.photo,
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.camera_failed'.tr())),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();

      // Show options for photo or video if video is allowed
      if (allowVideo) {
        final mediaType = await showDialog<ImageSource?>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('common.select_type'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_rounded),
                  title: Text('common.photo'.tr()),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: Text('common.video'.tr()),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );

        if (mediaType == null) return;

        if (mediaType == ImageSource.camera) {
          // Pick video
          final pickedFile = await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 5),
          );

          if (pickedFile != null && context.mounted) {
            final result = MediaPickerResult(
              file: File(pickedFile.path),
              type: ProofType.video,
            );
            Navigator.pop(context, result);
          }
        } else {
          // Pick image
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 70,
            maxWidth: 1920,
            maxHeight: 1080,
          );

          if (pickedFile != null && context.mounted) {
            final result = MediaPickerResult(
              file: File(pickedFile.path),
              type: ProofType.photo,
            );
            Navigator.pop(context, result);
          }
        }
      } else {
        // Only pick image
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1080,
        );

        if (pickedFile != null && context.mounted) {
          final result = MediaPickerResult(
            file: File(pickedFile.path),
            type: ProofType.photo,
          );
          Navigator.pop(context, result);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.gallery_failed'.tr())),
        );
      }
    }
  }

  Future<void> _pickPdf(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null && context.mounted) {
        final pickerResult = MediaPickerResult(
          file: File(result.files.single.path!),
          type: ProofType.pdf,
        );
        Navigator.pop(context, pickerResult);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.pdf_picker_failed'.tr())),
        );
      }
    }
  }

  Future<void> _pickAudio(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null && context.mounted) {
        final pickerResult = MediaPickerResult(
          file: File(result.files.single.path!),
          type: ProofType.audio,
        );
        Navigator.pop(context, pickerResult);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.audio_picker_failed'.tr())),
        );
      }
    }
  }

  Future<void> _recordAudio(BuildContext context) async {
    // TODO: Navigate to audio recorder screen
    // For now, show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('feature.coming_soon'.tr())),
    );
  }
}

/// Single picker option item
class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                icon,
                color: context.colors.primary,
                size: 24,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
