import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/dashboard_stats_model.dart';

/// Hive model for storing dashboard statistics locally
/// Used for offline-first functionality with 15-minute cache expiry
@HiveType(typeId: 11)
class DashboardStatsHiveModel extends HiveObject {
  /// Full stats JSON data
  @HiveField(0)
  String statsJson;

  /// Cached timestamp
  @HiveField(1)
  DateTime cachedAt;

  /// Cache expiry duration in minutes (default 15)
  static const int cacheExpiryMinutes = 15;

  DashboardStatsHiveModel({
    required this.statsJson,
    required this.cachedAt,
  });

  /// Check if cache is still valid
  bool get isCacheValid {
    final now = DateTime.now();
    final expiryTime = cachedAt.add(const Duration(minutes: cacheExpiryMinutes));
    return now.isBefore(expiryTime);
  }

  /// Get remaining cache time in minutes
  int get remainingCacheMinutes {
    final now = DateTime.now();
    final expiryTime = cachedAt.add(const Duration(minutes: cacheExpiryMinutes));
    if (now.isAfter(expiryTime)) return 0;
    return expiryTime.difference(now).inMinutes;
  }

  /// Create from DashboardStatsModel
  factory DashboardStatsHiveModel.fromModel(DashboardStatsModel model) {
    return DashboardStatsHiveModel(
      statsJson: jsonEncode(model.toJson()),
      cachedAt: DateTime.now(),
    );
  }

  /// Convert to DashboardStatsModel
  DashboardStatsModel? toModel() {
    try {
      final json = jsonDecode(statsJson) as Map<String, dynamic>;
      return DashboardStatsModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Update cache with new data
  void updateCache(DashboardStatsModel model) {
    statsJson = jsonEncode(model.toJson());
    cachedAt = DateTime.now();
  }
}
