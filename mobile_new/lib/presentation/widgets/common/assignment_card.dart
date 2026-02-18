import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/assignment_model.dart';
import '../../../domain/enums/assignment_status.dart';

/// A reusable card widget for displaying assignment information.
///
/// Used across tenant, admin, and service provider views.
/// Adapts display based on context (compact vs full, highlight for current user).
///
/// Example usage:
/// ```dart
/// AssignmentCard(assignment: assignment)
/// AssignmentCard(assignment: assignment, isCompact: true)
/// AssignmentCard(assignment: assignment, isHighlighted: true) // For SP's own assignment
/// ```
class AssignmentCard extends StatelessWidget {
  const AssignmentCard({
    super.key,
    required this.assignment,
    this.isCompact = false,
    this.isHighlighted = false,
    this.showWorkProgress = false,
    this.locale = 'en',
  });

  final AssignmentModel assignment;

  /// If true, shows a more compact version suitable for lists
  final bool isCompact;

  /// If true, adds a highlight border (for SP's own assignment)
  final bool isHighlighted;

  /// If true, shows work timestamps (started, finished, duration)
  final bool showWorkProgress;

  /// Locale for category names
  final String locale;

  Color _getStatusColor(BuildContext context, AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => context.colors.statusAssigned,
      AssignmentStatus.inProgress => context.colors.statusInProgress,
      AssignmentStatus.onHold => context.colors.warning,
      AssignmentStatus.finished => context.colors.info,
      AssignmentStatus.completed => context.colors.statusCompleted,
    };
  }

  Color _getStatusBgColor(BuildContext context, AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => context.colors.statusAssignedBg,
      AssignmentStatus.inProgress => context.colors.statusInProgressBg,
      AssignmentStatus.onHold => context.colors.warningBg,
      AssignmentStatus.finished => context.colors.infoBg,
      AssignmentStatus.completed => context.colors.statusCompletedBg,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = assignment.status;
    final statusColor = _getStatusColor(context, status);

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.allMd,
        border: isHighlighted
            ? Border.all(color: context.colors.primary, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Avatar, Name, Category, Status
          Row(
            children: [
              // Service provider avatar
              CircleAvatar(
                radius: isCompact ? 14 : 16,
                backgroundColor: context.colors.primary.withAlpha(26),
                child: Text(
                  (assignment.serviceProviderName ?? 'SP')[0].toUpperCase(),
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: isCompact ? 12 : 14,
                  ),
                ),
              ),
              AppSpacing.gapSm,

              // Name and category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.serviceProviderName ?? 'issue_detail.assignment_card.service_provider'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      assignment.getCategoryName(locale),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(context, status),
                  borderRadius: AppRadius.badgeRadius,
                ),
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),

          // Schedule info
          if (assignment.scheduledDate != null) ...[
            AppSpacing.vGapSm,
            Row(
              children: [
                Icon(
                  assignment.isMultiDay ? Icons.date_range_rounded : Icons.calendar_today,
                  size: 14,
                  color: context.colors.textTertiary,
                ),
                AppSpacing.gapXs,
                Text(
                  assignment.isMultiDay && assignment.scheduledDateRange != null
                      ? assignment.scheduledDateRange!
                      : '${assignment.scheduledDateFormatted}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
                if (assignment.isMultiDay) ...[
                  AppSpacing.gapXs,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.warningBg,
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Text(
                      '${assignment.spanDays} ${'common.days'.tr()}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.warning,
                            fontSize: 10,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            // Time slot info (multi-slot or single)
            if (assignment.hasMultipleSlots || assignment.assignedTimeRange != null) ...[
              AppSpacing.vGapXs,
              Row(
                children: [
                  Icon(
                    assignment.hasMultipleSlots
                        ? Icons.schedule_rounded
                        : Icons.access_time,
                    size: 14,
                    color: context.colors.textTertiary,
                  ),
                  AppSpacing.gapXs,
                  if (assignment.hasMultipleSlots) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withAlpha(26),
                        borderRadius: AppRadius.badgeRadius,
                      ),
                      child: Text(
                        '${assignment.timeSlotCount} ${'common.time_slots'.tr()}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ] else if (assignment.assignedTimeRange != null) ...[
                    Text(
                      assignment.assignedTimeRange!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ],

          // Work progress (if enabled and data available)
          if (showWorkProgress && assignment.startedAt != null) ...[
            AppSpacing.vGapSm,
            _buildWorkProgress(context),
          ],

          // Notes
          if (!isCompact &&
              assignment.notes != null &&
              assignment.notes!.isNotEmpty) ...[
            AppSpacing.vGapSm,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes,
                  size: 14,
                  color: context.colors.textTertiary,
                ),
                AppSpacing.gapXs,
                Expanded(
                  child: Text(
                    assignment.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkProgress(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        if (assignment.startedAt != null)
          _WorkInfoChip(
            icon: Icons.play_arrow,
            label: 'issue_detail.assignment_card.work_started'.tr(),
            value: _formatTime(assignment.startedAt!),
            color: context.colors.statusInProgress,
          ),
        if (assignment.finishedAt != null)
          _WorkInfoChip(
            icon: Icons.check_circle_outline,
            label: 'issue_detail.assignment_card.work_finished'.tr(),
            value: _formatTime(assignment.finishedAt!),
            color: context.colors.statusCompleted,
          ),
        if (assignment.workDuration != null)
          _WorkInfoChip(
            icon: Icons.timer_outlined,
            label: 'issue_detail.assignment_card.work_duration'.tr(),
            value: assignment.workDurationFormatted,
            color: context.colors.textSecondary,
          ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Small info chip for work progress details
class _WorkInfoChip extends StatelessWidget {
  const _WorkInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textSecondary,
              ),
        ),
      ],
    );
  }
}
