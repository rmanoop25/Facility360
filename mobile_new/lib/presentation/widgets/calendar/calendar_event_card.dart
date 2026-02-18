import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/calendar_event_model.dart';

/// Event card widget for displaying issue details in calendar
///
/// Shows:
/// - Status color bar (left edge)
/// - Status badge
/// - Issue title
/// - Time slot or "All Day"
/// - Service provider name (for assignments)
/// - Tenant name + unit
/// - Tap to navigate to issue detail
class CalendarEventCard extends StatelessWidget {
  final CalendarEventModel event;

  const CalendarEventCard({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: InkWell(
        onTap: () {
          context.push(
            RoutePaths.adminIssueDetail.replaceFirst(':id', '${event.issueId}'),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.allMd,
          child: Row(
            children: [
              // Status color bar
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: _getStatusColor(context, event.status.value),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),

              SizedBox(width: AppSpacing.md),

              // Event content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending badge (if pending issue)
                    if (event.isPendingIssue) ...[
                      _buildPendingBadge(context),
                      SizedBox(height: AppSpacing.xs),
                    ],

                    // Title
                    Text(
                      event.title,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: AppSpacing.xs),

                    // Status badge
                    _buildStatusBadge(context),

                    SizedBox(height: AppSpacing.xs),

                    // Time slot or All Day
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: context.colors.textSecondary,
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          event.displayTime,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: AppSpacing.xs),

                    // Service provider (for assignments)
                    if (event.serviceProvider != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.engineering,
                            size: 14,
                            color: context.colors.textSecondary,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              event.serviceProvider!.name,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                    ],

                    // Tenant info
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: context.colors.textSecondary,
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '${event.tenant.name}${event.tenant.unit != null ? " • ${event.tenant.unit}" : ""}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron icon
              Icon(
                Icons.chevron_right,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build pending badge
  Widget _buildPendingBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.statusPendingBg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: context.colors.statusPending,
          width: 1,
        ),
      ),
      child: Text(
        'common.pending'.tr(),
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colors.statusPending,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _getStatusBgColor(context, event.status.value),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        event.status.label.toUpperCase(),
        style: context.textTheme.labelSmall?.copyWith(
          color: _getStatusColor(context, event.status.value),
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  /// Get status color using theme extension
  Color _getStatusColor(BuildContext context, String statusValue) {
    return switch (statusValue) {
      'pending' => context.colors.statusPending,
      'assigned' => context.colors.statusAssigned,
      'in_progress' => context.colors.statusInProgress,
      'on_hold' => context.colors.statusOnHold,
      'finished' => context.colors.statusFinished,
      'completed' => context.colors.statusCompleted,
      'cancelled' => context.colors.statusCancelled,
      _ => context.colors.textSecondary,
    };
  }

  /// Get status background color using theme extension
  Color _getStatusBgColor(BuildContext context, String statusValue) {
    return switch (statusValue) {
      'pending' => context.colors.statusPendingBg,
      'assigned' => context.colors.statusAssignedBg,
      'in_progress' => context.colors.statusInProgressBg,
      'on_hold' => context.colors.statusOnHoldBg,
      'finished' => context.colors.statusFinishedBg,
      'completed' => context.colors.statusCompletedBg,
      'cancelled' => context.colors.statusCancelledBg,
      _ => context.colors.surfaceVariant,
    };
  }
}
