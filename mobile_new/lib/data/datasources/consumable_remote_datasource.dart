import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/consumable_model.dart';

/// Remote data source for consumable operations
class ConsumableRemoteDataSource {
  final ApiClient _apiClient;

  ConsumableRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Fetch all consumables from the server
  ///
  /// Optionally filter by [categoryId] to get consumables for a specific category.
  Future<List<ConsumableModel>> getConsumables({int? categoryId}) async {
    final queryParams = <String, dynamic>{};
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }

    final response = await _apiClient.get(
      ApiConstants.consumables,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response['success'] != true) {
      throw ApiException(
        message:
            response['message'] as String? ?? 'Failed to fetch consumables',
      );
    }

    final dataList = response['data'] as List<dynamic>? ?? [];
    return dataList
        .map((item) => ConsumableModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single consumable by ID
  Future<ConsumableModel> getConsumable(int id) async {
    final response = await _apiClient.get('${ApiConstants.consumables}/$id');

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Consumable not found',
      );
    }

    return ConsumableModel.fromJson(response['data'] as Map<String, dynamic>);
  }
}

/// Provider for ConsumableRemoteDataSource
final consumableRemoteDataSourceProvider =
    Provider<ConsumableRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ConsumableRemoteDataSource(apiClient: apiClient);
});
