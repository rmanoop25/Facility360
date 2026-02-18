import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_service.dart';
import '../datasources/admin_dashboard_remote_datasource.dart';
import '../datasources/dashboard_local_datasource.dart';
import '../models/dashboard_stats_model.dart';

/// Repository for admin dashboard operations
/// Supports offline-first with 15-minute cache expiry for stats
class AdminDashboardRepository {
  final AdminDashboardRemoteDataSource _remoteDataSource;
  final DashboardLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;

  AdminDashboardRepository({
    required AdminDashboardRemoteDataSource remoteDataSource,
    required DashboardLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivityService = connectivityService;

  /// Check if online
  bool get isOnline => _connectivityService.isOnline;

  /// Get dashboard statistics
  /// Returns cached data if offline or cache is valid, refreshes in background if online
  Future<DashboardStatsModel> getStats({
    DateTime? dateFrom,
    DateTime? dateTo,
    bool forceRefresh = false,
  }) async {
    // If not forcing refresh and cache is valid, return cached data
    if (!forceRefresh) {
      final cachedStats = await _localDataSource.getValidCachedStatsModel();
      if (cachedStats != null) {
        debugPrint('AdminDashboardRepository: Returning cached stats');

        // If online, refresh in background
        if (isOnline) {
          _refreshStatsInBackground(dateFrom: dateFrom, dateTo: dateTo);
        }

        return cachedStats;
      }
    }

    // If offline, return stale cached data if available
    if (!isOnline) {
      final cachedStats = await _localDataSource.getCachedStatsModel();
      if (cachedStats != null) {
        debugPrint('AdminDashboardRepository: Returning stale cached stats (offline)');
        return cachedStats;
      }
      throw Exception('Dashboard stats not available offline. Please connect to the internet.');
    }

    // Online: fetch from server
    try {
      String? dateFromStr;
      String? dateToStr;

      if (dateFrom != null) {
        dateFromStr =
            '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      }
      if (dateTo != null) {
        dateToStr =
            '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      }

      final stats = await _remoteDataSource.getStats(
        dateFrom: dateFromStr,
        dateTo: dateToStr,
      );

      // Cache the stats (only cache default date range)
      if (dateFrom == null && dateTo == null) {
        await _localDataSource.cacheStats(stats);
        debugPrint('AdminDashboardRepository: Cached fresh stats');
      }

      return stats;
    } catch (e) {
      debugPrint('AdminDashboardRepository: getStats error - $e');

      // Fallback to any cached data on error
      final cachedStats = await _localDataSource.getCachedStatsModel();
      if (cachedStats != null) {
        debugPrint('AdminDashboardRepository: Returning cached stats after error');
        return cachedStats;
      }

      rethrow;
    }
  }

  /// Refresh stats in background (fire and forget)
  void _refreshStatsInBackground({DateTime? dateFrom, DateTime? dateTo}) {
    Future(() async {
      try {
        String? dateFromStr;
        String? dateToStr;

        if (dateFrom != null) {
          dateFromStr =
              '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
        }
        if (dateTo != null) {
          dateToStr =
              '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
        }

        final stats = await _remoteDataSource.getStats(
          dateFrom: dateFromStr,
          dateTo: dateToStr,
        );

        // Cache the stats (only cache default date range)
        if (dateFrom == null && dateTo == null) {
          await _localDataSource.cacheStats(stats);
          debugPrint('AdminDashboardRepository: Background refresh complete');
        }
      } catch (e) {
        debugPrint('AdminDashboardRepository: Background refresh failed - $e');
      }
    });
  }

  /// Force refresh stats from server
  Future<DashboardStatsModel> refreshStats({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return getStats(
      dateFrom: dateFrom,
      dateTo: dateTo,
      forceRefresh: true,
    );
  }

  /// Check if cache is valid
  Future<bool> isCacheValid() async {
    return _localDataSource.isCacheValid();
  }

  /// Get remaining cache time in minutes
  Future<int> getRemainingCacheMinutes() async {
    return _localDataSource.getRemainingCacheMinutes();
  }

  /// Clear cached stats
  Future<void> clearCache() async {
    await _localDataSource.clearCache();
  }
}

/// Provider for AdminDashboardRepository
final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  final remoteDataSource = ref.watch(adminDashboardRemoteDataSourceProvider);
  final localDataSource = ref.watch(dashboardLocalDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);

  return AdminDashboardRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    connectivityService: connectivityService,
  );
});
