import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../domain/enums/user_role.dart';
import '../../models/user_model.dart';

/// Hive model for storing users locally
/// Used for caching current user and known users for offline access
@HiveType(typeId: 4)
class UserHiveModel extends HiveObject {
  /// Server ID
  @HiveField(0)
  int serverId;

  /// User name
  @HiveField(1)
  String name;

  /// User email
  @HiveField(2)
  String email;

  /// User phone
  @HiveField(3)
  String? phone;

  /// Profile photo URL
  @HiveField(4)
  String? profilePhoto;

  /// FCM token
  @HiveField(5)
  String? fcmToken;

  /// User locale (en/ar)
  @HiveField(6)
  String locale;

  /// Active status
  @HiveField(7)
  bool isActive;

  /// Roles list (JSON serialized)
  @HiveField(8)
  String rolesJson;

  /// Permissions list (JSON serialized)
  @HiveField(9)
  String permissionsJson;

  /// Is tenant flag
  @HiveField(10)
  bool? isTenant;

  /// Is service provider flag
  @HiveField(11)
  bool? isServiceProvider;

  /// Is admin flag
  @HiveField(12)
  bool? isAdmin;

  /// Tenant data (JSON serialized)
  @HiveField(13)
  String? tenantJson;

  /// Service provider data (JSON serialized)
  @HiveField(14)
  String? serviceProviderJson;

  /// Last synced timestamp
  @HiveField(15)
  DateTime syncedAt;

  /// Full JSON data for complete model restoration
  @HiveField(16)
  String? fullDataJson;

  /// Is this the current logged-in user
  @HiveField(17)
  bool isCurrentUser;

  UserHiveModel({
    required this.serverId,
    required this.name,
    required this.email,
    this.phone,
    this.profilePhoto,
    this.fcmToken,
    required this.locale,
    required this.isActive,
    required this.rolesJson,
    required this.permissionsJson,
    this.isTenant,
    this.isServiceProvider,
    this.isAdmin,
    this.tenantJson,
    this.serviceProviderJson,
    required this.syncedAt,
    this.fullDataJson,
    this.isCurrentUser = false,
  });

  /// Get roles list
  List<String> get roles {
    try {
      return (jsonDecode(rolesJson) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Get permissions list
  List<String> get permissions {
    try {
      return (jsonDecode(permissionsJson) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Get user role
  UserRole get role {
    if (isTenant == true) return UserRole.tenant;
    if (isServiceProvider == true) return UserRole.serviceProvider;
    if (isAdmin == true) {
      if (roles.contains('super_admin')) return UserRole.superAdmin;
      if (roles.contains('manager')) return UserRole.manager;
      if (roles.contains('viewer')) return UserRole.viewer;
      return UserRole.superAdmin;
    }
    return UserRole.tenant;
  }

  /// Create from UserModel
  factory UserHiveModel.fromModel(UserModel model, {bool isCurrentUser = false}) {
    return UserHiveModel(
      serverId: model.id,
      name: model.name,
      email: model.email,
      phone: model.phone,
      profilePhoto: model.profilePhoto,
      fcmToken: model.fcmToken,
      locale: model.locale,
      isActive: model.isActive,
      rolesJson: jsonEncode(model.roles),
      permissionsJson: jsonEncode(model.permissions),
      isTenant: model.isTenant,
      isServiceProvider: model.isServiceProvider,
      isAdmin: model.isAdmin,
      tenantJson: model.tenant != null ? jsonEncode(model.tenant!.toJson()) : null,
      serviceProviderJson: model.serviceProvider != null
          ? jsonEncode(model.serviceProvider!.toJson())
          : null,
      syncedAt: DateTime.now(),
      fullDataJson: jsonEncode(model.toJson()),
      isCurrentUser: isCurrentUser,
    );
  }

  /// Convert to UserModel
  UserModel toModel() {
    // If we have full data, restore from it
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return UserModel.fromJson(json);
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return UserModel(
      id: serverId,
      name: name,
      email: email,
      phone: phone,
      profilePhoto: profilePhoto,
      fcmToken: fcmToken,
      locale: locale,
      isActive: isActive,
      roles: roles,
      permissions: permissions,
      isTenantFlag: isTenant,
      isServiceProviderFlag: isServiceProvider,
      isAdminFlag: isAdmin,
    );
  }

  /// Update from server response
  void updateFromServer(UserModel model) {
    name = model.name;
    email = model.email;
    phone = model.phone;
    profilePhoto = model.profilePhoto;
    fcmToken = model.fcmToken;
    locale = model.locale;
    isActive = model.isActive;
    rolesJson = jsonEncode(model.roles);
    permissionsJson = jsonEncode(model.permissions);
    isTenant = model.isTenant;
    isServiceProvider = model.isServiceProvider;
    isAdmin = model.isAdmin;
    tenantJson = model.tenant != null ? jsonEncode(model.tenant!.toJson()) : null;
    serviceProviderJson = model.serviceProvider != null
        ? jsonEncode(model.serviceProvider!.toJson())
        : null;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
  }
}
