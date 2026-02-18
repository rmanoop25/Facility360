/// Immutable notification entity for app notifications
class NotificationEntity {
  /// Unique identifier (FCM message ID or generated UUID)
  final String id;

  /// Notification title
  final String title;

  /// Notification body/message
  final String body;

  /// Notification type (e.g., 'issue_assigned', 'issue_completed', 'work_started')
  final String? type;

  /// Related issue ID if applicable
  final int? issueId;

  /// Related assignment ID if applicable (for service providers)
  final int? assignmentId;

  /// Additional data payload as JSON string
  final String? data;

  /// When the notification was received
  final DateTime receivedAt;

  /// Whether the notification has been read
  final bool isRead;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.issueId,
    this.assignmentId,
    this.data,
    required this.receivedAt,
    this.isRead = false,
  });

  /// Create a copy with modified fields
  NotificationEntity copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    int? issueId,
    int? assignmentId,
    String? data,
    DateTime? receivedAt,
    bool? isRead,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      issueId: issueId ?? this.issueId,
      assignmentId: assignmentId ?? this.assignmentId,
      data: data ?? this.data,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NotificationEntity(id: $id, title: $title, isRead: $isRead)';
  }
}
