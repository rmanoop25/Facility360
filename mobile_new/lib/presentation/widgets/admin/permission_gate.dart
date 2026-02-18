import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/enums/user_role.dart';
import '../../../domain/enums/user_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';

/// A widget that conditionally renders its child based on user roles.
///
/// ⚠️ DEPRECATED: Use PermissionBasedGate or UserTypeGate instead.
/// This widget checks hardcoded roles, which doesn't support dynamic roles.
///
/// Migration:
/// ```dart
/// // OLD - hardcoded roles
/// PermissionGate(
///   allowedRoles: [UserRole.superAdmin, UserRole.manager],
///   child: DeleteButton(),
/// )
///
/// // NEW - permission-based (works with any role)
/// PermissionBasedGate(
///   permission: 'delete_users',
///   child: DeleteButton(),
/// )
///
/// // OR - user type-based (architectural)
/// UserTypeGate(
///   allowedTypes: [UserType.admin],
///   child: AdminButton(),
/// )
/// ```
@Deprecated('Use PermissionBasedGate or UserTypeGate instead')
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  /// The roles that are allowed to see the child widget.
  final List<UserRole> allowedRoles;

  /// The widget to display when the user has permission.
  final Widget child;

  /// Optional widget to display when the user does not have permission.
  /// If null, the widget will not render anything.
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentRole = authState.user?.role;

    if (currentRole == null) {
      return fallback ?? const SizedBox.shrink();
    }

    if (allowedRoles.contains(currentRole)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// A widget that conditionally renders based on user TYPE (not role name).
///
/// Use this for architectural access control (tenant/sp/admin sections).
/// Works with unlimited dynamic roles.
///
/// Example:
/// ```dart
/// UserTypeGate(
///   allowedTypes: [UserType.admin],  // Any admin role (manager, supervisor, etc.)
///   child: AdminButton(),
/// )
/// ```
class UserTypeGate extends ConsumerWidget {
  const UserTypeGate({
    super.key,
    required this.allowedTypes,
    required this.child,
    this.fallback,
  });

  /// The user types that are allowed to see the child widget.
  final List<UserType> allowedTypes;

  /// The widget to display when the user has the correct type.
  final Widget child;

  /// Optional widget to display when the user does not have the correct type.
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userType = user?.userType;

    if (userType != null && allowedTypes.contains(userType)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// A widget that shows content only for users who can manage entities.
///
/// Updated to use permissions instead of hardcoded roles.
/// Works with any admin role (super_admin, manager, supervisor, etc.)
class CanManageGate extends ConsumerWidget {
  const CanManageGate({
    super.key,
    required this.child,
    this.fallback,
    this.entity,
  });

  final Widget child;
  final Widget? fallback;

  /// Optional: specific entity to check manage permissions for
  /// If null, checks if user is admin type (has access to admin section)
  final String? entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Check if user has any manage permissions
    bool canManage = false;
    if (entity != null) {
      // Check specific entity management permissions
      canManage = user?.hasAnyPermission([
            'create_$entity',
            'update_$entity',
            'delete_$entity',
          ]) ??
          false;
    } else {
      // Check if user is admin type (can access admin section)
      canManage = user?.userType == UserType.admin;
    }

    return canManage ? child : (fallback ?? const SizedBox.shrink());
  }
}

/// A widget that shows content only for super admins.
class SuperAdminGate extends ConsumerWidget {
  const SuperAdminGate({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      allowedRoles: const [UserRole.superAdmin],
      fallback: fallback,
      child: child,
    );
  }
}

/// A widget that hides content from read-only users (viewers).
class NotReadOnlyGate extends ConsumerWidget {
  const NotReadOnlyGate({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentRole = authState.user?.role;

    if (currentRole == null || currentRole.isReadOnly) {
      return fallback ?? const SizedBox.shrink();
    }

    return child;
  }
}

/// Permission-based gate (dynamic) - checks specific permission string
class PermissionBasedGate extends ConsumerWidget {
  const PermissionBasedGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  /// The permission string to check (e.g., 'create_categories')
  final String permission;

  /// The widget to display when the user has permission.
  final Widget child;

  /// Optional widget to display when the user does not have permission.
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(hasPermissionProvider(permission));
    return hasPermission ? child : (fallback ?? const SizedBox.shrink());
  }
}

/// Convenience gate for create permissions
class CanCreateGate extends ConsumerWidget {
  const CanCreateGate({
    super.key,
    required this.entity,
    required this.child,
    this.fallback,
  });

  /// The entity name (e.g., 'categories', 'tenants')
  final String entity;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionBasedGate(
      permission: 'create_$entity',
      fallback: fallback,
      child: child,
    );
  }
}

/// Convenience gate for update permissions
class CanUpdateGate extends ConsumerWidget {
  const CanUpdateGate({
    super.key,
    required this.entity,
    required this.child,
    this.fallback,
  });

  /// The entity name (e.g., 'categories', 'tenants')
  final String entity;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionBasedGate(
      permission: 'update_$entity',
      fallback: fallback,
      child: child,
    );
  }
}

/// Convenience gate for delete permissions
class CanDeleteGate extends ConsumerWidget {
  const CanDeleteGate({
    super.key,
    required this.entity,
    required this.child,
    this.fallback,
  });

  /// The entity name (e.g., 'categories', 'tenants')
  final String entity;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionBasedGate(
      permission: 'delete_$entity',
      fallback: fallback,
      child: child,
    );
  }
}
