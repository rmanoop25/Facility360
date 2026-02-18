import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../domain/entities/notification_entity.dart';

/// Notification list item widget
/// Displays a single notification with swipe-to-delete support
class NotificationListItem extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const NotificationListItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  /// Get icon based on notification type
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'issue_assigned':
        return Icons.assignment_ind;
      case 'issue_completed':
        return Icons.check_circle;
      case 'work_started':
        return Icons.engineering;
      case 'work_finished':
        return Icons.flag;
      case 'issue_cancelled':
        return Icons.cancel;
      case 'new_issue':
        return Icons.report_problem;
      default:
        return Icons.notifications;
    }
  }

  /// Get relative time string
  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'common.just_now'.tr();
    } else if (difference.inMinutes < 60) {
      return 'time_format.minutes_ago'.tr(
        namedArgs: {'count': difference.inMinutes.toString()},
      );
    } else if (difference.inHours < 24) {
      return 'time_format.hours_ago'.tr(
        namedArgs: {'count': difference.inHours.toString()},
      );
    } else {
      return 'time_format.days_ago'.tr(
        namedArgs: {'count': difference.inDays.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        color: context.colors.error,
        child: Icon(Icons.delete_outline, color: context.colors.onPrimary),
      ),
      child: Material(
        color: notification.isRead
            ? context.colors.surface
            : context.colors.primary.withOpacity(0.05),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.colors.surfaceVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unread indicator
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),

                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceVariant,
                    borderRadius: AppRadius.allMd,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    size: 20,
                    color: context.colors.textSecondary,
                  ),
                ),

                AppSpacing.gapMd,

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRelativeTime(notification.receivedAt),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension to handle notification tap navigation
extension NotificationNavigation on NotificationEntity {
  /// Navigate to relevant screen based on notification data
  /// NOTE: This extension is not used anymore. Use _navigateToIssue in
  /// notification_sheet.dart instead, which properly handles role-based routing.
  void navigateToContent(BuildContext context) {
    if (issueId != null) {
      // Navigate to issue detail - uses role-based routing
      // Note: This should not be called directly - use notification_sheet.dart instead
      context.push('/issues/$issueId');
    }
  }
}
