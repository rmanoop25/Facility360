import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notification_provider.dart';
import 'notification_sheet.dart';

/// Notification icon button with unread badge
/// Shows notification count badge and opens notifications dialog on tap
class NotificationIconButton extends ConsumerWidget {
  const NotificationIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 99 ? '99+' : unreadCount.toString(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        child: const Icon(Icons.notifications_rounded),
      ),
      onPressed: () => _showNotificationsDialog(context),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
      useSafeArea: false,
    );
  }
}
