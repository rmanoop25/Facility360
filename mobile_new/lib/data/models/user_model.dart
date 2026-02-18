import '../../domain/enums/user_role.dart';
import '../../domain/enums/user_type.dart';
import 'tenant_model.dart';
import 'service_provider_model.dart';

/// User model matching Laravel backend User entity
/// Supports dynamic roles and permissions from Spatie Permission
class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePhoto;
  final String? fcmToken;
  final String locale;
  final bool isActive;
  final DateTime? createdAt;
  final TenantModel? tenant;
  final ServiceProviderModel? serviceProvider;
  final UserRole? _explicitRole;

  /// Role names from backend (e.g., ["super_admin"], ["manager"], ["supervisor"])
  final List<String> roles;

  /// Permissions from backend (e.g., ["view_issues", "assign_issues"])
  final List<String> permissions;

  /// API flags for user type detection (from /auth/me response)
  final bool? _isTenantFlag;
  final bool? _isServiceProviderFlag;
  final bool? _isAdminFlag;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profilePhoto,
    this.fcmToken,
    this.locale = 'en',
    this.isActive = true,
    this.createdAt,
    this.tenant,
    this.serviceProvider,
    UserRole? role,
    this.roles = const [],
    this.permissions = const [],
    bool? isTenantFlag,
    bool? isServiceProviderFlag,
    bool? isAdminFlag,
  })  : _explicitRole = role,
        _isTenantFlag = isTenantFlag,
        _isServiceProviderFlag = isServiceProviderFlag,
        _isAdminFlag = isAdminFlag;

  /// Check if user is a tenant (uses API flag if available, falls back to tenant object)
  bool get isTenant => _isTenantFlag ?? tenant != null;

  /// Check if user is a service provider (uses API flag if available)
  bool get isServiceProvider => _isServiceProviderFlag ?? serviceProvider != null;

  /// Check if user is an admin (uses API flag if available)
  bool get isAdmin => _isAdminFlag ?? role.isAdmin;

  /// Get user role - uses API flags for dynamic role support
  UserRole get role {
    if (_explicitRole != null) return _explicitRole;

    // Use API flags for routing (supports dynamic roles)
    if (_isTenantFlag == true) return UserRole.tenant;
    if (_isServiceProviderFlag == true) return UserRole.serviceProvider;
    if (_isAdminFlag == true) {
      // Try to determine specific admin role from roles array
      if (roles.contains('super_admin')) return UserRole.superAdmin;
      if (roles.contains('manager')) return UserRole.manager;
      if (roles.contains('viewer')) return UserRole.viewer;
      // Default to superAdmin for any other admin role (dynamic roles)
      return UserRole.superAdmin;
    }

    // Fallback to object-based detection
    if (tenant != null) return UserRole.tenant;
    if (serviceProvider != null) return UserRole.serviceProvider;
    return UserRole.superAdmin;
  }

  /// Get the primary role name (first role from roles array)
  String? get primaryRoleName => roles.isNotEmpty ? roles.first : null;

  /// Get user type based on backend flags (architectural category, not role name)
  ///
  /// User types are fixed (tenant/serviceProvider/admin) and determine which
  /// section of the app to show. This works with unlimited dynamic roles.
  ///
  /// Examples:
  /// - User with 'supervisor' role + is_admin=true → UserType.admin
  /// - User with 'manager' role + is_admin=true → UserType.admin
  /// - User with 'tenant' role + is_tenant=true → UserType.tenant
  UserType get userType {
    if (_isTenantFlag == true) return UserType.tenant;
    if (_isServiceProviderFlag == true) return UserType.serviceProvider;
    return UserType.admin; // Any other role (super_admin, manager, viewer, custom roles)
  }

  /// Get home route based on user type (not specific role name)
  ///
  /// Works with any admin role - supervisor, manager, custom_admin, etc.
  /// all get routed to /admin section.
  String get homeRoute => userType.homeRoute;

  // Permission checking methods

  /// Check if user has a specific permission
  /// Super admin bypasses all permission checks (mirrors Shield's Gate::before)
  bool hasPermission(String permission) {
    if (roles.contains('super_admin')) return true;
    return permissions.contains(permission);
  }

  /// Check if user has any of the given permissions
  bool hasAnyPermission(List<String> permissionList) {
    if (roles.contains('super_admin')) return true;
    return permissionList.any((p) => permissions.contains(p));
  }

  /// Check if user has all of the given permissions
  bool hasAllPermissions(List<String> permissionList) {
    if (roles.contains('super_admin')) return true;
    return permissionList.every((p) => permissions.contains(p));
  }

  // Common permission checks

  bool get canViewIssues => hasPermission('view_issues');
  bool get canCreateIssues => hasPermission('create_issues');
  bool get canAssignIssues => hasPermission('assign_issues');
  bool get canApproveIssues => hasPermission('approve_issues');
  bool get canCancelIssues => hasPermission('cancel_issues');
  bool get canUpdateIssues => hasPermission('update_issues');

  bool get canViewTenants => hasPermission('view_tenants');
  bool get canManageTenants => hasAnyPermission(['create_tenants', 'update_tenants', 'delete_tenants']);

  bool get canViewServiceProviders => hasPermission('view_service_providers');
  bool get canManageServiceProviders => hasAnyPermission(['create_service_providers', 'update_service_providers', 'delete_service_providers']);

  bool get canViewCategories => hasPermission('view_categories');
  bool get canManageCategories => hasAnyPermission(['create_categories', 'update_categories', 'delete_categories']);

  bool get canViewConsumables => hasPermission('view_consumables');
  bool get canManageConsumables => hasAnyPermission(['create_consumables', 'update_consumables', 'delete_consumables']);

  bool get canViewUsers => hasPermission('view_users');
  bool get canManageUsers => hasAnyPermission(['create_users', 'update_users', 'delete_users']);

  bool get canViewReports => hasPermission('view_reports');
  bool get canExportReports => hasPermission('export_reports');

  bool get canManageSettings => hasPermission('manage_settings');

  /// Get display name with fallback
  String get displayName => name.isNotEmpty ? name : email.split('@').first;

  /// Get initials for avatar
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  /// Get formatted phone number
  String? get formattedPhone {
    if (phone == null || phone!.isEmpty) return null;
    return phone;
  }

  /// Copy with method
  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? profilePhoto,
    String? fcmToken,
    String? locale,
    bool? isActive,
    DateTime? createdAt,
    TenantModel? tenant,
    ServiceProviderModel? serviceProvider,
    UserRole? role,
    List<String>? roles,
    List<String>? permissions,
    bool? isTenantFlag,
    bool? isServiceProviderFlag,
    bool? isAdminFlag,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      fcmToken: fcmToken ?? this.fcmToken,
      locale: locale ?? this.locale,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      tenant: tenant ?? this.tenant,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      role: role ?? _explicitRole,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      isTenantFlag: isTenantFlag ?? _isTenantFlag,
      isServiceProviderFlag: isServiceProviderFlag ?? _isServiceProviderFlag,
      isAdminFlag: isAdminFlag ?? _isAdminFlag,
    );
  }

  /// Factory constructor for /auth/login response (minimal user data)
  factory UserModel.fromLoginResponse(Map<String, dynamic> json) {
    // Parse roles array
    final rolesList = <String>[];
    if (json['roles'] != null) {
      rolesList.addAll((json['roles'] as List).map((e) => e.toString()));
    }

    return UserModel(
      id: _parseInt(json['id']) ?? 0,
      name: _parseString(json['name']) ?? '',
      email: _parseString(json['email']) ?? '',
      locale: _parseString(json['locale']) ?? 'en',
      roles: rolesList,
      permissions: const [], // Login response doesn't include full permissions
      isTenantFlag: json['is_tenant'] as bool?,
      isServiceProviderFlag: json['is_service_provider'] as bool?,
      isAdminFlag: json['is_admin'] as bool?,
    );
  }

  /// Factory constructor for /auth/me response (full user data with permissions)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Parse roles array
    final rolesList = <String>[];
    if (json['roles'] != null) {
      rolesList.addAll((json['roles'] as List).map((e) => e.toString()));
    }

    // Parse permissions array
    final permissionsList = <String>[];
    if (json['permissions'] != null) {
      permissionsList.addAll((json['permissions'] as List).map((e) => e.toString()));
    }

    return UserModel(
      id: _parseInt(json['id']) ?? 0,
      name: _parseString(json['name']) ?? '',
      email: _parseString(json['email']) ?? '',
      phone: _parseString(json['phone']),
      profilePhoto: _parseString(json['profile_photo_url']) ?? _parseString(json['profile_photo']),
      fcmToken: _parseString(json['fcm_token']),
      locale: _parseString(json['locale']) ?? 'en',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      tenant: json['tenant'] != null
          ? TenantModel.fromJson(json['tenant'] as Map<String, dynamic>)
          : null,
      serviceProvider: json['service_provider'] != null
          ? ServiceProviderModel.fromJson(json['service_provider'] as Map<String, dynamic>)
          : null,
      roles: rolesList,
      permissions: permissionsList,
      isTenantFlag: json['is_tenant'] as bool?,
      isServiceProviderFlag: json['is_service_provider'] as bool?,
      isAdminFlag: json['is_admin'] as bool?,
    );
  }

  /// Helper to safely parse int from dynamic value
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  /// Helper to safely parse string from dynamic value
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profile_photo': profilePhoto,
      'fcm_token': fcmToken,
      'locale': locale,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'tenant': tenant?.toJson(),
      'service_provider': serviceProvider?.toJson(),
      'roles': roles,
      'permissions': permissions,
      'is_tenant': _isTenantFlag,
      'is_service_provider': _isServiceProviderFlag,
      'is_admin': _isAdminFlag,
    };
  }
}
