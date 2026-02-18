import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/assignment_model.dart';

/// Time tracking card for in-progress assignments
/// Shows real-time elapsed time, progress bar, and overtime warnings
class TimeTrackingCard extends ConsumerStatefulWidget {
  final AssignmentModel assignment;
  final VoidCallback onRequestExtension;

  const TimeTrackingCard({
    super.key,
    required this.assignment,
    required this.onRequestExtension,
  });

  @override
  ConsumerState<TimeTrackingCard> createState() => _TimeTrackingCardState();
}

class _TimeTrackingCardState extends ConsumerState<TimeTrackingCard> {
  late DateTime _workStartTime;
  int _elapsedMinutes = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _workStartTime = widget.assignment.startedAt ?? DateTime.now();
    _updateElapsedTime();

    // Update every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _updateElapsedTime();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateElapsedTime() {
    if (mounted) {
      setState(() {
        _elapsedMinutes = DateTime.now().difference(_workStartTime).inMinutes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAllowed = widget.assignment.totalAllowedMinutes ?? 0;
    final progress = totalAllowed > 0 ? _elapsedMinutes / totalAllowed : 0.0;
    final overtime = _elapsedMinutes - totalAllowed;

    // Color coding
    Color progressColor;
    if (progress < 0.9) {
      progressColor = AppColors.success;
    } else if (progress < 1.0) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.error;
    }

    return Card(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: context.colors.primary),
                AppSpacing.gapSm,
                Text(
                  'assignment.time_tracking'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMd,

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'assignment.elapsed_time'.tr(),
                      style: context.textTheme.bodyMedium,
                    ),
                    Text(
                      '$_elapsedMinutes / $totalAllowed ${'common.min'.tr()}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
                AppSpacing.vGapSm,
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: context.colors.surface,
                  valueColor: AlwaysStoppedAnimation(progressColor),
                  minHeight: 8,
                  borderRadius: AppRadius.badgeRadius,
                ),
              ],
            ),

            AppSpacing.vGapMd,

            // Overtime indicator
            if (overtime > 0) ...[
              Container(
                padding: AppSpacing.allMd,
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(26),
                  borderRadius: AppRadius.inputRadius,
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 20),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'assignment.overtime_warning'.tr(
                          namedArgs: {'minutes': overtime.toString()},
                        ),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapMd,
            ],

            // Request extension button
            if (widget.assignment.canRequestExtension) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onRequestExtension,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text('extensions.request_extension'.tr()),
                ),
              ),
            ] else if (widget.assignment.hasPendingExtension) ...[
              Container(
                padding: AppSpacing.allMd,
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(26),
                  borderRadius: AppRadius.inputRadius,
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending_outlined,
                        color: AppColors.warning, size: 20),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'extensions.pending_request'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
