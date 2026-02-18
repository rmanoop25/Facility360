import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../models/calendar_events_response.dart';

/// Remote data source for calendar events
class CalendarRemoteDataSource {
  final ApiClient _apiClient;

  CalendarRemoteDataSource(this._apiClient);

  /// Get calendar events for a date range
  ///
  /// [startDate] and [endDate] define the date range
  /// Optional filters: [status], [serviceProviderId], [categoryId]
  Future<CalendarEventsResponse> getEvents({
    required DateTime startDate,
    required DateTime endDate,
    String? status,
    int? serviceProviderId,
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      };

      if (status != null) queryParams['status'] = status;
      if (serviceProviderId != null) {
        queryParams['service_provider_id'] = serviceProviderId;
      }
      if (categoryId != null) queryParams['category_id'] = categoryId;

      final response = await _apiClient.get(
        ApiConstants.adminCalendarEvents,
        queryParameters: queryParams,
      );

      final data = response['data'] as Map<String, dynamic>;
      return CalendarEventsResponse.fromJson(data);
    } catch (e) {
      debugPrint('CalendarRemoteDataSource: getEvents error - $e');
      rethrow;
    }
  }

  /// Get calendar events for a specific month
  ///
  /// Convenience method that calculates start/end dates for the month
  Future<CalendarEventsResponse> getEventsForMonth({
    required int year,
    required int month,
    String? status,
    int? serviceProviderId,
    int? categoryId,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // Last day of month

    return getEvents(
      startDate: startDate,
      endDate: endDate,
      status: status,
      serviceProviderId: serviceProviderId,
      categoryId: categoryId,
    );
  }

  /// Format date to YYYY-MM-DD for API
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }
}

/// Provider for CalendarRemoteDataSource
final calendarRemoteDataSourceProvider =
    Provider<CalendarRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CalendarRemoteDataSource(apiClient);
});
