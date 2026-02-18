import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/work_type_model.dart';

/// Hive model for storing work types locally
/// Used for offline-first functionality (master data - server wins)
@HiveType(typeId: 13)
class WorkTypeHiveModel extends HiveObject {
  /// Server ID (always has server ID for master data)
  @HiveField(0)
  int serverId;

  /// Work type name in English
  @HiveField(1)
  String nameEn;

  /// Work type name in Arabic
  @HiveField(2)
  String nameAr;

  /// Description in English
  @HiveField(3)
  String? descriptionEn;

  /// Description in Arabic
  @HiveField(4)
  String? descriptionAr;

  /// Duration in minutes
  @HiveField(5)
  int durationMinutes;

  /// Active status
  @HiveField(6)
  bool isActive;

  /// Category IDs this work type belongs to
  @HiveField(7)
  List<int> categoryIds;

  /// Last synced timestamp
  @HiveField(8)
  DateTime syncedAt;

  WorkTypeHiveModel({
    required this.serverId,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    required this.durationMinutes,
    this.isActive = true,
    required this.categoryIds,
    required this.syncedAt,
  });

  /// Get localized name based on locale
  String localizedName(String locale) => locale == 'ar' ? nameAr : nameEn;

  /// Get localized description based on locale
  String? localizedDescription(String locale) =>
      locale == 'ar' ? descriptionAr : descriptionEn;

  /// Create from WorkTypeModel
  factory WorkTypeHiveModel.fromModel(WorkTypeModel model) {
    return WorkTypeHiveModel(
      serverId: model.id,
      nameEn: model.nameEn,
      nameAr: model.nameAr,
      descriptionEn: model.descriptionEn,
      descriptionAr: model.descriptionAr,
      durationMinutes: model.durationMinutes,
      isActive: model.isActive,
      categoryIds: model.categoryIds,
      syncedAt: DateTime.now(),
    );
  }

  /// Convert to WorkTypeModel
  WorkTypeModel toModel() {
    return WorkTypeModel(
      id: serverId,
      nameEn: nameEn,
      nameAr: nameAr,
      descriptionEn: descriptionEn,
      descriptionAr: descriptionAr,
      durationMinutes: durationMinutes,
      isActive: isActive,
      categoryIds: categoryIds,
    );
  }

  /// Update from server (server-wins strategy)
  void updateFromServer(WorkTypeModel model) {
    nameEn = model.nameEn;
    nameAr = model.nameAr;
    descriptionEn = model.descriptionEn;
    descriptionAr = model.descriptionAr;
    durationMinutes = model.durationMinutes;
    isActive = model.isActive;
    categoryIds = model.categoryIds;
    syncedAt = DateTime.now();
  }
}
