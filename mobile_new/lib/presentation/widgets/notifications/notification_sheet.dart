import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import 'notification_list_item.dart';

/// Show notification sheet
void showNotificationSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _NotificationSheetContent(),
  );
}

/// Notification sheet content with draggable scrollable sheet
class _NotificationSheetContent extends ConsumerWidget {
  const _NotificationSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationListProvider);
    final notifications = notificationState.notifications;
    final hasUnread = notificationState.unreadCount > 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: AppRadius.allFull,
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      'notifications.title'.tr(),
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (hasUnread)
                      TextButton(
                        onPressed: () {
                          ref
                              .read(notificationListProvider.notifier)
                              .markAllAsRead();
                        },
                        child: Text('notifications.mark_all_read'.tr()),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Notification list
              Expanded(
                child: notificationState.isInitialLoading
                    ? const Center(child: CircularProgressIndicator())
                    : notifications.isEmpty
                    ? _EmptyNotifications()
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return NotificationListItem(
                            notification: notification,
                            onTap: () {
                              // Mark as read
                              ref
                                  .read(notificationListProvider.notifier)
                                  .markAsRead(notification.id);

                              // Close sheet
                              Navigator.pop(context);

                              // Navigate if issue ID exists
                              if (notification.issueId != null) {
                                _navigateToIssue(
                                  context,
                                  ref,
                                  notification.issueId!,
                                  assignmentId: notification.assignmentId,
                                );
                              }
                            },
                            onDismissed: () {
                              ref
                                  .read(notificationListProvider.notifier)
                                  .deleteNotification(notification.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Navigate to issue/assignment based on user role
  void _navigateToIssue(BuildContext context, WidgetRef ref, int issueId, {int? assignmentId}) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    String route;
    switch (user.role.name) {
      case 'tenant':
        route = '/tenant/issues/$issueId';
        break;
      case 'service_provider':
        // Use assignment ID if available, otherwise fall back to issue ID
        final id = assignmentId ?? issueId;
        route = '/sp/assignments/$id';
        break;
      case 'super_admin':
      case 'manager':
      case 'viewer':
        route = '/admin/issues/$issueId';
        break;
      default:
        // Default to admin route (safest fallback)
        route = '/admin/issues/$issueId';
    }

    context.push(route);
  }
}

/// Empty state for notifications
class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.allXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/empty_notifications.json',
              width: 280,
              height: 280,
              fit: BoxFit.contain,
              repeat: false,
            ),
            AppSpacing.vGapLg,
            Text(
              'notifications.empty_title'.tr(),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              'notifications.empty_description'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen notifications dialog
class NotificationsDialog extends ConsumerWidget {
  const NotificationsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationListProvider);
    final notifications = notificationState.notifications;
    final hasUnread = notificationState.unreadCount > 0;

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: Text('notifications.title'.tr()),
          elevation: 0,
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
          actions: [
            if (hasUnread)
              TextButton(
                onPressed: () {
                  ref.read(notificationListProvider.notifier).markAllAsRead();
                },
                child: Text(
                  'notifications.mark_all_read'.tr(),
                  style: TextStyle(color: context.colors.primary),
                ),
              ),
          ],
        ),
        body: notificationState.isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
            ? _EmptyNotifications()
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(notificationListProvider.notifier).refresh(),
                child: ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return NotificationListItem(
                      notification: notification,
                      onTap: () {
                        // Mark as read
                        ref
                            .read(notificationListProvider.notifier)
                            .markAsRead(notification.id);

                        // Close dialog
                        Navigator.pop(context);

                        // Navigate if issue ID exists
                        if (notification.issueId != null) {
                          _navigateToIssue(
                            context,
                            ref,
                            notification.issueId!,
                            assignmentId: notification.assignmentId,
                          );
                        }
                      },
                      onDismissed: () {
                        ref
                            .read(notificationListProvider.notifier)
                            .deleteNotification(notification.id);
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  /// Navigate to issue/assignment based on user role
  void _navigateToIssue(BuildContext context, WidgetRef ref, int issueId, {int? assignmentId}) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    String route;
    switch (user.role.name) {
      case 'tenant':
        route = '/tenant/issues/$issueId';
        break;
      case 'service_provider':
        // Use assignment ID if available, otherwise fall back to issue ID
        final id = assignmentId ?? issueId;
        route = '/sp/assignments/$id';
        break;
      case 'super_admin':
      case 'manager':
      case 'viewer':
        route = '/admin/issues/$issueId';
        break;
      default:
        // Default to admin route (safest fallback)
        route = '/admin/issues/$issueId';
    }

    context.push(route);
  }
}
