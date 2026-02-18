import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/category_hive_model.dart';
import '../models/category_model.dart';

/// Local data source for category operations using Hive
/// Master data - uses server-wins conflict resolution
/// Supports hierarchical categories with parent-child relationships
class CategoryLocalDataSource {
  static const String _boxName = 'categories';

  /// Get or open the categories box
  Future<Box<CategoryHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<CategoryHiveModel>(_boxName);
    }
    return Hive.openBox<CategoryHiveModel>(_boxName);
  }

  /// Save a category to local storage
  Future<void> saveCategory(CategoryHiveModel category) async {
    final box = await _getBox();
    await box.put(category.serverId.toString(), category);
    debugPrint('CategoryLocalDataSource: Saved category ${category.serverId}');
  }

  /// Save multiple categories to local storage
  Future<void> saveCategories(List<CategoryHiveModel> categories) async {
    final box = await _getBox();
    final map = {for (var cat in categories) cat.serverId.toString(): cat};
    await box.putAll(map);
    debugPrint('CategoryLocalDataSource: Saved ${categories.length} categories');
  }

  /// Get all categories from local storage (sorted by path for hierarchy display)
  Future<List<CategoryHiveModel>> getAllCategories() async {
    final box = await _getBox();
    final categories = box.values.toList();
    // Sort by path for proper hierarchy order, then by sortOrder within same level
    categories.sort((a, b) {
      final pathCompare = (a.path ?? '').compareTo(b.path ?? '');
      if (pathCompare != 0) return pathCompare;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return categories;
  }

  /// Get active categories only (sorted by hierarchy)
  Future<List<CategoryHiveModel>> getActiveCategories() async {
    final box = await _getBox();
    final categories = box.values.where((cat) => cat.isActive).toList();
    categories.sort((a, b) {
      final pathCompare = (a.path ?? '').compareTo(b.path ?? '');
      if (pathCompare != 0) return pathCompare;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return categories;
  }

  /// Get a category by server ID
  Future<CategoryHiveModel?> getCategoryById(int serverId) async {
    final box = await _getBox();
    return box.get(serverId.toString());
  }

  /// Search categories by name
  Future<List<CategoryHiveModel>> searchCategories(String query, String locale) async {
    final box = await _getBox();
    final lowerQuery = query.toLowerCase();
    return box.values.where((cat) {
      final name = cat.localizedName(locale).toLowerCase();
      return name.contains(lowerQuery);
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // =========================================================================
  // Hierarchy Methods
  // =========================================================================

  /// Get root categories only (no parent)
  Future<List<CategoryHiveModel>> getRootCategories({bool activeOnly = true}) async {
    final box = await _getBox();
    var categories = box.values.where((cat) => cat.isRoot || cat.parentId == null);
    if (activeOnly) {
      categories = categories.where((cat) => cat.isActive);
    }
    return categories.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get children of a specific category
  Future<List<CategoryHiveModel>> getChildrenOf(int parentId, {bool activeOnly = true}) async {
    final box = await _getBox();
    var categories = box.values.where((cat) => cat.parentId == parentId);
    if (activeOnly) {
      categories = categories.where((cat) => cat.isActive);
    }
    return categories.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get all descendants of a category (using path)
  Future<List<CategoryHiveModel>> getDescendantsOf(int categoryId, {bool activeOnly = true}) async {
    final box = await _getBox();
    final category = await getCategoryById(categoryId);
    if (category == null) return [];

    final categoryPath = category.path ?? categoryId.toString();
    var descendants = box.values.where((cat) {
      final catPath = cat.path ?? '';
      return catPath.startsWith('$categoryPath/');
    });

    if (activeOnly) {
      descendants = descendants.where((cat) => cat.isActive);
    }

    return descendants.toList()..sort((a, b) => (a.path ?? '').compareTo(b.path ?? ''));
  }

  /// Get ancestors of a category (ordered from root to immediate parent)
  Future<List<CategoryHiveModel>> getAncestorsOf(int categoryId) async {
    final box = await _getBox();
    final ancestors = <CategoryHiveModel>[];

    var currentId = categoryId;
    var visited = <int>{}; // Prevent infinite loops

    while (true) {
      final category = box.get(currentId.toString());
      if (category == null || category.parentId == null) break;
      if (visited.contains(category.parentId)) break; // Circular reference protection
      visited.add(category.parentId!);

      final parent = box.get(category.parentId.toString());
      if (parent == null) break;

      ancestors.insert(0, parent);
      currentId = parent.serverId;
    }

    return ancestors;
  }

  /// Get leaf categories (categories without children)
  Future<List<CategoryHiveModel>> getLeafCategories({bool activeOnly = true}) async {
    final box = await _getBox();
    final categories = box.values.toList();

    // Build set of parent IDs
    final parentIds = categories
        .map((c) => c.parentId)
        .whereType<int>()
        .toSet();

    // Filter categories that are not parents
    var leaves = categories.where((cat) => !parentIds.contains(cat.serverId));

    if (activeOnly) {
      leaves = leaves.where((cat) => cat.isActive);
    }

    return leaves.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get categories at a specific depth level
  Future<List<CategoryHiveModel>> getCategoriesAtDepth(int depth, {bool activeOnly = true}) async {
    final box = await _getBox();
    var categories = box.values.where((cat) => cat.depth == depth);
    if (activeOnly) {
      categories = categories.where((cat) => cat.isActive);
    }
    return categories.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Build a category tree map (parent ID -> list of children)
  Future<Map<int?, List<CategoryHiveModel>>> buildCategoryTree({bool activeOnly = true}) async {
    final box = await _getBox();
    final tree = <int?, List<CategoryHiveModel>>{};

    var categories = box.values.toList();
    if (activeOnly) {
      categories = categories.where((cat) => cat.isActive).toList();
    }

    for (final category in categories) {
      tree.putIfAbsent(category.parentId, () => []).add(category);
    }

    // Sort each level by sortOrder
    for (final children in tree.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return tree;
  }

  /// Get the full path of category names (for breadcrumb display)
  Future<List<String>> getCategoryPath(int categoryId, String locale) async {
    final ancestors = await getAncestorsOf(categoryId);
    final category = await getCategoryById(categoryId);

    final path = ancestors.map((a) => a.localizedName(locale)).toList();
    if (category != null) {
      path.add(category.localizedName(locale));
    }

    return path;
  }

  // =========================================================================
  // Standard CRUD Methods (continued)
  // =========================================================================

  /// Replace all cached categories with server data (server-wins)
  Future<void> replaceAllFromServer(List<CategoryModel> serverCategories) async {
    final box = await _getBox();
    await box.clear();

    for (final serverCategory in serverCategories) {
      final hiveModel = CategoryHiveModel.fromModel(serverCategory);
      await box.put(hiveModel.serverId.toString(), hiveModel);
    }

    debugPrint('CategoryLocalDataSource: Replaced with ${serverCategories.length} server categories');
  }

  /// Delete a category by server ID
  Future<void> deleteCategory(int serverId) async {
    final box = await _getBox();
    await box.delete(serverId.toString());
    debugPrint('CategoryLocalDataSource: Deleted category $serverId');
  }

  /// Delete all categories (for logout/clear data)
  Future<void> deleteAllCategories() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('CategoryLocalDataSource: Deleted all categories');
  }

  /// Get count of categories
  Future<int> getCategoryCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// Check if categories have been cached
  Future<bool> hasCache() async {
    final box = await _getBox();
    return box.isNotEmpty;
  }

  /// Get last sync time (most recent syncedAt from any category)
  Future<DateTime?> getLastSyncTime() async {
    final box = await _getBox();
    if (box.isEmpty) return null;

    DateTime? latest;
    for (final cat in box.values) {
      if (latest == null || cat.syncedAt.isAfter(latest)) {
        latest = cat.syncedAt;
      }
    }
    return latest;
  }

  /// Convert CategoryHiveModel list to CategoryModel list
  List<CategoryModel> toModels(List<CategoryHiveModel> hiveModels) {
    return hiveModels.map((h) => h.toModel()).toList();
  }
}

/// Provider for CategoryLocalDataSource
final categoryLocalDataSourceProvider = Provider<CategoryLocalDataSource>((ref) {
  return CategoryLocalDataSource();
});
