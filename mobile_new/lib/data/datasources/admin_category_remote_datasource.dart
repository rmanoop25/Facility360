import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/category_model.dart';
import '../models/paginated_response.dart';

/// Remote data source for admin category CRUD operations
class AdminCategoryRemoteDataSource {
  final ApiClient _apiClient;

  AdminCategoryRemoteDataSource(this._apiClient);

  /// Get paginated list of categories with optional filters
  Future<PaginatedResponse<CategoryModel>> getCategories({
    String? search,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'with_counts': 1,  // Use 1 instead of true for Laravel boolean validation
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive;
      }

      final response = await _apiClient.get(
        ApiConstants.adminCategories,
        queryParameters: queryParams,
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to fetch categories',
        );
      }

      final data = response['data'] as List<dynamic>;
      final categories = data
          .map((json) => CategoryModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return PaginatedResponse(
        data: categories,
        currentPage: response['meta']?['current_page'] as int? ?? page,
        lastPage: response['meta']?['last_page'] as int? ?? 1,
        perPage: response['meta']?['per_page'] as int? ?? perPage,
        total: response['meta']?['total'] as int? ?? categories.length,
      );
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: getCategories error - $e');
      rethrow;
    }
  }

  /// Get a single category by ID
  Future<CategoryModel> getCategory(int id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.adminCategoryDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Category not found',
        );
      }

      return CategoryModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: getCategory error - $e');
      rethrow;
    }
  }

  /// Create a new category
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
    try {
      final response = await _apiClient.post(
        ApiConstants.adminCategories,
        data: {
          'name_en': nameEn,
          'name_ar': nameAr,
          if (parentId != null) 'parent_id': parentId,
          if (descriptionEn != null) 'description_en': descriptionEn,
          if (descriptionAr != null) 'description_ar': descriptionAr,
          if (icon != null) 'icon': icon,
          if (color != null) 'color': color,
          'sort_order': sortOrder,
          'is_active': isActive,
        },
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to create category',
          data: response['errors'],
        );
      }

      return CategoryModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: createCategory error - $e');
      rethrow;
    }
  }

  /// Update an existing category
  ///
  /// [parentId] - Optional parent category ID (use -1 to set to null/root)
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
    try {
      final data = <String, dynamic>{};
      if (nameEn != null) data['name_en'] = nameEn;
      if (nameAr != null) data['name_ar'] = nameAr;
      // parent_id: -1 means set to null (make root), other values set the parent
      if (parentId != null) data['parent_id'] = parentId == -1 ? null : parentId;
      if (descriptionEn != null) data['description_en'] = descriptionEn;
      if (descriptionAr != null) data['description_ar'] = descriptionAr;
      if (icon != null) data['icon'] = icon;
      if (color != null) data['color'] = color;
      if (sortOrder != null) data['sort_order'] = sortOrder;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _apiClient.put(
        ApiConstants.adminCategoryDetail(id),
        data: data,
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to update category',
          data: response['errors'],
        );
      }

      return CategoryModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: updateCategory error - $e');
      rethrow;
    }
  }

  /// Delete a category (super_admin only)
  Future<void> deleteCategory(int id) async {
    try {
      final response = await _apiClient.delete(
        ApiConstants.adminCategoryDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to delete category',
        );
      }
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: deleteCategory error - $e');
      rethrow;
    }
  }

  /// Toggle category active status
  Future<CategoryModel> toggleActive(int id) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.adminCategoryToggle(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to toggle category status',
        );
      }

      return CategoryModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: toggleActive error - $e');
      rethrow;
    }
  }

  /// Get category tree (root categories with nested children)
  ///
  /// Returns hierarchical structure for admin panel
  Future<List<CategoryModel>> getCategoryTree({bool includeInactive = false}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.adminCategoryTree,
        queryParameters: {
          'nested': true,
          if (includeInactive) 'include_inactive': true,
        },
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to fetch category tree',
        );
      }

      final dataList = response['data'] as List<dynamic>? ?? [];
      return dataList
          .whereType<Map<String, dynamic>>()
          .map((item) => CategoryModel.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: getCategoryTree error - $e');
      rethrow;
    }
  }

  /// Get children of a specific category
  Future<List<CategoryModel>> getCategoryChildren(int parentId, {bool includeInactive = false}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.adminCategoryChildren(parentId),
        queryParameters: {
          if (includeInactive) 'include_inactive': true,
        },
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to fetch category children',
        );
      }

      final dataList = response['data'] as List<dynamic>? ?? [];
      return dataList
          .whereType<Map<String, dynamic>>()
          .map((item) => CategoryModel.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: getCategoryChildren error - $e');
      rethrow;
    }
  }

  /// Archive a category (soft delete)
  ///
  /// [confirmCascade] - Set to true to confirm archiving children
  Future<Map<String, dynamic>> archiveCategory(int id, {bool confirmCascade = false}) async {
    try {
      final response = await _apiClient.delete(
        ApiConstants.adminCategoryDetail(id),
        queryParameters: {
          if (confirmCascade) 'confirm_cascade': true,
        },
      );

      if (response['success'] != true) {
        // Check if requires confirmation
        if (response['requires_confirmation'] == true) {
          return {
            'success': false,
            'requires_confirmation': true,
            'message': response['message'] as String? ?? 'Confirmation required',
            'descendants_count': response['descendants_count'] as int? ?? 0,
          };
        }
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to archive category',
        );
      }

      return {
        'success': true,
        'archived_count': response['archived_count'] as int? ?? 1,
      };
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: archiveCategory error - $e');
      rethrow;
    }
  }

  /// Restore an archived category
  ///
  /// [includeDescendants] - Whether to restore children as well
  Future<CategoryModel> restoreCategory(int id, {bool includeDescendants = true}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.adminCategoryRestore(id),
        data: {'include_descendants': includeDescendants},
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to restore category',
        );
      }

      return CategoryModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: restoreCategory error - $e');
      rethrow;
    }
  }

  /// Move a category to a new parent
  ///
  /// [newParentId] - New parent ID (null to make root)
  Future<CategoryModel> moveCategory(int id, int? newParentId) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.adminCategoryMove(id),
        data: {'parent_id': newParentId},
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to move category',
        );
      }

      return CategoryModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminCategoryRemoteDataSource: moveCategory error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminCategoryRemoteDataSource
final adminCategoryRemoteDataSourceProvider =
    Provider<AdminCategoryRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminCategoryRemoteDataSource(apiClient);
});
