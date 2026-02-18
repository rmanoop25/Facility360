import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/category_model.dart';

/// Hive model for storing categories locally with hierarchy support
/// Used for offline-first functionality (master data - server wins)
@HiveType(typeId: 7)
class CategoryHiveModel extends HiveObject {
  /// Server ID (always has server ID for master data)
  @HiveField(0)
  int serverId;

  /// Category name in English
  @HiveField(1)
  String nameEn;

  /// Category name in Arabic
  @HiveField(2)
  String nameAr;

  /// Description in English
  @HiveField(3)
  String? descriptionEn;

  /// Description in Arabic
  @HiveField(4)
  String? descriptionAr;

  /// Icon name
  @HiveField(5)
  String? icon;

  /// Color hex code
  @HiveField(6)
  String? color;

  /// Sort order
  @HiveField(7)
  int sortOrder;

  /// Active status
  @HiveField(8)
  bool isActive;

  /// Last synced timestamp
  @HiveField(9)
  DateTime syncedAt;

  /// Full JSON data for complete model restoration
  @HiveField(10)
  String? fullDataJson;

  /// Stats - consumables count
  @HiveField(11)
  int? consumablesCount;

  /// Stats - service providers count
  @HiveField(12)
  int? serviceProvidersCount;

  /// Stats - issues count
  @HiveField(13)
  int? issuesCount;

  // =========================================================================
  // Hierarchy fields (14-19)
  // =========================================================================

  /// Parent category ID (null for root categories)
  @HiveField(14)
  int? parentId;

  /// Depth level (0 = root)
  @HiveField(15)
  int depth;

  /// Materialized path (e.g., "1/5/12")
  @HiveField(16)
  String? path;

  /// Whether this is a root category
  @HiveField(17)
  bool isRoot;

  /// Number of direct children
  @HiveField(18)
  int? childrenCount;

  /// Whether this category has children
  @HiveField(19)
  bool? hasChildren;

  CategoryHiveModel({
    required this.serverId,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    this.icon,
    this.color,
    required this.sortOrder,
    required this.isActive,
    required this.syncedAt,
    this.fullDataJson,
    this.consumablesCount,
    this.serviceProvidersCount,
    this.issuesCount,
    // Hierarchy fields
    this.parentId,
    this.depth = 0,
    this.path,
    this.isRoot = true,
    this.childrenCount,
    this.hasChildren,
  });

  /// Get localized name based on locale
  String localizedName(String locale) => locale == 'ar' ? nameAr : nameEn;

  /// Check if this is a leaf category (no children)
  bool get isLeaf => hasChildren == false || (childrenCount ?? 0) == 0;

  /// Create from CategoryModel
  factory CategoryHiveModel.fromModel(CategoryModel model) {
    return CategoryHiveModel(
      serverId: model.id,
      nameEn: model.nameEn,
      nameAr: model.nameAr,
      descriptionEn: model.descriptionEn,
      descriptionAr: model.descriptionAr,
      icon: model.icon,
      color: model.color,
      sortOrder: model.sortOrder,
      isActive: model.isActive,
      syncedAt: DateTime.now(),
      fullDataJson: jsonEncode(model.toJson()),
      consumablesCount: model.consumablesCount,
      serviceProvidersCount: model.serviceProvidersCount,
      issuesCount: model.issuesCount,
      // Hierarchy fields
      parentId: model.parentId,
      depth: model.depth,
      path: model.path,
      isRoot: model.isRoot,
      childrenCount: model.childrenCount,
      hasChildren: model.hasChildren,
    );
  }

  /// Convert to CategoryModel
  CategoryModel toModel() {
    // If we have full data, restore from it
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return CategoryModel.fromJson(json);
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return CategoryModel(
      id: serverId,
      nameEn: nameEn,
      nameAr: nameAr,
      descriptionEn: descriptionEn,
      descriptionAr: descriptionAr,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      isActive: isActive,
      consumablesCount: consumablesCount,
      serviceProvidersCount: serviceProvidersCount,
      issuesCount: issuesCount,
      // Hierarchy fields
      parentId: parentId,
      depth: depth,
      path: path,
      isRoot: isRoot,
      childrenCount: childrenCount,
      hasChildren: hasChildren,
    );
  }

  /// Update from server (server-wins strategy)
  void updateFromServer(CategoryModel model) {
    nameEn = model.nameEn;
    nameAr = model.nameAr;
    descriptionEn = model.descriptionEn;
    descriptionAr = model.descriptionAr;
    icon = model.icon;
    color = model.color;
    sortOrder = model.sortOrder;
    isActive = model.isActive;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
    consumablesCount = model.consumablesCount;
    serviceProvidersCount = model.serviceProvidersCount;
    issuesCount = model.issuesCount;
    // Hierarchy fields
    parentId = model.parentId;
    depth = model.depth;
    path = model.path;
    isRoot = model.isRoot;
    childrenCount = model.childrenCount;
    hasChildren = model.hasChildren;
  }
}
