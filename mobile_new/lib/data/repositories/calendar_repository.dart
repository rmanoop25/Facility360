import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../datasources/calendar_local_datasource.dart';
import '../datasources/calendar_remote_datasource.dart';
import '../models/calendar_event_model.dart';
import '../models/calendar_events_response.dart';

/// Repository for calendar events with offline-first support
///
/// Strategy:
/// 1. Try cache first (instant, works offline)
/// 2. If cache is fresh (< 24 hours), return cache and refresh in background if online
/// 3. If cache is stale or forceRefresh, fetch from server
/// 4. Always update cache after successful server fetch
class CalendarRepository {
  final CalendarRemoteDataSource _remoteDataSource;
  final CalendarLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;

  CalendarRepository({
    required CalendarRemoteDataSource remoteDataSource,
    required CalendarLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivityService = connectivityService;

  /// Get calendar events for a specific month
  ///
  /// Implements offline-first strategy with background refresh
  Future<CalendarEventsResponse> getMonthEvents({
    required int year,
    required int month,
    String? status,
    int? serviceProviderId,
    int? categoryId,
    bool forceRefresh = false,
  }) async {
    // If force refresh, skip cache and fetch from server
    if (forceRefresh && _connectivityService.isOnline) {
      return _fetchAndCacheFromServer(
        year: year,
        month: month,
        status: status,
        serviceProviderId: serviceProviderId,
        categoryId: categoryId,
      );
    }

    // Try to return cached data if fresh
    final hasFreshCache =
        await _localDataSource.hasFreshCache(year, month);
    if (hasFreshCache) {
      final cachedEvents = await _localDataSource.getCachedEvents(year, month);
      if (cachedEvents != null && cachedEvents.isNotEmpty) {
        debugPrint(
            'CalendarRepository: Returning ${cachedEvents.length} cached events for $year-$month');

        // Refresh in background if online
        if (_connectivityService.isOnline) {
          _refreshInBackground(
            year: year,
            month: month,
            status: status,
            serviceProviderId: serviceProviderId,
            categoryId: categoryId,
          );
        }

        // Group events and return
        return _groupEvents(cachedEvents);
      }
    }

    // Cache is stale or empty - fetch from server if online
    if (_connectivityService.isOnline) {
      try {
        return await _fetchAndCacheFromServer(
          year: year,
          month: month,
          status: status,
          serviceProviderId: serviceProviderId,
          categoryId: categoryId,
        );
      } on ApiException catch (e) {
        // If server fails, try returning stale cache as fallback
        final cachedEvents =
            await _localDataSource.getCachedEvents(year, month);
        if (cachedEvents != null && cachedEvents.isNotEmpty) {
          debugPrint(
              'CalendarRepository: Server error, returning stale cache for $year-$month');
          return _groupEvents(cachedEvents);
        }
        rethrow;
      }
    }

    // Offline - try to return stale cache
    final cachedEvents = await _localDataSource.getCachedEvents(year, month);
    if (cachedEvents != null && cachedEvents.isNotEmpty) {
      debugPrint(
          'CalendarRepository: Offline, returning cached events for $year-$month');
      return _groupEvents(cachedEvents);
    }

    // No cache and offline
    throw const ApiException(
      message:
          'No calendar data available offline. Please connect to the internet.',
    );
  }

  /// Fetch events from server and update cache
  Future<CalendarEventsResponse> _fetchAndCacheFromServer({
    required int year,
    required int month,
    String? status,
    int? serviceProviderId,
    int? categoryId,
  }) async {
    debugPrint('CalendarRepository: Fetching from server for $year-$month');

    final response = await _remoteDataSource.getEventsForMonth(
      year: year,
      month: month,
      status: status,
      serviceProviderId: serviceProviderId,
      categoryId: categoryId,
    );

    // Cache all events (assignments + pending issues)
    await _localDataSource.cacheMonthEvents(year, month, response.allEvents);

    return response;
  }

  /// Refresh data from server in background (fire-and-forget)
  void _refreshInBackground({
    required int year,
    required int month,
    String? status,
    int? serviceProviderId,
    int? categoryId,
  }) {
    // Run async without awaiting
    _fetchAndCacheFromServer(
      year: year,
      month: month,
      status: status,
      serviceProviderId: serviceProviderId,
      categoryId: categoryId,
    ).then((_) {
      debugPrint(
          'CalendarRepository: Background refresh completed for $year-$month');
    }).catchError((error) {
      debugPrint('CalendarRepository: Background refresh failed - $error');
    });
  }

  /// Group events into CalendarEventsResponse structure
  ///
  /// Since cached events don't distinguish between assignments and pending issues,
  /// we separate them based on the 'type' field
  CalendarEventsResponse _groupEvents(List<CalendarEventModel> events) {
    final assignments = events
        .where((e) => e.type == 'assignment')
        .toList();
    final pendingIssues = events
        .where((e) => e.type == 'pending_issue')
        .toList();

    return CalendarEventsResponse(
      assignments: assignments,
      pendingIssues: pendingIssues,
    );
  }

  /// Clear all cached calendar data
  Future<void> clearCache() async {
    await _localDataSource.clearAllCache();
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    await _localDataSource.clearExpiredCache();
  }
}

/// Provider for CalendarRepository
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    remoteDataSource: ref.watch(calendarRemoteDataSourceProvider),
    localDataSource: ref.watch(calendarLocalDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});
