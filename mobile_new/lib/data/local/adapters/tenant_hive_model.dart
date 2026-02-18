import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../domain/enums/sync_status.dart';
import '../../models/tenant_model.dart';

/// Hive model for storing tenants locally
/// Used for offline-first functionality with full CRUD support
@HiveType(typeId: 5)
class TenantHiveModel extends HiveObject {
  /// Server ID (null for locally created tenants)
  @HiveField(0)
  int? serverId;

  /// Local UUID for tracking before server sync
  @HiveField(1)
  String localId;

  /// User ID
  @HiveField(2)
  int? userId;

  /// Unit number
  @HiveField(3)
  String? unitNumber;

  /// Building name
  @HiveField(4)
  String? buildingName;

  /// Floor
  @HiveField(5)
  String? floor;

  /// User name
  @HiveField(6)
  String? userName;

  /// User email
  @HiveField(7)
  String? userEmail;

  /// User phone
  @HiveField(8)
  String? userPhone;

  /// User active status
  @HiveField(9)
  bool userIsActive;

  /// User locale
  @HiveField(10)
  String? userLocale;

  /// Issues count (stats)
  @HiveField(11)
  int? issuesCount;

  /// Sync status value string
  @HiveField(12)
  String syncStatus;

  /// Created timestamp
  @HiveField(13)
  DateTime createdAt;

  /// Last synced timestamp
  @HiveField(14)
  DateTime? syncedAt;

  /// Full JSON data for complete model restoration
  @HiveField(15)
  String? fullDataJson;

  /// Flag for soft delete (pending sync)
  @HiveField(16)
  bool isDeleted;

  TenantHiveModel({
    this.serverId,
    required this.localId,
    this.userId,
    this.unitNumber,
    this.buildingName,
    this.floor,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userIsActive = true,
    this.userLocale,
    this.issuesCount,
    required this.syncStatus,
    required this.createdAt,
    this.syncedAt,
    this.fullDataJson,
    this.isDeleted = false,
  });

  /// Get the effective ID (server ID or negative local ID hash)
  int get effectiveId => serverId ?? -localId.hashCode.abs();

  /// Get sync status as enum
  SyncStatus get syncStatusEnum =>
      SyncStatus.fromValue(syncStatus) ?? SyncStatus.pending;

  /// Check if needs sync
  bool get needsSync => syncStatusEnum.needsSync;

  /// Check if synced
  bool get isSynced => syncStatusEnum == SyncStatus.synced;

  /// Get full address
  String get fullAddress {
    final parts = <String>[];
    if (unitNumber != null && unitNumber!.isNotEmpty) {
      parts.add('Unit $unitNumber');
    }
    if (buildingName != null && buildingName!.isNotEmpty) {
      parts.add(buildingName!);
    }
    return parts.join(', ');
  }

  /// Create from TenantModel
  factory TenantHiveModel.fromModel(TenantModel model, {String? localId}) {
    return TenantHiveModel(
      serverId: model.id > 0 ? model.id : null,
      localId: localId ?? model.id.toString(),
      userId: model.userId,
      unitNumber: model.unitNumber,
      buildingName: model.buildingName,
      userName: model.userName,
      userEmail: model.userEmail,
      userPhone: model.userPhone,
      userIsActive: model.userIsActive,
      userLocale: model.userLocale,
      issuesCount: model.issuesCount,
      syncStatus: SyncStatus.synced.value,
      createdAt: model.createdAt ?? DateTime.now(),
      syncedAt: DateTime.now(),
      fullDataJson: jsonEncode(model.toJson()),
    );
  }

  /// Create for a new local tenant (admin creating offline)
  factory TenantHiveModel.createLocal({
    required String localId,
    required String userName,
    required String userEmail,
    String? userPhone,
    String? unitNumber,
    String? buildingName,
    bool userIsActive = true,
  }) {
    return TenantHiveModel(
      localId: localId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      unitNumber: unitNumber,
      buildingName: buildingName,
      userIsActive: userIsActive,
      syncStatus: SyncStatus.pending.value,
      createdAt: DateTime.now(),
    );
  }

  /// Convert to TenantModel
  /// IMPORTANT: When fullDataJson exists, we still use local fields for
  /// any data that can be modified offline (user details, unit info)
  TenantModel toModel() {
    // If we have full data, restore from it but overlay local changes
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return TenantModel.fromJson(json).copyWith(
          // CRITICAL: Use local fields for offline-modifiable data
          userName: userName,
          userEmail: userEmail,
          userPhone: userPhone,
          unitNumber: unitNumber,
          buildingName: buildingName,
          userIsActive: userIsActive,
        );
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return TenantModel(
      id: effectiveId,
      userId: userId,
      unitNumber: unitNumber,
      buildingName: buildingName,
      createdAt: createdAt,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      userIsActive: userIsActive,
      userLocale: userLocale,
      issuesCount: issuesCount,
    );
  }

  /// Mark as synced with server ID
  void markAsSynced(int serverId) {
    this.serverId = serverId;
    syncStatus = SyncStatus.synced.value;
    syncedAt = DateTime.now();
  }

  /// Mark as failed
  void markAsFailed() {
    syncStatus = SyncStatus.failed.value;
  }

  /// Mark as syncing
  void markAsSyncing() {
    syncStatus = SyncStatus.syncing.value;
  }

  /// Mark as pending (for local updates)
  void markAsPending() {
    syncStatus = SyncStatus.pending.value;
  }

  /// Update from server response
  void updateFromServer(TenantModel model) {
    serverId = model.id;
    userId = model.userId;
    unitNumber = model.unitNumber;
    buildingName = model.buildingName;
    userName = model.userName;
    userEmail = model.userEmail;
    userPhone = model.userPhone;
    userIsActive = model.userIsActive;
    userLocale = model.userLocale;
    issuesCount = model.issuesCount;
    syncStatus = SyncStatus.synced.value;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
  }

  /// Update locally (for offline edits)
  void updateLocally({
    String? userName,
    String? userEmail,
    String? userPhone,
    String? unitNumber,
    String? buildingName,
    bool? userIsActive,
  }) {
    if (userName != null) this.userName = userName;
    if (userEmail != null) this.userEmail = userEmail;
    if (userPhone != null) this.userPhone = userPhone;
    if (unitNumber != null) this.unitNumber = unitNumber;
    if (buildingName != null) this.buildingName = buildingName;
    if (userIsActive != null) this.userIsActive = userIsActive;
    syncStatus = SyncStatus.pending.value;
  }

  /// Mark as deleted (soft delete for sync)
  void markAsDeleted() {
    isDeleted = true;
    syncStatus = SyncStatus.pending.value;
  }
}
