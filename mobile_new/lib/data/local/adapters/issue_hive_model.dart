import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../domain/enums/issue_priority.dart';
import '../../../domain/enums/issue_status.dart';
import '../../../domain/enums/sync_status.dart';
import '../../models/issue_model.dart';

/// Hive model for storing issues locally
/// Used for offline-first functionality
@HiveType(typeId: 1)
class IssueHiveModel extends HiveObject {
  /// Server ID (null for locally created issues)
  @HiveField(0)
  int? serverId;

  /// Local UUID for tracking before server sync
  @HiveField(1)
  String localId;

  /// Issue title
  @HiveField(2)
  String title;

  /// Issue description
  @HiveField(3)
  String? description;

  /// Status value string
  @HiveField(4)
  String status;

  /// Priority value string
  @HiveField(5)
  String priority;

  /// Category IDs for this issue
  @HiveField(6)
  List<int> categoryIds;

  /// Location latitude
  @HiveField(7)
  double? latitude;

  /// Location longitude
  @HiveField(8)
  double? longitude;

  /// Location address (from reverse geocoding)
  @HiveField(15)
  String? address;

  /// Local media file paths (before upload)
  @HiveField(9)
  List<String> localMediaPaths;

  /// Sync status value string
  @HiveField(10)
  String syncStatus;

  /// Created timestamp
  @HiveField(11)
  DateTime createdAt;

  /// Last synced timestamp
  @HiveField(12)
  DateTime? syncedAt;

  /// Tenant ID
  @HiveField(13)
  int? tenantId;

  /// Full JSON data for complete model restoration
  @HiveField(14)
  String? fullDataJson;

  IssueHiveModel({
    this.serverId,
    required this.localId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.categoryIds,
    this.latitude,
    this.longitude,
    this.address,
    this.localMediaPaths = const [],
    required this.syncStatus,
    required this.createdAt,
    this.syncedAt,
    this.tenantId,
    this.fullDataJson,
  });

  /// Get the effective ID (server ID or negative local ID)
  int get effectiveId => serverId ?? -localId.hashCode.abs();

  /// Get status as enum
  IssueStatus get statusEnum =>
      IssueStatus.fromValue(status) ?? IssueStatus.pending;

  /// Get priority as enum
  IssuePriority get priorityEnum =>
      IssuePriority.fromValue(priority) ?? IssuePriority.medium;

  /// Get sync status as enum
  SyncStatus get syncStatusEnum =>
      SyncStatus.fromValue(syncStatus) ?? SyncStatus.pending;

  /// Check if needs sync
  bool get needsSync => syncStatusEnum.needsSync;

  /// Check if synced
  bool get isSynced => syncStatusEnum == SyncStatus.synced;

  /// Create from IssueModel
  factory IssueHiveModel.fromModel(IssueModel model, {String? localId}) {
    return IssueHiveModel(
      serverId: model.id > 0 ? model.id : null,
      localId: localId ?? model.localId ?? '',
      title: model.title,
      description: model.description,
      status: model.status.value,
      priority: model.priority.value,
      categoryIds: model.categories.map((c) => c.id).toList(),
      latitude: model.latitude,
      longitude: model.longitude,
      address: model.address,
      localMediaPaths: [],
      syncStatus: model.syncStatus.value,
      createdAt: model.createdAt ?? DateTime.now(),
      syncedAt: model.syncStatus == SyncStatus.synced ? DateTime.now() : null,
      tenantId: model.tenantId,
      fullDataJson: jsonEncode(model.toJson()),
    );
  }

  /// Create for a new local issue
  factory IssueHiveModel.createLocal({
    required String localId,
    required String title,
    String? description,
    required List<int> categoryIds,
    IssuePriority priority = IssuePriority.medium,
    double? latitude,
    double? longitude,
    String? address,
    List<String> localMediaPaths = const [],
    int? tenantId,
  }) {
    return IssueHiveModel(
      localId: localId,
      title: title,
      description: description,
      status: IssueStatus.pending.value,
      priority: priority.value,
      categoryIds: categoryIds,
      latitude: latitude,
      longitude: longitude,
      address: address,
      localMediaPaths: localMediaPaths,
      syncStatus: SyncStatus.pending.value,
      createdAt: DateTime.now(),
      tenantId: tenantId,
    );
  }

  /// Convert to IssueModel
  /// IMPORTANT: When fullDataJson exists, we still use local fields for
  /// any data that can be modified offline (status, priority)
  IssueModel toModel() {
    // If we have full data, restore from it but overlay local changes
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return IssueModel.fromJson(json).copyWith(
          syncStatus: syncStatusEnum,
          localId: localId,
          // CRITICAL: Use local fields for offline-modifiable data
          status: statusEnum,  // For offline cancel
          priority: priorityEnum,  // If priority can be changed offline
        );
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return IssueModel(
      id: effectiveId,
      tenantId: tenantId ?? 0,
      title: title,
      description: description,
      status: statusEnum,
      priority: priorityEnum,
      latitude: latitude,
      longitude: longitude,
      address: address,
      createdAt: createdAt,
      localId: localId,
      syncStatus: syncStatusEnum,
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

  /// Update full data from server response
  void updateFromServer(IssueModel model) {
    serverId = model.id;
    title = model.title;
    description = model.description;
    status = model.status.value;
    priority = model.priority.value;
    categoryIds = model.categories.map((c) => c.id).toList();
    latitude = model.latitude;
    longitude = model.longitude;
    address = model.address;
    syncStatus = SyncStatus.synced.value;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
  }
}
