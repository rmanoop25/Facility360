import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../domain/enums/sync_status.dart';
import '../../models/category_model.dart';
import '../../models/service_provider_model.dart';
import '../../models/time_slot_model.dart';

/// Hive model for storing service providers locally
/// Used for offline-first functionality with full CRUD support
@HiveType(typeId: 6)
class ServiceProviderHiveModel extends HiveObject {
  /// Server ID (null for locally created service providers)
  @HiveField(0)
  int? serverId;

  /// Local UUID for tracking before server sync
  @HiveField(1)
  String localId;

  /// User ID
  @HiveField(2)
  int? userId;

  /// Category IDs
  @HiveField(3)
  List<int> categoryIds;

  /// Location latitude
  @HiveField(4)
  double? latitude;

  /// Location longitude
  @HiveField(5)
  double? longitude;

  /// Availability status
  @HiveField(6)
  bool isAvailable;

  /// User name
  @HiveField(7)
  String? userName;

  /// User email
  @HiveField(8)
  String? userEmail;

  /// User phone
  @HiveField(9)
  String? userPhone;

  /// Active jobs count
  @HiveField(10)
  int activeJobs;

  /// Rating
  @HiveField(11)
  double? rating;

  /// Categories JSON (serialized list)
  @HiveField(12)
  String? categoriesJson;

  /// Time slots JSON (serialized list)
  @HiveField(13)
  String? timeSlotsJson;

  /// Sync status value string
  @HiveField(14)
  String syncStatus;

  /// Created timestamp
  @HiveField(15)
  DateTime createdAt;

  /// Last synced timestamp
  @HiveField(16)
  DateTime? syncedAt;

  /// Full JSON data for complete model restoration
  @HiveField(17)
  String? fullDataJson;

  /// Flag for soft delete (pending sync)
  @HiveField(18)
  bool isDeleted;

  /// User is active status (account active/inactive)
  @HiveField(19)
  bool userIsActive;

  ServiceProviderHiveModel({
    this.serverId,
    required this.localId,
    this.userId,
    this.categoryIds = const [],
    this.latitude,
    this.longitude,
    this.isAvailable = true,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.activeJobs = 0,
    this.rating,
    this.categoriesJson,
    this.timeSlotsJson,
    required this.syncStatus,
    required this.createdAt,
    this.syncedAt,
    this.fullDataJson,
    this.isDeleted = false,
    this.userIsActive = true,
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

  /// Get display name
  String get displayName => userName ?? 'Service Provider #$effectiveId';

  /// Check if has location
  bool get hasLocation => latitude != null && longitude != null;

  /// Get categories from JSON
  List<CategoryModel> get categories {
    if (categoriesJson == null) return [];
    try {
      final list = jsonDecode(categoriesJson!) as List;
      return list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get time slots from JSON
  List<TimeSlotModel> get timeSlots {
    if (timeSlotsJson == null) return [];
    try {
      final list = jsonDecode(timeSlotsJson!) as List;
      return list
          .map((e) => TimeSlotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Create from ServiceProviderModel
  factory ServiceProviderHiveModel.fromModel(ServiceProviderModel model,
      {String? localId}) {
    return ServiceProviderHiveModel(
      serverId: model.id > 0 ? model.id : null,
      localId: localId ?? model.id.toString(),
      userId: model.userId,
      categoryIds: model.categoryIds,
      latitude: model.latitude,
      longitude: model.longitude,
      isAvailable: model.isAvailable,
      userName: model.userName,
      userEmail: model.userEmail,
      userPhone: model.userPhone,
      activeJobs: model.activeJobs,
      rating: model.rating,
      categoriesJson: model.categories.isNotEmpty
          ? jsonEncode(model.categories.map((c) => c.toJson()).toList())
          : null,
      timeSlotsJson: model.timeSlots.isNotEmpty
          ? jsonEncode(model.timeSlots.map((t) => t.toJson()).toList())
          : null,
      syncStatus: SyncStatus.synced.value,
      createdAt: model.createdAt ?? DateTime.now(),
      syncedAt: DateTime.now(),
      fullDataJson: jsonEncode(model.toJson()),
      userIsActive: model.userIsActive ?? true,
    );
  }

  /// Create for a new local service provider (admin creating offline)
  factory ServiceProviderHiveModel.createLocal({
    required String localId,
    required String userName,
    required String userEmail,
    String? userPhone,
    required List<int> categoryIds,
    double? latitude,
    double? longitude,
    bool isAvailable = true,
  }) {
    return ServiceProviderHiveModel(
      localId: localId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      categoryIds: categoryIds,
      latitude: latitude,
      longitude: longitude,
      isAvailable: isAvailable,
      syncStatus: SyncStatus.pending.value,
      createdAt: DateTime.now(),
    );
  }

  /// Convert to ServiceProviderModel
  /// IMPORTANT: When fullDataJson exists, we still use local fields for
  /// any data that can be modified offline (user details, availability)
  ServiceProviderModel toModel() {
    // If we have full data, restore from it but overlay local changes
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return ServiceProviderModel.fromJson(json).copyWith(
          // CRITICAL: Use local fields for offline-modifiable data
          userName: userName,
          userEmail: userEmail,
          userPhone: userPhone,
          isAvailable: isAvailable,
          categoryIds: categoryIds,
          latitude: latitude,
          longitude: longitude,
        );
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return ServiceProviderModel(
      id: effectiveId,
      userId: userId,
      categoryIds: categoryIds,
      latitude: latitude,
      longitude: longitude,
      isAvailable: isAvailable,
      createdAt: createdAt,
      categories: categories,
      timeSlots: timeSlots,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      activeJobs: activeJobs,
      rating: rating,
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
  void updateFromServer(ServiceProviderModel model) {
    serverId = model.id;
    userId = model.userId;
    categoryIds = model.categoryIds;
    latitude = model.latitude;
    longitude = model.longitude;
    isAvailable = model.isAvailable;
    userName = model.userName;
    userEmail = model.userEmail;
    userPhone = model.userPhone;
    activeJobs = model.activeJobs;
    rating = model.rating;
    userIsActive = model.userIsActive ?? true;
    categoriesJson = model.categories.isNotEmpty
        ? jsonEncode(model.categories.map((c) => c.toJson()).toList())
        : null;
    timeSlotsJson = model.timeSlots.isNotEmpty
        ? jsonEncode(model.timeSlots.map((t) => t.toJson()).toList())
        : null;
    syncStatus = SyncStatus.synced.value;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
  }

  /// Update locally (for offline edits)
  void updateLocally({
    String? userName,
    String? userEmail,
    String? userPhone,
    List<int>? categoryIds,
    double? latitude,
    double? longitude,
    bool? isAvailable,
    bool? userIsActive,
  }) {
    if (userName != null) this.userName = userName;
    if (userEmail != null) this.userEmail = userEmail;
    if (userPhone != null) this.userPhone = userPhone;
    if (categoryIds != null) this.categoryIds = categoryIds;
    if (latitude != null) this.latitude = latitude;
    if (longitude != null) this.longitude = longitude;
    if (isAvailable != null) this.isAvailable = isAvailable;
    if (userIsActive != null) this.userIsActive = userIsActive;
    syncStatus = SyncStatus.pending.value;
  }

  /// Toggle availability locally
  void toggleAvailability() {
    isAvailable = !isAvailable;
    syncStatus = SyncStatus.pending.value;
  }

  /// Mark as deleted (soft delete for sync)
  void markAsDeleted() {
    isDeleted = true;
    syncStatus = SyncStatus.pending.value;
  }
}
