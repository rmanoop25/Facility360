import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/calendar_event_model.dart';

/// Local data source for calendar event caching using Hive
///
/// Caches calendar events per month with expiry timestamps
class CalendarLocalDataSource {
  static const String _boxName = 'calendar_cache';
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Get or open the calendar cache box
  Box<dynamic> _getBox() {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    throw Exception('Calendar cache box not opened');
  }

  /// Cache events for a specific month
  ///
  /// Stores events with a cache timestamp for expiry checking
  Future<void> cacheMonthEvents(
    int year,
    int month,
    List<CalendarEventModel> events,
  ) async {
    try {
      final box = _getBox();
      final key = _generateKey(year, month);
      final cacheData = {
        'events': events.map((e) => e.toJson()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
      };

      await box.put(key, jsonEncode(cacheData));
      debugPrint(
          'CalendarLocalDataSource: Cached ${events.length} events for $year-$month');
    } catch (e) {
      debugPrint('CalendarLocalDataSource: Cache error - $e');
    }
  }

  /// Get cached events for a specific month
  ///
  /// Returns null if cache doesn't exist or is expired
  Future<List<CalendarEventModel>?> getCachedEvents(
    int year,
    int month,
  ) async {
    try {
      final box = _getBox();
      final key = _generateKey(year, month);
      final cachedJson = box.get(key) as String?;

      if (cachedJson == null) {
        debugPrint('CalendarLocalDataSource: No cache for $year-$month');
        return null;
      }

      final cacheData = jsonDecode(cachedJson) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(cacheData['cached_at'] as String);

      // Check if cache is expired
      if (DateTime.now().difference(cachedAt) > _cacheExpiry) {
        debugPrint('CalendarLocalDataSource: Cache expired for $year-$month');
        await box.delete(key); // Clean up expired cache
        return null;
      }

      final eventsJson = cacheData['events'] as List<dynamic>;
      final events = eventsJson
          .map((e) => CalendarEventModel.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint(
          'CalendarLocalDataSource: Retrieved ${events.length} cached events for $year-$month');
      return events;
    } catch (e) {
      debugPrint('CalendarLocalDataSource: Get cache error - $e');
      return null;
    }
  }

  /// Clear all expired cache entries
  ///
  /// Should be called on app startup to clean up old data
  Future<void> clearExpiredCache() async {
    try {
      final box = _getBox();
      final keysToDelete = <String>[];
      final now = DateTime.now();

      for (final key in box.keys) {
        try {
          final cachedJson = box.get(key) as String?;
          if (cachedJson != null) {
            final cacheData = jsonDecode(cachedJson) as Map<String, dynamic>;
            final cachedAt = DateTime.parse(cacheData['cached_at'] as String);

            if (now.difference(cachedAt) > _cacheExpiry) {
              keysToDelete.add(key as String);
            }
          }
        } catch (e) {
          // If parsing fails, mark for deletion
          keysToDelete.add(key as String);
        }
      }

      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        debugPrint(
            'CalendarLocalDataSource: Cleared ${keysToDelete.length} expired cache entries');
      }
    } catch (e) {
      debugPrint('CalendarLocalDataSource: Clear expired error - $e');
    }
  }

  /// Clear all cached calendar data
  Future<void> clearAllCache() async {
    try {
      final box = _getBox();
      await box.clear();
      debugPrint('CalendarLocalDataSource: Cleared all cache');
    } catch (e) {
      debugPrint('CalendarLocalDataSource: Clear all error - $e');
    }
  }

  /// Get cache age for a specific month
  ///
  /// Returns null if no cache exists
  Future<Duration?> getCacheAge(int year, int month) async {
    try {
      final box = _getBox();
      final key = _generateKey(year, month);
      final cachedJson = box.get(key) as String?;

      if (cachedJson == null) return null;

      final cacheData = jsonDecode(cachedJson) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(cacheData['cached_at'] as String);

      return DateTime.now().difference(cachedAt);
    } catch (e) {
      debugPrint('CalendarLocalDataSource: Get cache age error - $e');
      return null;
    }
  }

  /// Check if cache exists and is valid for a specific month
  Future<bool> hasFreshCache(int year, int month) async {
    final age = await getCacheAge(year, month);
    return age != null && age < _cacheExpiry;
  }

  /// Generate cache key for year-month combination
  String _generateKey(int year, int month) {
    return 'calendar_${year}_${month.toString().padLeft(2, '0')}';
  }
}

/// Provider for CalendarLocalDataSource
final calendarLocalDataSourceProvider = Provider<CalendarLocalDataSource>((ref) {
  return CalendarLocalDataSource();
});
