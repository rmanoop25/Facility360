import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../models/dashboard_stats_model.dart';

/// Remote data source for admin dashboard statistics
class AdminDashboardRemoteDataSource {
  final ApiClient _apiClient;

  AdminDashboardRemoteDataSource(this._apiClient);

  /// Get dashboard statistics
  /// [dateFrom] and [dateTo] are optional date range filters
  Future<DashboardStatsModel> getStats({
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;

      final response = await _apiClient.get(
        ApiConstants.adminDashboard,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response['data'] as Map<String, dynamic>;
      return DashboardStatsModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminDashboardRemoteDataSource: getStats error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminDashboardRemoteDataSource
final adminDashboardRemoteDataSourceProvider =
    Provider<AdminDashboardRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminDashboardRemoteDataSource(apiClient);
});
