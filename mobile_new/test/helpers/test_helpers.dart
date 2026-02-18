import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lib/data/models/user_model.dart';
import '../../lib/domain/enums/user_role.dart';
import '../../lib/domain/enums/sync_status.dart';

/// Creates a [UserModel] for a given role with configurable permissions.
///
/// This is the primary test factory for user-dependent tests across
/// widget, unit, and integration test suites.
UserModel createTestUser({
  int id = 1,
  String name = 'Test User',
  String email = 'test@example.com',
  UserRole role = UserRole.superAdmin,
  List<String> roles = const [],
  List<String> permissions = const [],
  bool isActive = true,
  String locale = 'en',
}) {
  // Derive role flags from the role enum
  final isTenant = role == UserRole.tenant;
  final isServiceProvider = role == UserRole.serviceProvider;
  final isAdmin =
      role == UserRole.superAdmin ||
      role == UserRole.manager ||
      role == UserRole.viewer;

  // Derive roles list if not provided
  final effectiveRoles = roles.isNotEmpty ? roles : [role.value];

  return UserModel(
    id: id,
    name: name,
    email: email,
    locale: locale,
    isActive: isActive,
    roles: effectiveRoles,
    permissions: permissions,
    isTenantFlag: isTenant,
    isServiceProviderFlag: isServiceProvider,
    isAdminFlag: isAdmin,
  );
}

/// Pre-built user instances for each role.
///
/// Usage:
/// ```dart
/// final user = TestUsers.superAdmin;
/// final tenantUser = TestUsers.tenant;
/// ```
class TestUsers {
  TestUsers._();

  static UserModel get superAdmin => createTestUser(
    id: 1,
    name: 'Super Admin',
    email: 'admin@test.com',
    role: UserRole.superAdmin,
    permissions: _allPermissions,
  );

  static UserModel get manager => createTestUser(
    id: 2,
    name: 'Manager',
    email: 'manager@test.com',
    role: UserRole.manager,
    permissions: _managerPermissions,
  );

  static UserModel get viewer => createTestUser(
    id: 3,
    name: 'Viewer',
    email: 'viewer@test.com',
    role: UserRole.viewer,
    permissions: _viewerPermissions,
  );

  static UserModel get tenant => createTestUser(
    id: 4,
    name: 'Tenant',
    email: 'tenant@test.com',
    role: UserRole.tenant,
    permissions: _tenantPermissions,
  );

  static UserModel get serviceProvider => createTestUser(
    id: 5,
    name: 'Service Provider',
    email: 'sp@test.com',
    role: UserRole.serviceProvider,
    permissions: _spPermissions,
  );

  static const _allPermissions = [
    'view_issues', 'create_issues', 'update_issues', 'delete_issues',
    'assign_issues', 'approve_issues', 'cancel_issues',
    'view_tenants', 'create_tenants', 'update_tenants', 'delete_tenants',
    'view_service_providers', 'create_service_providers',
    'update_service_providers', 'delete_service_providers',
    'view_categories', 'create_categories', 'update_categories',
    'delete_categories',
    'view_consumables', 'create_consumables', 'update_consumables',
    'delete_consumables',
    'view_users', 'create_users', 'update_users', 'delete_users',
    'view_reports', 'export_reports', 'manage_settings',
  ];

  static const _managerPermissions = [
    'view_issues', 'update_issues', 'assign_issues', 'approve_issues',
    'cancel_issues',
    'view_tenants', 'create_tenants', 'update_tenants',
    'view_service_providers', 'create_service_providers',
    'update_service_providers',
    'view_categories', 'create_categories', 'update_categories',
    'view_consumables', 'create_consumables', 'update_consumables',
    'view_reports',
  ];

  static const _viewerPermissions = [
    'view_issues', 'view_tenants', 'view_service_providers',
    'view_categories', 'view_consumables', 'view_reports',
  ];

  static const _tenantPermissions = [
    'view_issues', 'create_issues', 'cancel_issues',
  ];

  static const _spPermissions = [
    'view_issues',
  ];
}

/// Helper to create a [ProviderContainer] with an overridden auth state.
///
/// Usage:
/// ```dart
/// final container = createAuthenticatedContainer(TestUsers.superAdmin);
/// final result = container.read(someProvider);
/// ```
ProviderContainer createAuthenticatedContainer(
  UserModel user, {
  List<Override> additionalOverrides = const [],
}) {
  // This is a placeholder. Actual implementation will import the real
  // authStateProvider and create overrides.
  // Consumers should use ProviderScope(overrides: [...]) in widget tests.
  return ProviderContainer(overrides: additionalOverrides);
}
