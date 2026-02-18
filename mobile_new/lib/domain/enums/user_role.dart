import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

/// User role enum matching Laravel backend
@JsonEnum(valueField: 'value')
enum UserRole {
  @JsonValue('tenant')
  tenant('tenant'),

  @JsonValue('service_provider')
  serviceProvider('service_provider'),

  @JsonValue('super_admin')
  superAdmin('super_admin'),

  @JsonValue('manager')
  manager('manager'),

  @JsonValue('viewer')
  viewer('viewer');

  const UserRole(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get localized label using easy_localization
  String get label => switch (this) {
    tenant => 'role.tenant'.tr(),
    serviceProvider => 'role.service_provider'.tr(),
    superAdmin => 'role.super_admin'.tr(),
    manager => 'role.manager'.tr(),
    viewer => 'role.viewer'.tr(),
  };

  /// Get icon for this role
  IconData get icon => switch (this) {
    tenant => Icons.home_rounded,
    serviceProvider => Icons.engineering_rounded,
    superAdmin => Icons.admin_panel_settings_rounded,
    manager => Icons.manage_accounts_rounded,
    viewer => Icons.visibility_rounded,
  };

  /// Check if user is a mobile user (tenant or service provider)
  bool get isMobileUser => this == tenant || this == serviceProvider;

  /// Check if user is an admin (super_admin, manager, or viewer)
  bool get isAdmin =>
      this == superAdmin || this == manager || this == viewer;

  /// Check if user can create issues
  bool get canCreateIssue => this == tenant;

  /// Check if user can execute work
  bool get canExecuteWork => this == serviceProvider;

  /// Check if user can assign issues
  bool get canAssignIssue => this == superAdmin || this == manager;

  /// Check if user can approve work
  bool get canApproveWork => this == superAdmin || this == manager;

  /// Check if user can manage issues (assign, approve, cancel)
  bool get canManageIssues => this == superAdmin || this == manager;

  /// Check if user can manage tenants (create, edit, toggle status)
  bool get canManageTenants => this == superAdmin || this == manager;

  /// Check if user can manage service providers (create, edit, toggle status)
  bool get canManageServiceProviders => this == superAdmin || this == manager;

  /// Check if user can manage categories (create, edit, toggle status)
  bool get canManageCategories => this == superAdmin || this == manager;

  /// Check if user can manage consumables (create, edit, toggle status)
  bool get canManageConsumables => this == superAdmin || this == manager;

  /// Check if user can manage admin users (super_admin only)
  bool get canManageAdminUsers => this == superAdmin;

  /// Check if user has read-only access (viewer)
  bool get isReadOnly => this == viewer;

  /// Check if user can export reports
  bool get canExportReports => this == superAdmin || this == manager;

  /// Get home route for this role
  String get homeRoute => switch (this) {
    tenant => '/tenant',
    serviceProvider => '/sp',
    superAdmin => '/admin',
    manager => '/admin',
    viewer => '/admin',
  };

  /// Parse from string value
  static UserRole? fromValue(String? value) {
    if (value == null) return null;
    return UserRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => UserRole.tenant,
    );
  }
}
