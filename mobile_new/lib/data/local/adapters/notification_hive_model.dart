import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/notification_entity.dart';

/// Hive model for storing notifications locally
/// Uses typeId: 3 (after issues=1, assignments=2)
@HiveType(typeId: 3)
class NotificationHiveModel extends HiveObject {
  /// Unique identifier (FCM message ID or generated UUID)
  @HiveField(0)
  String id;

  /// Notification title
  @HiveField(1)
  String title;

  /// Notification body/message
  @HiveField(2)
  String body;

  /// Notification type (e.g., 'issue_assigned', 'issue_completed')
  @HiveField(3)
  String? type;

  /// Related issue ID if applicable
  @HiveField(4)
  int? issueId;

  /// Related assignment ID if applicable (for service providers)
  @HiveField(8)
  int? assignmentId;

  /// Additional data payload as JSON string
  @HiveField(5)
  String? dataJson;

  /// When the notification was received
  @HiveField(6)
  DateTime receivedAt;

  /// Whether the notification has been read
  @HiveField(7)
  bool isRead;

  NotificationHiveModel({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.issueId,
    this.assignmentId,
    this.dataJson,
    required this.receivedAt,
    this.isRead = false,
  });

  /// Create from Firebase RemoteMessage
  factory NotificationHiveModel.fromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    // Extract issue ID from data payload if present
    int? issueId;
    if (data['issue_id'] != null) {
      issueId = int.tryParse(data['issue_id'].toString());
    }

    // Extract assignment ID from data payload if present
    int? assignmentId;
    if (data['assignment_id'] != null) {
      assignmentId = int.tryParse(data['assignment_id'].toString());
    }

    return NotificationHiveModel(
      id: message.messageId ?? const Uuid().v4(),
      title: notification?.title ?? data['title'] ?? 'New Notification',
      body: notification?.body ?? data['body'] ?? '',
      type: data['type'] as String?,
      issueId: issueId,
      assignmentId: assignmentId,
      dataJson: data.isNotEmpty ? jsonEncode(data) : null,
      receivedAt: DateTime.now(),
      isRead: false,
    );
  }

  /// Create from entity
  factory NotificationHiveModel.fromEntity(NotificationEntity entity) {
    return NotificationHiveModel(
      id: entity.id,
      title: entity.title,
      body: entity.body,
      type: entity.type,
      issueId: entity.issueId,
      assignmentId: entity.assignmentId,
      dataJson: entity.data,
      receivedAt: entity.receivedAt,
      isRead: entity.isRead,
    );
  }

  /// Convert to entity
  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      title: title,
      body: body,
      type: type,
      issueId: issueId,
      assignmentId: assignmentId,
      data: dataJson,
      receivedAt: receivedAt,
      isRead: isRead,
    );
  }

  /// Mark notification as read
  void markAsRead() {
    isRead = true;
  }
}
