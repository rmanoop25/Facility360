import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/user_type.dart';
import 'auth_provider.dart';

/// Check if user has a specific permission
/// Usage: ref.watch(hasPermissionProvider('assign_issues'))
final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  return user?.hasPermission(permission) ?? false;
});

/// Check if user has any of the given permissions
/// Usage: ref.watch(hasAnyPermissionProvider(['create_issues', 'update_issues']))
final hasAnyPermissionProvider = Provider.family<bool, List<String>>((ref, permissions) {
  final user = ref.watch(currentUserProvider);
  return user?.hasAnyPermission(permissions) ?? false;
});

/// Check if user has all of the given permissions
/// Usage: ref.watch(hasAllPermissionsProvider(['view_issues', 'assign_issues']))
final hasAllPermissionsProvider = Provider.family<bool, List<String>>((ref, permissions) {
  final user = ref.watch(currentUserProvider);
  return user?.hasAllPermissions(permissions) ?? false;
});

// ============================================================================
// Issue Permissions
// ============================================================================

/// Can view issues (view_issues permission)
final canViewIssuesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('view_issues'));
});

/// Can create issues (create_issues permission)
final canCreateIssuesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('create_issues'));
});

/// Can assign issues (assign_issues permission)
final canAssignIssuesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('assign_issues'));
});

/// Can approve issues/work (approve_issues permission)
final canApproveIssuesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('approve_issues'));
});

/// Can cancel issues (cancel_issues permission)
final canCancelIssuesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('cancel_issues'));
});

/// Can update issues (update_issues permission)
final canUpdateIssuesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('update_issues'));
});

// ============================================================================
// Tenant Permissions
// ============================================================================

/// Can view tenants (view_tenants permission)
final canViewTenantsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('view_tenants'));
});

/// Can manage tenants (create, update, delete)
final canManageTenantsProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(['create_tenants', 'update_tenants', 'delete_tenants']));
});

/// Specific CRUD permissions for tenants
final canCreateTenantsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('create_tenants'));
});

final canUpdateTenantsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('update_tenants'));
});

final canDeleteTenantsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('delete_tenants'));
});

// ============================================================================
// Service Provider Permissions
// ============================================================================

/// Can view service providers (view_service_providers permission)
final canViewServiceProvidersProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('view_service_providers'));
});

/// Can manage service providers (create, update, delete)
final canManageServiceProvidersProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(['create_service_providers', 'update_service_providers', 'delete_service_providers']));
});

/// Specific CRUD permissions for service providers
final canCreateServiceProvidersProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('create_service_providers'));
});

final canUpdateServiceProvidersProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('update_service_providers'));
});

final canDeleteServiceProvidersProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('delete_service_providers'));
});

// ============================================================================
// Category Permissions
// ============================================================================

/// Can view categories (view_categories permission)
final canViewCategoriesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('view_categories'));
});

/// Can manage categories (create, update, delete)
final canManageCategoriesProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(['create_categories', 'update_categories', 'delete_categories']));
});

/// Specific CRUD permissions for categories
final canCreateCategoriesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('create_categories'));
});

final canUpdateCategoriesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('update_categories'));
});

final canDeleteCategoriesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('delete_categories'));
});

// ============================================================================
// Consumable Permissions
// ============================================================================

/// Can view consumables (view_consumables permission)
final canViewConsumablesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('view_consumables'));
});

/// Can manage consumables (create, update, delete)
final canManageConsumablesProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(['create_consumables', 'update_consumables', 'delete_consumables']));
});

/// Specific CRUD permissions for consumables
final canCreateConsumablesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('create_consumables'));
});

final canUpdateConsumablesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('update_consumables'));
});

final canDeleteConsumablesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('delete_consumables'));
});

// ============================================================================
// User Permissions
// ============================================================================

/// Can view users (view_users permission)
final canViewUsersProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('view_users'));
});

/// Can manage users (create, update, delete)
final canManageUsersProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(['create_users', 'update_users', 'delete_users']));
});

// ============================================================================
// Report Permissions
// ============================================================================

/// Can view reports (view_reports permission)
final canViewReportsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('view_reports'));
});

/// Can export reports (export_reports permission)
final canExportReportsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('export_reports'));
});

// ============================================================================
// Settings Permissions
// ============================================================================

/// Can manage settings (manage_settings permission)
final canManageSettingsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider('manage_settings'));
});

// ============================================================================
// User Type Checks (Works with Dynamic Roles)
// ============================================================================

/// Get the current user's type (architectural category)
/// Returns: UserType.tenant, UserType.serviceProvider, or UserType.admin
/// Works with unlimited dynamic roles (supervisor, auditor, etc. → admin)
final userTypeProvider = Provider<UserType?>((ref) {
  return ref.watch(currentUserProvider)?.userType;
});

/// Is the current user a tenant
/// Returns true if user has tenant relationship
final isTenantProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isTenant ?? false;
});

/// Is the current user a service provider
/// Returns true if user has service_provider relationship
final isServiceProviderProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isServiceProvider ?? false;
});

/// Is the current user an admin (any admin role)
/// Returns true for super_admin, manager, viewer, and ANY custom admin roles
/// Works with dynamic roles like supervisor, auditor, maintenance_lead, etc.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAdmin ?? false;
});

/// Get all permissions the current user has
/// Example: ['view_issues', 'assign_issues', 'approve_issues']
final userPermissionsProvider = Provider<List<String>>((ref) {
  return ref.watch(currentUserProvider)?.permissions ?? [];
});

/// Get all roles the current user has
/// Example: ['supervisor'], ['manager', 'auditor'], ['custom_role']
/// Supports unlimited dynamic roles from backend
final userRolesProvider = Provider<List<String>>((ref) {
  return ref.watch(currentUserProvider)?.roles ?? [];
});
