import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/notification_entity.dart';
import '../local/adapters/notification_hive_model.dart';

/// Local datasource for managing notifications in Hive
class NotificationLocalDataSource {
  static const String _boxName = 'notifications';
  static const int _maxNotifications = 100;

  Box<NotificationHiveModel>? _box;

  /// Get or open the notifications box
  Future<Box<NotificationHiveModel>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openBox<NotificationHiveModel>(_boxName);
    return _box!;
  }

  /// Save a notification from RemoteMessage
  Future<NotificationEntity> saveNotification(RemoteMessage message) async {
    final box = await _getBox();
    final model = NotificationHiveModel.fromRemoteMessage(message);

    // Check if notification with same ID already exists
    if (box.containsKey(model.id)) {
      debugPrint('NotificationLocalDataSource: Notification already exists - ${model.id}');
      return box.get(model.id)!.toEntity();
    }

    await box.put(model.id, model);
    debugPrint('NotificationLocalDataSource: Saved notification - ${model.id}');

    // Auto-prune if exceeding max
    await _pruneOldNotifications(box);

    return model.toEntity();
  }

  /// Save a notification entity directly
  Future<void> saveNotificationEntity(NotificationEntity entity) async {
    final box = await _getBox();
    final model = NotificationHiveModel.fromEntity(entity);
    await box.put(model.id, model);
    await _pruneOldNotifications(box);
  }

  /// Get all notifications sorted by received date (newest first)
  Future<List<NotificationEntity>> getAllNotifications() async {
    final box = await _getBox();
    final notifications = box.values.map((m) => m.toEntity()).toList();

    // Sort by received date (newest first)
    notifications.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    return notifications;
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final box = await _getBox();
    return box.values.where((m) => !m.isRead).length;
  }

  /// Mark a notification as read
  Future<void> markAsRead(String id) async {
    final box = await _getBox();
    final model = box.get(id);
    if (model != null && !model.isRead) {
      model.markAsRead();
      await model.save();
      debugPrint('NotificationLocalDataSource: Marked as read - $id');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final box = await _getBox();
    for (final model in box.values) {
      if (!model.isRead) {
        model.markAsRead();
        await model.save();
      }
    }
    debugPrint('NotificationLocalDataSource: Marked all as read');
  }

  /// Delete a notification
  Future<void> deleteNotification(String id) async {
    final box = await _getBox();
    await box.delete(id);
    debugPrint('NotificationLocalDataSource: Deleted notification - $id');
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('NotificationLocalDataSource: Cleared all notifications');
  }

  /// Prune old notifications if exceeding max limit
  Future<void> _pruneOldNotifications(Box<NotificationHiveModel> box) async {
    if (box.length <= _maxNotifications) return;

    // Get all notifications sorted by date (oldest first)
    final notifications = box.values.toList()
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

    // Calculate how many to remove
    final toRemove = box.length - _maxNotifications;

    // Remove oldest notifications
    for (var i = 0; i < toRemove; i++) {
      await box.delete(notifications[i].id);
    }

    debugPrint('NotificationLocalDataSource: Pruned $toRemove old notifications');
  }

  /// Close the box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}

/// Provider for NotificationLocalDataSource
final notificationLocalDataSourceProvider = Provider<NotificationLocalDataSource>((ref) {
  final dataSource = NotificationLocalDataSource();
  ref.onDispose(() => dataSource.close());
  return dataSource;
});
