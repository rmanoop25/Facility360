import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../models/work_type_model.dart';

/// Remote data source for work type operations
class WorkTypeRemoteDataSource {
  final ApiClient _apiClient;

  WorkTypeRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Fetch all work types from the server
  ///
  /// [categoryId] - Optional filter by category
  /// [isActive] - Optional filter by active status
  Future<List<WorkTypeModel>> getWorkTypes({
    int? categoryId,
    bool? isActive,
  }) async {
    final queryParams = <String, dynamic>{};
    if (categoryId != null) queryParams['category_id'] = categoryId;
    if (isActive != null) queryParams['is_active'] = isActive ? 1 : 0;

    final response = await _apiClient.get(
      '/admin/work-types',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Failed to fetch work types',
      );
    }

    final dataList = response['data'] as List<dynamic>? ?? [];
    return dataList
        .map((item) => WorkTypeModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single work type by ID
  Future<WorkTypeModel> getWorkType(int id) async {
    final response = await _apiClient.get('/admin/work-types/$id');

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Work type not found',
      );
    }

    return WorkTypeModel.fromJson(response['data'] as Map<String, dynamic>);
  }
}

/// Provider for WorkTypeRemoteDataSource
final workTypeRemoteDataSourceProvider =
    Provider<WorkTypeRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WorkTypeRemoteDataSource(apiClient: apiClient);
});
