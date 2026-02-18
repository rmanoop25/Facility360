import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

/// Timeline action enum matching Laravel backend
/// Tracks all actions performed on issues and assignments
@JsonEnum(valueField: 'value')
enum TimelineAction {
  @JsonValue('created')
  created('created'),

  @JsonValue('assigned')
  assigned('assigned'),

  @JsonValue('started')
  started('started'),

  @JsonValue('held')
  held('held'),

  @JsonValue('resumed')
  resumed('resumed'),

  @JsonValue('finished')
  finished('finished'),

  @JsonValue('approved')
  approved('approved'),

  @JsonValue('cancelled')
  cancelled('cancelled'),

  @JsonValue('updated')
  updated('updated'),

  @JsonValue('assignment_updated')
  assignmentUpdated('assignment_updated');

  const TimelineAction(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get localized label using easy_localization
  String get label => switch (this) {
    created => 'timeline_action.created'.tr(),
    assigned => 'timeline_action.assigned'.tr(),
    started => 'timeline_action.started'.tr(),
    held => 'timeline_action.held'.tr(),
    resumed => 'timeline_action.resumed'.tr(),
    finished => 'timeline_action.finished'.tr(),
    approved => 'timeline_action.approved'.tr(),
    cancelled => 'timeline_action.cancelled'.tr(),
    updated => 'timeline_action.updated'.tr(),
    assignmentUpdated => 'timeline_action.assignment_updated'.tr(),
  };

  /// Get icon for this action
  IconData get icon => switch (this) {
    created => Icons.add_circle_rounded,
    assigned => Icons.person_add_rounded,
    started => Icons.play_circle_rounded,
    held => Icons.pause_circle_rounded,
    resumed => Icons.play_arrow_rounded,
    finished => Icons.check_circle_rounded,
    approved => Icons.verified_rounded,
    cancelled => Icons.cancel_rounded,
    updated => Icons.edit_rounded,
    assignmentUpdated => Icons.edit_note_rounded,
  };

  /// Get description template
  String getDescription(String performerName) => switch (this) {
    created => '$performerName created this issue',
    assigned => '$performerName assigned this issue',
    started => '$performerName started working',
    held => '$performerName put the work on hold',
    resumed => '$performerName resumed working',
    finished => '$performerName finished the work',
    approved => '$performerName approved the work',
    cancelled => '$performerName cancelled this issue',
    updated => '$performerName edited this issue',
    assignmentUpdated => '$performerName updated the assignment',
  };

  /// Get Arabic description template
  String getDescriptionAr(String performerName) => switch (this) {
    created => 'قام $performerName بإنشاء هذه المشكلة',
    assigned => 'قام $performerName بتعيين هذه المشكلة',
    started => 'بدأ $performerName العمل',
    held => 'قام $performerName بتعليق العمل',
    resumed => 'استأنف $performerName العمل',
    finished => 'أنهى $performerName العمل',
    approved => 'وافق $performerName على العمل',
    cancelled => 'ألغى $performerName هذه المشكلة',
    updated => 'قام $performerName بتعديل هذه المشكلة',
    assignmentUpdated => 'قام $performerName بتحديث التعيين',
  };

  /// Get localized description
  String getLocalizedDescription(String performerName, String locale) =>
      locale == 'ar'
          ? getDescriptionAr(performerName)
          : getDescription(performerName);

  /// Check if this is a positive action
  bool get isPositive => switch (this) {
    created => true,
    assigned => true,
    started => true,
    held => false,
    resumed => true,
    finished => true,
    approved => true,
    cancelled => false,
    updated => true,
    assignmentUpdated => true,
  };

  /// Parse from string value
  static TimelineAction? fromValue(String? value) {
    if (value == null) return null;
    return TimelineAction.values.firstWhere(
      (a) => a.value == value,
      orElse: () => TimelineAction.created,
    );
  }
}
