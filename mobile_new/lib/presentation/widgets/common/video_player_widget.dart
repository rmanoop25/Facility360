import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_spacing.dart';

/// Video player widget for playing video files
///
/// Supports:
/// - Network videos (from URL)
/// - Local videos (from File)
/// - Play/pause controls
/// - Seek/progress bar
/// - Duration display
class VideoPlayerWidget extends StatefulWidget {
  /// Network URL for video (if loading from network)
  final String? networkUrl;

  /// Local file for video (if loading from file system)
  final File? file;

  /// Title to show above player
  final String? title;

  /// Whether to show overlay controls
  final bool showControls;

  const VideoPlayerWidget.network({
    super.key,
    required this.networkUrl,
    this.title,
    this.showControls = true,
  }) : file = null;

  const VideoPlayerWidget.file({
    super.key,
    required this.file,
    this.title,
    this.showControls = true,
  }) : networkUrl = null;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.networkUrl != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.networkUrl!),
        );
      } else if (widget.file != null) {
        _controller = VideoPlayerController.file(widget.file!);
      } else {
        throw Exception('Either networkUrl or file must be provided');
      }

      await _controller.initialize();
      _controller.setLooping(false);

      // Listen for playback changes
      _controller.addListener(() {
        if (_controller.value.hasError) {
          setState(() {
            _hasError = true;
            _errorMessage = _controller.value.errorDescription ?? 'Unknown error';
            _isInitialized = true;
          });
        }
        if (mounted) {
          setState(() {});
        }
      });

      setState(() {
        _isInitialized = true;
      });
    } on PlatformException {
      setState(() {
        _hasError = true;
        _errorMessage = 'video_player.cannot_play'.tr();
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        color: Colors.black,
        padding: AppSpacing.allXxl,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.7),
              ),
              AppSpacing.vGapLg,
              Text(
                'video_player.cannot_play'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.vGapMd,
              Text(
                _errorMessage ?? 'video_player.unknown_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              AppSpacing.vGapXl,
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isInitialized = false;
                    _hasError = false;
                    _errorMessage = null;
                  });
                  _initPlayer();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text('common.retry'.tr()),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.showControls ? _toggleControls : null,
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video player
                VideoPlayer(_controller),

                // Controls overlay
                if (widget.showControls && _showControls)
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _buildControls(),
                  ),

                // Play/pause button (center)
                if (widget.showControls && _showControls)
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 48,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top bar with title
          if (widget.title != null)
            Container(
              padding: AppSpacing.allMd,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Bottom bar with progress and controls
          Container(
            padding: AppSpacing.allMd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: position.inMilliseconds.toDouble(),
                        min: 0.0,
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          _controller.seekTo(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
