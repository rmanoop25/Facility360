import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

/// Assignment status enum matching Laravel backend
/// Workflow: ASSIGNED → IN_PROGRESS → FINISHED → COMPLETED
/// Alternative path: ON_HOLD (from IN_PROGRESS, can resume)
@JsonEnum(valueField: 'value')
enum AssignmentStatus {
  @JsonValue('assigned')
  assigned('assigned'),

  @JsonValue('in_progress')
  inProgress('in_progress'),

  @JsonValue('on_hold')
  onHold('on_hold'),

  @JsonValue('finished')
  finished('finished'),

  @JsonValue('completed')
  completed('completed');

  const AssignmentStatus(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get localized label using easy_localization
  String get label => switch (this) {
    assigned => 'status.assigned'.tr(),
    inProgress => 'status.in_progress'.tr(),
    onHold => 'status.on_hold'.tr(),
    finished => 'status.finished'.tr(),
    completed => 'status.completed'.tr(),
  };

  /// Get icon for this status
  IconData get icon => switch (this) {
    assigned => Icons.assignment_rounded,
    inProgress => Icons.play_circle_rounded,
    onHold => Icons.pause_circle_rounded,
    finished => Icons.check_circle_rounded,
    completed => Icons.verified_rounded,
  };

  /// Check if work can be started
  bool get canStart => this == assigned;

  /// Check if work can be put on hold
  bool get canHold => this == inProgress;

  /// Check if work can be resumed
  bool get canResume => this == onHold;

  /// Check if work can be finished
  bool get canFinish => this == inProgress;

  /// Check if assignment is active (work not completed)
  bool get isActive => this != completed;

  /// Check if assignment requires action from service provider
  bool get requiresAction => switch (this) {
    assigned => true,
    inProgress => true,
    onHold => true,
    finished => false,
    completed => false,
  };

  /// Get next possible status
  AssignmentStatus? get nextStatus => switch (this) {
    assigned => inProgress,
    inProgress => finished,
    onHold => inProgress,
    finished => completed,
    completed => null,
  };

  /// Parse from string value
  static AssignmentStatus? fromValue(String? value) {
    if (value == null) return null;
    return AssignmentStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => AssignmentStatus.assigned,
    );
  }
}
