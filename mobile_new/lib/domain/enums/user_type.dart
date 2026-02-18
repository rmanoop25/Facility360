/// User type based on backend relationship, not role name.
///
/// This is architectural (3 fixed types) vs roles (unlimited dynamic).
/// User types determine which section of the app to show, while roles
/// determine what permissions the user has.
///
/// Examples:
/// - Tenant user (has tenant relationship) → shows tenant section
/// - Service Provider (has service_provider relationship) → shows SP section
/// - Manager/Supervisor/Auditor (any admin role) → shows admin section
enum UserType {
  /// User has a tenant relationship - shows tenant section of mobile app
  /// Determined by backend flag: is_tenant == true
  tenant,

  /// User has a service_provider relationship - shows service provider section
  /// Determined by backend flag: is_service_provider == true
  serviceProvider,

  /// User has any other role (super_admin, manager, viewer, custom roles)
  /// Shows admin section of mobile app
  /// Determined by backend flag: is_admin == true
  admin;

  /// Get home route for this user type
  String get homeRoute {
    switch (this) {
      case UserType.tenant:
        return '/tenant';
      case UserType.serviceProvider:
        return '/sp';
      case UserType.admin:
        return '/admin';
    }
  }

  /// Get display name key for localization
  /// Use with .tr() extension: userType.displayNameKey.tr()
  String get displayNameKey {
    switch (this) {
      case UserType.tenant:
        return 'tenant.role';
      case UserType.serviceProvider:
        return 'service_provider.role';
      case UserType.admin:
        return 'admin.role';
    }
  }

  /// Check if this is a mobile-only user type
  bool get isMobileOnly {
    switch (this) {
      case UserType.tenant:
      case UserType.serviceProvider:
        return true;
      case UserType.admin:
        return false;
    }
  }

  /// Check if this user type can access admin panel
  bool get canAccessAdminPanel {
    return this == UserType.admin;
  }

  /// Get icon name for this user type
  String get iconName {
    switch (this) {
      case UserType.tenant:
        return 'person';
      case UserType.serviceProvider:
        return 'build';
      case UserType.admin:
        return 'admin_panel_settings';
    }
  }
}
