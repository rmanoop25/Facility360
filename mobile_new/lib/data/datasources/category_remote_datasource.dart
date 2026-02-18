import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/category_model.dart';

/// Remote data source for category operations
class CategoryRemoteDataSource {
  final ApiClient _apiClient;

  CategoryRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Fetch all categories from the server
  ///
  /// Returns a list of active categories that can be used for issue creation.
  Future<List<CategoryModel>> getCategories() async {
    final response = await _apiClient.get(ApiConstants.categories);

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Failed to fetch categories',
      );
    }

    final dataList = response['data'] as List<dynamic>? ?? [];
    return dataList
        .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single category by ID
  Future<CategoryModel> getCategory(int id) async {
    final response = await _apiClient.get('${ApiConstants.categories}/$id');

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Category not found',
      );
    }

    return CategoryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Fetch category tree (root categories with nested children)
  ///
  /// Returns hierarchical structure with all children nested
  Future<List<CategoryModel>> getCategoryTree() async {
    final response = await _apiClient.get(
      ApiConstants.categoryTree,
      queryParameters: {'nested': true},
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
  }

  /// Fetch children of a specific category
  Future<List<CategoryModel>> getCategoryChildren(int parentId) async {
    final response = await _apiClient.get(ApiConstants.categoryChildren(parentId));

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
  }
}

/// Provider for CategoryRemoteDataSource
final categoryRemoteDataSourceProvider =
    Provider<CategoryRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CategoryRemoteDataSource(apiClient: apiClient);
});
