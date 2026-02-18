import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/consumable_model.dart';
import '../models/paginated_response.dart';

/// Remote data source for admin consumable CRUD operations
class AdminConsumableRemoteDataSource {
  final ApiClient _apiClient;

  AdminConsumableRemoteDataSource(this._apiClient);

  /// Get paginated list of consumables with optional filters
  Future<PaginatedResponse<ConsumableModel>> getConsumables({
    String? search,
    int? categoryId,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive ? '1' : '0';
      }

      final response = await _apiClient.get(
        ApiConstants.adminConsumables,
        queryParameters: queryParams,
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to fetch consumables',
        );
      }

      final data = response['data'] as List<dynamic>;
      final consumables = data
          .map((json) => ConsumableModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return PaginatedResponse(
        data: consumables,
        currentPage: response['meta']?['current_page'] as int? ?? page,
        lastPage: response['meta']?['last_page'] as int? ?? 1,
        perPage: response['meta']?['per_page'] as int? ?? perPage,
        total: response['meta']?['total'] as int? ?? consumables.length,
      );
    } catch (e) {
      debugPrint('AdminConsumableRemoteDataSource: getConsumables error - $e');
      rethrow;
    }
  }

  /// Get a single consumable by ID
  Future<ConsumableModel> getConsumable(int id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.adminConsumableDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Consumable not found',
        );
      }

      return ConsumableModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminConsumableRemoteDataSource: getConsumable error - $e');
      rethrow;
    }
  }

  /// Create a new consumable
  Future<ConsumableModel> createConsumable({
    required String nameEn,
    required String nameAr,
    required int categoryId,
    bool isActive = true,
  }) async {
    try {
      final requestData = {
        'name_en': nameEn,
        'name_ar': nameAr,
        'category_id': categoryId,
        'is_active': isActive,
      };

      debugPrint('AdminConsumableRemoteDataSource: Creating consumable with data: $requestData');

      final response = await _apiClient.post(
        ApiConstants.adminConsumables,
        data: requestData,
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to create consumable',
          data: response['errors'],
        );
      }

      return ConsumableModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminConsumableRemoteDataSource: createConsumable error - $e');
      rethrow;
    }
  }

  /// Update an existing consumable
  Future<ConsumableModel> updateConsumable(
    int id, {
    String? nameEn,
    String? nameAr,
    int? categoryId,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (nameEn != null) data['name_en'] = nameEn;
      if (nameAr != null) data['name_ar'] = nameAr;
      if (categoryId != null) data['category_id'] = categoryId;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _apiClient.put(
        ApiConstants.adminConsumableDetail(id),
        data: data,
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to update consumable',
          data: response['errors'],
        );
      }

      return ConsumableModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminConsumableRemoteDataSource: updateConsumable error - $e');
      rethrow;
    }
  }

  /// Delete a consumable
  Future<void> deleteConsumable(int id) async {
    try {
      final response = await _apiClient.delete(
        ApiConstants.adminConsumableDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to delete consumable',
        );
      }
    } catch (e) {
      debugPrint('AdminConsumableRemoteDataSource: deleteConsumable error - $e');
      rethrow;
    }
  }

  /// Toggle consumable active status
  Future<ConsumableModel> toggleActive(int id) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.adminConsumableToggle(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to toggle consumable status',
        );
      }

      return ConsumableModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminConsumableRemoteDataSource: toggleActive error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminConsumableRemoteDataSource
final adminConsumableRemoteDataSourceProvider =
    Provider<AdminConsumableRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminConsumableRemoteDataSource(apiClient);
});
