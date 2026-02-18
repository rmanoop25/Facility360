import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Audio player widget for playing audio files
///
/// Supports:
/// - Network audio (from URL)
/// - Local audio (from File)
/// - Play/pause controls
/// - Progress slider
/// - Duration display
class AudioPlayerWidget extends StatefulWidget {
  /// Network URL for audio (if loading from network)
  final String? networkUrl;

  /// Local file for audio (if loading from file system)
  final File? file;

  /// Title to show above player
  final String? title;

  /// Whether to show in compact mode (smaller UI)
  final bool compact;

  const AudioPlayerWidget.network({
    super.key,
    required this.networkUrl,
    this.title,
    this.compact = false,
  }) : file = null;

  const AudioPlayerWidget.file({
    super.key,
    required this.file,
    this.title,
    this.compact = false,
  }) : networkUrl = null;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = AudioPlayer();

    try {
      if (widget.networkUrl != null) {
        await _player.setUrl(widget.networkUrl!);
      } else if (widget.file != null) {
        await _player.setFilePath(widget.file!.path);
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isInitialized) {
      return _buildLoadingState(isDark);
    }

    if (_hasError) {
      return _buildErrorState(isDark);
    }

    return Container(
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          if (widget.title != null) ...[
            Row(
              children: [
                Icon(
                  Icons.audiotrack_rounded,
                  size: widget.compact ? 16 : 20,
                  color: (isDark ? AppColors.primaryDark : AppColors.primaryLight),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.title!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: widget.compact ? 13 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          ],

          // Controls row
          Row(
            children: [
              // Play/Pause button
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final processingState = playerState?.processingState;
                  final playing = playerState?.playing ?? false;

                  return IconButton(
                    icon: Icon(
                      playing
                          ? Icons.pause_rounded
                          : processingState == ProcessingState.loading ||
                                  processingState == ProcessingState.buffering
                              ? Icons.hourglass_empty_rounded
                              : Icons.play_arrow_rounded,
                      color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                    ),
                    iconSize: widget.compact ? 28 : 32,
                    onPressed: () {
                      if (playing) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                  );
                },
              ),

              // Progress slider
              Expanded(
                child: StreamBuilder<Duration?>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _player.duration ?? Duration.zero;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: widget.compact ? 2 : 3,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: widget.compact ? 6 : 8,
                            ),
                            overlayShape: RoundSliderOverlayShape(
                              overlayRadius: widget.compact ? 12 : 16,
                            ),
                          ),
                          child: Slider(
                            value: position.inSeconds.toDouble(),
                            max: duration.inSeconds.toDouble().clamp(1, double.infinity),
                            activeColor: isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight,
                            inactiveColor: (isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primaryLight)
                                .withOpacity(0.2),
                            onChanged: (value) {
                              _player.seek(Duration(seconds: value.toInt()));
                            },
                          ),
                        ),
                        if (!widget.compact)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Stop button
              if (!widget.compact)
                IconButton(
                  icon: const Icon(Icons.stop_rounded),
                  iconSize: 24,
                  onPressed: () {
                    _player.stop();
                    _player.seek(Duration.zero);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      padding: EdgeInsets.all(widget.compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      padding: EdgeInsets.all(widget.compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Colors.red.shade700.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: widget.compact ? 32 : 40,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'error.audio_load_failed'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Compact audio thumbnail for showing in lists
class AudioThumbnailWidget extends StatelessWidget {
  final String? title;
  final VoidCallback? onTap;

  const AudioThumbnailWidget({
    super.key,
    this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                Icons.audiotrack_rounded,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                size: 20,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? 'common.audio_file'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'common.media_mp3'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.play_circle_outline_rounded,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
          ],
        ),
      ),
    );
  }
}
