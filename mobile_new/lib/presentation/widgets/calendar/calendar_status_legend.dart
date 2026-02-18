import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';

/// Horizontal scrollable legend showing all status colors
///
/// Displays color chips with labels for:
/// - Pending, Assigned, In Progress, On Hold, Finished, Completed, Cancelled
class CalendarStatusLegend extends StatelessWidget {
  const CalendarStatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          _buildStatusChip(context, 'status.pending'.tr(), context.colors.statusPending),
          _buildStatusChip(context, 'status.assigned'.tr(), context.colors.statusAssigned),
          _buildStatusChip(context, 'status.in_progress'.tr(), context.colors.statusInProgress),
          _buildStatusChip(context, 'status.on_hold'.tr(), context.colors.statusOnHold),
          _buildStatusChip(context, 'status.finished'.tr(), context.colors.statusFinished),
          _buildStatusChip(context, 'status.completed'.tr(), context.colors.statusCompleted),
          _buildStatusChip(context, 'status.cancelled'.tr(), context.colors.statusCancelled),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, Color color) {
    return Container(
      margin: EdgeInsets.only(right: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
