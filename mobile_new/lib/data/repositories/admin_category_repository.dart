import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_operation.dart';
import '../../core/sync/sync_queue_service.dart';
import '../datasources/admin_category_remote_datasource.dart';
import '../datasources/category_local_datasource.dart';
import '../local/adapters/category_hive_model.dart';
import '../models/category_model.dart';
import '../models/paginated_response.dart';

/// Repository for admin category CRUD operations
/// Supports full offline-first functionality with sync queue
class AdminCategoryRepository {
  final AdminCategoryRemoteDataSource _remoteDataSource;
  final CategoryLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;
  final SyncQueueService _syncQueueService;

  AdminCategoryRepository({
    required AdminCategoryRemoteDataSource remoteDataSource,
    required CategoryLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
    required SyncQueueService syncQueueService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivityService = connectivityService,
        _syncQueueService = syncQueueService;

  /// Check if online
  bool get isOnline => _connectivityService.isOnline;

  /// Get paginated list of categories with optional filters
  /// Returns cached data if offline, refreshes in background if online
  Future<PaginatedResponse<CategoryModel>> getCategories({
    String? search,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    // Get cached data first
    final cachedCategories = await _localDataSource.getAllCategories();

    // If offline, use cached data with local filtering and pagination
    if (!isOnline) {
      // Apply filters locally
      var filtered = cachedCategories.where((c) {
        if (isActive != null && c.isActive != isActive) return false;
        if (search != null && search.isNotEmpty) {
          final lowerSearch = search.toLowerCase();
          return c.nameEn.toLowerCase().contains(lowerSearch) ||
              c.nameAr.toLowerCase().contains(lowerSearch);
        }
        return true;
      }).toList();

      // Apply pagination
      final startIndex = (page - 1) * perPage;
      final endIndex = startIndex + perPage;
      final paginatedList = filtered.length > startIndex
          ? filtered.sublist(
              startIndex, endIndex.clamp(0, filtered.length))
          : <CategoryHiveModel>[];

      return PaginatedResponse(
        data: _localDataSource.toModels(paginatedList),
        currentPage: page,
        lastPage: (filtered.length / perPage).ceil(),
        perPage: perPage,
        total: filtered.length,
      );
    }

    // Online: fetch from server for all pages
    try {
      final response = await _remoteDataSource.getCategories(
        search: search,
        isActive: isActive,
        page: page,
        perPage: perPage,
      );

      // If this is page 1, replace all cached data
      if (page == 1 && search == null && isActive == null) {
        await _localDataSource.replaceAllFromServer(response.data);
      }

      return response;
    } catch (e) {
      debugPrint('AdminCategoryRepository: getCategories error - $e');
      // Fallback to cached data on error
      if (cachedCategories.isNotEmpty) {
        debugPrint('Falling back to cached categories');
        return PaginatedResponse(
          data: _localDataSource.toModels(cachedCategories),
          currentPage: 1,
          lastPage: 1,
          perPage: cachedCategories.length,
          total: cachedCategories.length,
        );
      }
      rethrow;
    }
  }

  /// Get a single category by ID
  /// Returns cached data if offline
  Future<CategoryModel> getCategory(int id) async {
    // Try cache first
    final cached = await _localDataSource.getCategoryById(id);

    if (!isOnline) {
      if (cached != null) {
        return cached.toModel();
      }
      throw Exception('Category not found in cache and device is offline');
    }

    // Online: fetch from server
    try {
      final category = await _remoteDataSource.getCategory(id);
      // Update cache
      await _localDataSource.saveCategory(CategoryHiveModel.fromModel(category));
      return category;
    } catch (e) {
      debugPrint('AdminCategoryRepository: getCategory error - $e');
      // Fallback to cache on error
      if (cached != null) {
        return cached.toModel();
      }
      rethrow;
    }
  }

  /// Create a new category
  /// Saves locally and queues for sync if offline
  ///
  /// [parentId] - Optional parent category ID for creating subcategories
  Future<CategoryModel> createCategory({
    required String nameEn,
    required String nameAr,
    int? parentId,
    String? descriptionEn,
    String? descriptionAr,
    String? icon,
    String? color,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    if (isOnline) {
      // Online: create on server
      try {
        final category = await _remoteDataSource.createCategory(
          nameEn: nameEn,
          nameAr: nameAr,
          parentId: parentId,
          descriptionEn: descriptionEn,
          descriptionAr: descriptionAr,
          icon: icon,
          color: color,
          sortOrder: sortOrder,
          isActive: isActive,
        );
        // Save to cache
        await _localDataSource.saveCategory(CategoryHiveModel.fromModel(category));
        return category;
      } catch (e) {
        debugPrint('AdminCategoryRepository: createCategory error - $e');
        rethrow;
      }
    } else {
      // Offline: save locally and queue for sync
      final localId = const Uuid().v4();

      // Calculate depth and path for local category
      int depth = 0;
      String? path;
      if (parentId != null) {
        final parent = await _localDataSource.getCategoryById(parentId);
        if (parent != null) {
          depth = parent.depth + 1;
          path = '${parent.path ?? parentId}/-$localId';
        }
      }

      final localCategory = CategoryModel(
        id: -localId.hashCode.abs(), // Negative ID for local items
        parentId: parentId,
        nameEn: nameEn,
        nameAr: nameAr,
        descriptionEn: descriptionEn,
        descriptionAr: descriptionAr,
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        isActive: isActive,
        depth: depth,
        path: path,
        isRoot: parentId == null,
      );

      // Save to local storage
      await _localDataSource.saveCategory(CategoryHiveModel.fromModel(localCategory));

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.create,
        entity: SyncEntityType.category,
        localId: localId,
        data: {
          'name_en': nameEn,
          'name_ar': nameAr,
          if (parentId != null) 'parent_id': parentId,
          'description_en': descriptionEn,
          'description_ar': descriptionAr,
          'icon': icon,
          'color': color,
          'sort_order': sortOrder,
          'is_active': isActive,
        },
      );

      debugPrint('Category created offline, queued for sync');
      return localCategory;
    }
  }

  /// Update an existing category
  /// Updates locally and queues for sync if offline
  ///
  /// [parentId] - Optional parent ID (-1 to set to null/root, other values set parent)
  Future<CategoryModel> updateCategory(
    int id, {
    String? nameEn,
    String? nameAr,
    int? parentId,
    String? descriptionEn,
    String? descriptionAr,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isActive,
  }) async {
    if (isOnline) {
      // Online: update on server
      try {
        final category = await _remoteDataSource.updateCategory(
          id,
          nameEn: nameEn,
          nameAr: nameAr,
          parentId: parentId,
          descriptionEn: descriptionEn,
          descriptionAr: descriptionAr,
          icon: icon,
          color: color,
          sortOrder: sortOrder,
          isActive: isActive,
        );
        // Update cache
        await _localDataSource.saveCategory(CategoryHiveModel.fromModel(category));
        return category;
      } catch (e) {
        debugPrint('AdminCategoryRepository: updateCategory error - $e');
        rethrow;
      }
    } else {
      // Offline: update locally and queue for sync
      final cached = await _localDataSource.getCategoryById(id);
      if (cached == null) {
        throw Exception('Category not found in cache');
      }

      // Calculate new depth and path if parent changed
      int? newDepth;
      String? newPath;
      bool? newIsRoot;
      final effectiveParentId = parentId == -1 ? null : parentId;

      if (parentId != null) {
        if (effectiveParentId == null) {
          // Making it a root
          newDepth = 0;
          newPath = id.toString();
          newIsRoot = true;
        } else {
          // Setting new parent
          final newParent = await _localDataSource.getCategoryById(effectiveParentId);
          if (newParent != null) {
            newDepth = newParent.depth + 1;
            newPath = '${newParent.path ?? effectiveParentId}/$id';
            newIsRoot = false;
          }
        }
      }

      // Update local model
      final updatedCategory = cached.toModel().copyWith(
        nameEn: nameEn,
        nameAr: nameAr,
        parentId: effectiveParentId,
        descriptionEn: descriptionEn,
        descriptionAr: descriptionAr,
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        isActive: isActive,
        depth: newDepth,
        path: newPath,
        isRoot: newIsRoot,
      );

      // Save updated model
      await _localDataSource.saveCategory(CategoryHiveModel.fromModel(updatedCategory));

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.category,
        localId: id.toString(),
        data: {
          'server_id': id,
          if (nameEn != null) 'name_en': nameEn,
          if (nameAr != null) 'name_ar': nameAr,
          if (parentId != null) 'parent_id': effectiveParentId,
          if (descriptionEn != null) 'description_en': descriptionEn,
          if (descriptionAr != null) 'description_ar': descriptionAr,
          if (icon != null) 'icon': icon,
          if (color != null) 'color': color,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );

      debugPrint('Category updated offline, queued for sync');
      return updatedCategory;
    }
  }

  /// Delete a category (super_admin only)
  /// Deletes locally and queues for sync if offline
  Future<void> deleteCategory(int id) async {
    if (isOnline) {
      // Online: delete on server
      try {
        await _remoteDataSource.deleteCategory(id);
        // Remove from cache
        await _localDataSource.deleteCategory(id);
      } catch (e) {
        debugPrint('AdminCategoryRepository: deleteCategory error - $e');
        rethrow;
      }
    } else {
      // Offline: remove locally and queue for sync
      await _localDataSource.deleteCategory(id);

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.delete,
        entity: SyncEntityType.category,
        localId: id.toString(),
        data: {'server_id': id},
      );

      debugPrint('Category deleted offline, queued for sync');
    }
  }

  /// Toggle category active status
  /// Toggles locally and queues for sync if offline
  Future<CategoryModel> toggleActive(int id) async {
    if (isOnline) {
      // Online: toggle on server
      try {
        final category = await _remoteDataSource.toggleActive(id);
        // Update cache
        await _localDataSource.saveCategory(CategoryHiveModel.fromModel(category));
        return category;
      } catch (e) {
        debugPrint('AdminCategoryRepository: toggleActive error - $e');
        rethrow;
      }
    } else {
      // Offline: toggle locally and queue for sync
      final cached = await _localDataSource.getCategoryById(id);
      if (cached == null) {
        throw Exception('Category not found in cache');
      }

      // Toggle isActive
      final updatedCategory = cached.toModel().copyWith(
        isActive: !cached.isActive,
      );

      // Save updated model
      await _localDataSource.saveCategory(CategoryHiveModel.fromModel(updatedCategory));

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.category,
        localId: id.toString(),
        data: {
          'server_id': id,
          'is_active': updatedCategory.isActive,
        },
      );

      debugPrint('Category toggled offline, queued for sync');
      return updatedCategory;
    }
  }

  /// Refresh categories from server (force refresh)
  Future<void> refreshFromServer() async {
    if (!isOnline) {
      debugPrint('Cannot refresh: offline');
      return;
    }

    try {
      // Fetch all categories (paginated)
      int page = 1;
      final allCategories = <CategoryModel>[];

      while (true) {
        final response = await _remoteDataSource.getCategories(
          page: page,
          perPage: 50,
        );
        allCategories.addAll(response.data);

        if (page >= response.lastPage) break;
        page++;
      }

      // Replace local cache
      await _localDataSource.replaceAllFromServer(allCategories);
      debugPrint('Refreshed ${allCategories.length} categories from server');
    } catch (e) {
      debugPrint('AdminCategoryRepository: refreshFromServer error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminCategoryRepository
final adminCategoryRepositoryProvider = Provider<AdminCategoryRepository>((ref) {
  final remoteDataSource = ref.watch(adminCategoryRemoteDataSourceProvider);
  final localDataSource = ref.watch(categoryLocalDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncQueueService = ref.watch(syncQueueServiceProvider);

  return AdminCategoryRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    connectivityService: connectivityService,
    syncQueueService: syncQueueService,
  );
});
