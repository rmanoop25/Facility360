import 'package:easy_localization/easy_localization.dart';

import '../../domain/enums/timeline_action.dart';
import 'user_model.dart';

/// Timeline model matching Laravel backend IssueTimeline entity
class TimelineModel {
  final int id;
  final int? issueId;
  final int? issueAssignmentId;
  final TimelineAction action;
  final int? performedBy;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final UserModel? performedByUser;

  const TimelineModel({
    required this.id,
    this.issueId,
    this.issueAssignmentId,
    required this.action,
    this.performedBy,
    this.notes,
    this.metadata,
    this.createdAt,
    this.performedByUser,
  });

  /// Get performer name
  String get performerName =>
      performedByUser?.displayName ?? 'Unknown User';

  /// Get action description
  String getDescription(String locale) =>
      action.getLocalizedDescription(performerName, locale);

  /// Get formatted timestamp
  String get formattedTime {
    if (createdAt == null) return '';
    final time = createdAt!;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Get formatted date (e.g., "Jan 13, 2026")
  String get formattedDate {
    if (createdAt == null) return '';
    return DateFormat('MMM d, y').format(createdAt!);
  }

  /// Get relative time (localized)
  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inDays > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${diff.inDays} ${'time.day'.tr()}'});
    } else if (diff.inHours > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${diff.inHours} ${'time.hour'.tr()}'});
    } else if (diff.inMinutes > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${diff.inMinutes} ${'time.minute'.tr()}'});
    }
    return 'common.just_now'.tr();
  }

  /// Check if this is a positive action
  bool get isPositive => action.isPositive;

  /// Check if has notes
  bool get hasNotes => notes != null && notes!.isNotEmpty;

  TimelineModel copyWith({
    int? id,
    int? issueId,
    int? issueAssignmentId,
    TimelineAction? action,
    int? performedBy,
    String? notes,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    UserModel? performedByUser,
  }) {
    return TimelineModel(
      id: id ?? this.id,
      issueId: issueId ?? this.issueId,
      issueAssignmentId: issueAssignmentId ?? this.issueAssignmentId,
      action: action ?? this.action,
      performedBy: performedBy ?? this.performedBy,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      performedByUser: performedByUser ?? this.performedByUser,
    );
  }

  factory TimelineModel.fromJson(Map<String, dynamic> json) {
    // Handle action - can be string or object with 'value' field
    String? actionValue;
    if (json['action'] is String) {
      actionValue = json['action'] as String?;
    } else if (json['action'] is Map) {
      actionValue = (json['action'] as Map)['value'] as String?;
    }

    // Parse performed_by field - can be int (user ID) or object (full user)
    int? performedById;
    UserModel? performedByUser;

    if (json['performed_by'] != null) {
      if (json['performed_by'] is Map) {
        // It's a user object from the API
        final userMap = json['performed_by'] as Map<String, dynamic>;
        performedByUser = UserModel.fromJson(userMap);
        performedById = performedByUser.id;
      } else {
        // It's just the user ID
        performedById = _parseInt(json['performed_by']);
      }
    }

    return TimelineModel(
      id: _parseInt(json['id']) ?? 0,
      issueId: _parseInt(json['issue_id']),
      issueAssignmentId: _parseInt(json['issue_assignment_id']),
      action: TimelineAction.fromValue(actionValue) ??
          TimelineAction.created,
      performedBy: performedById,
      notes: json['notes'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      performedByUser: performedByUser,
    );
  }

  /// Helper to safely parse int from dynamic value (handles both int and String)
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'issue_assignment_id': issueAssignmentId,
      'action': action.value,
      'performed_by': performedByUser?.toJson(),
      'notes': notes,
      'metadata': metadata,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
