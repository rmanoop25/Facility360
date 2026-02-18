import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/notification_local_datasource.dart';
import '../../domain/entities/notification_entity.dart';

// ============================================================================
// NOTIFICATION LIST STATE & PROVIDER
// ============================================================================

/// State for notification list
class NotificationListState {
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationListState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationListState copyWith({
    List<NotificationEntity>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Check if list is empty
  bool get isEmpty => notifications.isEmpty && !isLoading;

  /// Check if initial load is in progress
  bool get isInitialLoading => isLoading && notifications.isEmpty;

  /// Get unread notifications
  List<NotificationEntity> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();
}

/// Notification list notifier
class NotificationListNotifier extends StateNotifier<NotificationListState> {
  final NotificationLocalDataSource _dataSource;

  NotificationListNotifier(this._dataSource)
    : super(const NotificationListState()) {
    // Initialize with stored notifications
    _loadNotifications();
  }

  /// Load notifications from local storage
  Future<void> _loadNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final notifications = await _dataSource.getAllNotifications();
      final unreadCount = await _dataSource.getUnreadCount();

      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('NotificationListNotifier: Load failed - $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications',
      );
    }
  }

  /// Refresh notifications
  Future<void> refresh() async {
    await _loadNotifications();
  }

  /// Add a new notification from FCM message
  Future<void> addNotificationFromMessage(RemoteMessage message) async {
    try {
      final entity = await _dataSource.saveNotification(message);

      // Add to beginning of list
      final updatedList = [entity, ...state.notifications];
      final updatedUnreadCount = state.unreadCount + 1;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: updatedUnreadCount,
      );

      debugPrint('NotificationListNotifier: Added notification - ${entity.id}');
    } catch (e) {
      debugPrint('NotificationListNotifier: Failed to add notification - $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String id) async {
    try {
      await _dataSource.markAsRead(id);

      // Update local state
      final updatedList = state.notifications.map((n) {
        if (n.id == id && !n.isRead) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final updatedUnreadCount = updatedList.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: updatedUnreadCount,
      );
    } catch (e) {
      debugPrint('NotificationListNotifier: Failed to mark as read - $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _dataSource.markAllAsRead();

      // Update local state
      final updatedList = state.notifications.map((n) {
        if (!n.isRead) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      state = state.copyWith(notifications: updatedList, unreadCount: 0);
    } catch (e) {
      debugPrint('NotificationListNotifier: Failed to mark all as read - $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String id) async {
    try {
      // Get the notification before deleting to check if it was unread
      final notification = state.notifications.firstWhere(
        (n) => n.id == id,
        orElse: () => throw Exception('Notification not found'),
      );

      await _dataSource.deleteNotification(id);

      // Update local state
      final updatedList = state.notifications.where((n) => n.id != id).toList();
      final updatedUnreadCount = !notification.isRead
          ? state.unreadCount - 1
          : state.unreadCount;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: updatedUnreadCount.clamp(0, state.notifications.length),
      );
    } catch (e) {
      debugPrint(
        'NotificationListNotifier: Failed to delete notification - $e',
      );
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      await _dataSource.clearAll();

      state = state.copyWith(notifications: [], unreadCount: 0);
    } catch (e) {
      debugPrint('NotificationListNotifier: Failed to clear all - $e');
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for notification list
final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>((
      ref,
    ) {
      final dataSource = ref.watch(notificationLocalDataSourceProvider);
      return NotificationListNotifier(dataSource);
    });

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Provider for unread notification count (for badge)
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationListProvider).unreadCount;
});

/// Provider for checking if there are any notifications
final hasNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationListProvider).notifications.isNotEmpty;
});

/// Provider for checking if there are unread notifications
final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationListProvider).unreadCount > 0;
});
