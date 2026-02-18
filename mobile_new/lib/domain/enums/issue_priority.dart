import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

/// Issue priority enum matching Laravel backend
@JsonEnum(valueField: 'value')
enum IssuePriority {
  @JsonValue('low')
  low('low'),

  @JsonValue('medium')
  medium('medium'),

  @JsonValue('high')
  high('high');

  const IssuePriority(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get localized label using easy_localization
  String get label => switch (this) {
    low => 'priority.low'.tr(),
    medium => 'priority.medium'.tr(),
    high => 'priority.high'.tr(),
  };

  /// Get icon for this priority
  IconData get icon => switch (this) {
    low => Icons.arrow_downward_rounded,
    medium => Icons.remove_rounded,
    high => Icons.arrow_upward_rounded,
  };

  /// Get sort order (higher priority = lower number)
  int get sortOrder => switch (this) {
    high => 1,
    medium => 2,
    low => 3,
  };

  /// Parse from string value
  static IssuePriority? fromValue(String? value) {
    if (value == null) return null;
    return IssuePriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => IssuePriority.medium,
    );
  }
}
