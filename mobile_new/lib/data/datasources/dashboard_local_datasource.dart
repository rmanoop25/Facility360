import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/dashboard_stats_hive_model.dart';
import '../models/dashboard_stats_model.dart';

/// Local data source for dashboard statistics using Hive
/// Uses 15-minute cache expiry for stats data
class DashboardLocalDataSource {
  static const String _boxName = 'dashboard_stats';
  static const String _statsKey = 'stats';

  /// Get or open the dashboard stats box
  Future<Box<DashboardStatsHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<DashboardStatsHiveModel>(_boxName);
    }
    return Hive.openBox<DashboardStatsHiveModel>(_boxName);
  }

  /// Cache dashboard stats
  Future<void> cacheStats(DashboardStatsModel stats) async {
    final box = await _getBox();
    final hiveModel = DashboardStatsHiveModel.fromModel(stats);
    await box.put(_statsKey, hiveModel);
    debugPrint('DashboardLocalDataSource: Cached dashboard stats');
  }

  /// Get cached dashboard stats
  Future<DashboardStatsHiveModel?> getCachedStats() async {
    final box = await _getBox();
    return box.get(_statsKey);
  }

  /// Get cached stats as model (only if cache is valid)
  Future<DashboardStatsModel?> getValidCachedStatsModel() async {
    final cached = await getCachedStats();
    if (cached != null && cached.isCacheValid) {
      return cached.toModel();
    }
    return null;
  }

  /// Get cached stats as model (regardless of validity)
  Future<DashboardStatsModel?> getCachedStatsModel() async {
    final cached = await getCachedStats();
    return cached?.toModel();
  }

  /// Check if cache is valid (not expired)
  Future<bool> isCacheValid() async {
    final cached = await getCachedStats();
    return cached?.isCacheValid ?? false;
  }

  /// Get remaining cache time in minutes
  Future<int> getRemainingCacheMinutes() async {
    final cached = await getCachedStats();
    return cached?.remainingCacheMinutes ?? 0;
  }

  /// Get cache age in minutes
  Future<int?> getCacheAgeMinutes() async {
    final cached = await getCachedStats();
    if (cached == null) return null;
    return DateTime.now().difference(cached.cachedAt).inMinutes;
  }

  /// Update existing cache with new data
  Future<void> updateCache(DashboardStatsModel stats) async {
    final box = await _getBox();
    final cached = box.get(_statsKey);

    if (cached != null) {
      cached.updateCache(stats);
      await cached.save();
      debugPrint('DashboardLocalDataSource: Updated cached stats');
    } else {
      await cacheStats(stats);
    }
  }

  /// Clear cached stats
  Future<void> clearCache() async {
    final box = await _getBox();
    await box.delete(_statsKey);
    debugPrint('DashboardLocalDataSource: Cleared cached stats');
  }

  /// Clear all dashboard data (for logout/clear data)
  Future<void> deleteAll() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('DashboardLocalDataSource: Deleted all dashboard data');
  }

  /// Check if stats have been cached
  Future<bool> hasCache() async {
    final box = await _getBox();
    return box.containsKey(_statsKey);
  }

  /// Get last cache time
  Future<DateTime?> getLastCacheTime() async {
    final cached = await getCachedStats();
    return cached?.cachedAt;
  }
}

/// Provider for DashboardLocalDataSource
final dashboardLocalDataSourceProvider = Provider<DashboardLocalDataSource>((ref) {
  return DashboardLocalDataSource();
});
