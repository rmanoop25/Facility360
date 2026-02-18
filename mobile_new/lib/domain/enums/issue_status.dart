import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

/// Issue status enum matching Laravel backend
/// Workflow: PENDING → ASSIGNED → IN_PROGRESS → FINISHED → COMPLETED
/// Alternative paths: ON_HOLD (from IN_PROGRESS), CANCELLED (from any)
@JsonEnum(valueField: 'value')
enum IssueStatus {
  @JsonValue('pending')
  pending('pending'),

  @JsonValue('assigned')
  assigned('assigned'),

  @JsonValue('in_progress')
  inProgress('in_progress'),

  @JsonValue('on_hold')
  onHold('on_hold'),

  @JsonValue('finished')
  finished('finished'),

  @JsonValue('completed')
  completed('completed'),

  @JsonValue('cancelled')
  cancelled('cancelled');

  const IssueStatus(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get localized label using easy_localization
  String get label => switch (this) {
    pending => 'status.pending'.tr(),
    assigned => 'status.assigned'.tr(),
    inProgress => 'status.in_progress'.tr(),
    onHold => 'status.on_hold'.tr(),
    finished => 'status.finished'.tr(),
    completed => 'status.completed'.tr(),
    cancelled => 'status.cancelled'.tr(),
  };

  /// Get icon for this status
  IconData get icon => switch (this) {
    pending => Icons.schedule_rounded,
    assigned => Icons.person_add_rounded,
    inProgress => Icons.play_circle_rounded,
    onHold => Icons.pause_circle_rounded,
    finished => Icons.check_circle_rounded,
    completed => Icons.verified_rounded,
    cancelled => Icons.cancel_rounded,
  };

  /// Check if issue is active (not completed or cancelled)
  bool get isActive =>
      this != completed && this != cancelled;

  /// Check if issue can be assigned
  bool get canBeAssigned => this == pending;

  /// Check if issue can be cancelled
  bool get canBeCancelled =>
      this != completed && this != cancelled;

  /// Check if issue is in a terminal state
  bool get isTerminal =>
      this == completed || this == cancelled;

  /// Get all active statuses (for filtering)
  static List<IssueStatus> get activeStatuses => [
    pending,
    assigned,
    inProgress,
    onHold,
    finished,
  ];

  /// Get all terminal statuses
  static List<IssueStatus> get terminalStatuses => [
    completed,
    cancelled,
  ];

  /// Parse from string value
  static IssueStatus? fromValue(String? value) {
    if (value == null) return null;
    return IssueStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => IssueStatus.pending,
    );
  }
}
