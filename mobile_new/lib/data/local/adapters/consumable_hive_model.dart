import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/consumable_model.dart';

/// Hive model for storing consumables locally
/// Used for offline-first functionality (master data - server wins)
@HiveType(typeId: 8)
class ConsumableHiveModel extends HiveObject {
  /// Server ID (always has server ID for master data)
  @HiveField(0)
  int serverId;

  /// Category ID
  @HiveField(1)
  int? categoryId;

  /// Consumable name in English
  @HiveField(2)
  String nameEn;

  /// Consumable name in Arabic
  @HiveField(3)
  String nameAr;

  /// Active status
  @HiveField(4)
  bool isActive;

  /// Last synced timestamp
  @HiveField(5)
  DateTime syncedAt;

  /// Full JSON data for complete model restoration
  @HiveField(6)
  String? fullDataJson;

  ConsumableHiveModel({
    required this.serverId,
    this.categoryId,
    required this.nameEn,
    required this.nameAr,
    required this.isActive,
    required this.syncedAt,
    this.fullDataJson,
  });

  /// Get localized name based on locale
  String localizedName(String locale) => locale == 'ar' ? nameAr : nameEn;

  /// Create from ConsumableModel
  factory ConsumableHiveModel.fromModel(ConsumableModel model) {
    return ConsumableHiveModel(
      serverId: model.id,
      categoryId: model.categoryId,
      nameEn: model.nameEn,
      nameAr: model.nameAr,
      isActive: model.isActive,
      syncedAt: DateTime.now(),
      fullDataJson: jsonEncode(model.toJson()),
    );
  }

  /// Convert to ConsumableModel
  ConsumableModel toModel() {
    // If we have full data, restore from it
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return ConsumableModel.fromJson(json);
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return ConsumableModel(
      id: serverId,
      categoryId: categoryId,
      nameEn: nameEn,
      nameAr: nameAr,
      isActive: isActive,
    );
  }

  /// Update from server (server-wins strategy)
  void updateFromServer(ConsumableModel model) {
    categoryId = model.categoryId;
    nameEn = model.nameEn;
    nameAr = model.nameAr;
    isActive = model.isActive;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
  }
}
