import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Audio recorder widget with waveform visualization
///
/// Features:
/// - Record audio with real-time waveform
/// - Play back recorded audio
/// - Duration counter
/// - Permission handling
class AudioRecorderWidget extends StatefulWidget {
  /// Callback when recording is complete
  final Function(File audioFile) onRecordingComplete;

  /// Maximum recording duration in seconds
  final int? maxDurationSeconds;

  const AudioRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.maxDurationSeconds = 300, // 5 minutes default
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  late RecorderController _recorderController;
  late PlayerController _playerController;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  bool _isInitialized = false;
  String? _recordedFilePath;
  int _recordedDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  Future<void> _initControllers() async {
    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;

    _playerController = PlayerController();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _recorderController.dispose();
    _playerController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Check microphone permission
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.microphone_permission_denied'.tr())),
        );
      }
      return;
    }

    try {
      // Generate temp file path
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordedFilePath = '${directory.path}/audio_$timestamp.m4a';

      await _recorderController.record(path: _recordedFilePath);

      setState(() {
        _isRecording = true;
        _hasRecording = false;
        _recordedDurationSeconds = 0;
      });

      // Start duration counter
      _startDurationCounter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.recording_failed'.tr())),
        );
      }
    }
  }

  void _startDurationCounter() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          _recordedDurationSeconds++;
        });

        // Stop if max duration reached
        if (widget.maxDurationSeconds != null &&
            _recordedDurationSeconds >= widget.maxDurationSeconds!) {
          _stopRecording();
        } else {
          _startDurationCounter();
        }
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      await _recorderController.stop();

      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });

      // Prepare player
      if (_recordedFilePath != null) {
        await _playerController.preparePlayer(
          path: _recordedFilePath!,
          shouldExtractWaveform: true,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.stop_recording_failed'.tr())),
        );
      }
    }
  }

  Future<void> _playRecording() async {
    try {
      if (_isPlaying) {
        await _playerController.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _playerController.startPlayer(finishMode: FinishMode.pause);
        setState(() {
          _isPlaying = true;
        });

        // Listen for completion
        _playerController.onCompletion.listen((_) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error.playback_failed'.tr())),
        );
      }
    }
  }

  void _deleteRecording() {
    setState(() {
      _hasRecording = false;
      _recordedDurationSeconds = 0;
      _recordedFilePath = null;
    });
  }

  void _saveRecording() {
    if (_recordedFilePath != null) {
      widget.onRecordingComplete(File(_recordedFilePath!));
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.mic_rounded,
                color: _isRecording
                    ? Colors.red
                    : (isDark ? AppColors.primaryDark : AppColors.primaryLight),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                _isRecording
                    ? 'common.recording'.tr()
                    : _hasRecording
                        ? 'common.recorded_audio'.tr()
                        : 'common.record_audio'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(_recordedDurationSeconds),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),

          // Waveform
          if (_isRecording)
            AudioWaveforms(
              size: Size(double.infinity, 80),
              recorderController: _recorderController,
              enableGesture: false,
              waveStyle: WaveStyle(
                waveColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            )
          else if (_hasRecording)
            AudioFileWaveforms(
              size: Size(double.infinity, 80),
              playerController: _playerController,
              enableSeekGesture: true,
              waveformType: WaveformType.fitWidth,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    .withOpacity(0.2),
                liveWaveColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                spacing: 6,
              ),
            )
          else
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    .withOpacity(0.05),
                borderRadius: AppRadius.cardAll,
              ),
              child: Center(
                child: Icon(
                  Icons.mic_none_rounded,
                  size: 40,
                  color: (isDark ? AppColors.textDark : AppColors.textLight)
                      .withOpacity(0.3),
                ),
              ),
            ),

          SizedBox(height: AppSpacing.lg),

          // Controls
          if (!_hasRecording)
            // Recording controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRecording)
                  ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic_rounded),
                    label: Text('common.start_recording'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text('common.stop_recording'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
              ],
            )
          else
            // Playback and save controls
            Row(
              children: [
                // Play/Pause button
                IconButton(
                  onPressed: _playRecording,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  iconSize: 32,
                  color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                ),
                SizedBox(width: AppSpacing.sm),

                // Delete button
                IconButton(
                  onPressed: _deleteRecording,
                  icon: const Icon(Icons.delete_rounded),
                  iconSize: 28,
                  color: Colors.red,
                ),

                const Spacer(),

                // Save button
                ElevatedButton.icon(
                  onPressed: _saveRecording,
                  icon: const Icon(Icons.check_rounded),
                  label: Text('common.save'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.primaryDark : AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
