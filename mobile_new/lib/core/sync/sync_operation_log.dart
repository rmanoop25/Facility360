import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Maximum number of log entries to keep
const int maxLogEntries = 500;

/// Represents a logged sync operation for debugging
class SyncLogEntry {
  final String id;
  final DateTime timestamp;
  final String operationType; // create, update, delete
  final String entityType; // issue, assignment, category, etc.
  final String localId;
  final bool success;
  final String? error;
  final int? serverId;
  final int retryCount;

  const SyncLogEntry({
    required this.id,
    required this.timestamp,
    required this.operationType,
    required this.entityType,
    required this.localId,
    required this.success,
    this.error,
    this.serverId,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'operation_type': operationType,
      'entity_type': entityType,
      'local_id': localId,
      'success': success,
      'error': error,
      'server_id': serverId,
      'retry_count': retryCount,
    };
  }

  factory SyncLogEntry.fromJson(Map<String, dynamic> json) {
    return SyncLogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      operationType: json['operation_type'] as String,
      entityType: json['entity_type'] as String,
      localId: json['local_id'] as String,
      success: json['success'] as bool,
      error: json['error'] as String?,
      serverId: json['server_id'] as int?,
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    final status = success ? 'OK' : 'FAILED';
    final errorMsg = error != null ? ' - $error' : '';
    return '[$status] $operationType $entityType:$localId$errorMsg';
  }
}

/// Service for logging sync operations for debugging
class SyncOperationLog {
  static const String _boxName = 'sync_log';
  static const String _logKey = 'entries';

  SyncOperationLog();

  /// Get or open the log box
  Future<Box<dynamic>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  /// Log a successful sync operation
  Future<void> logSuccess({
    required String operationType,
    required String entityType,
    required String localId,
    int? serverId,
    int retryCount = 0,
  }) async {
    await _addEntry(SyncLogEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_$localId',
      timestamp: DateTime.now(),
      operationType: operationType,
      entityType: entityType,
      localId: localId,
      success: true,
      serverId: serverId,
      retryCount: retryCount,
    ));
  }

  /// Log a failed sync operation
  Future<void> logFailure({
    required String operationType,
    required String entityType,
    required String localId,
    required String error,
    int retryCount = 0,
  }) async {
    await _addEntry(SyncLogEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_$localId',
      timestamp: DateTime.now(),
      operationType: operationType,
      entityType: entityType,
      localId: localId,
      success: false,
      error: error,
      retryCount: retryCount,
    ));
  }

  /// Add an entry to the log
  Future<void> _addEntry(SyncLogEntry entry) async {
    try {
      final box = await _getBox();
      final entriesJson = box.get(_logKey, defaultValue: '[]') as String;
      final entries = (jsonDecode(entriesJson) as List)
          .map((e) => SyncLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // Add new entry
      entries.add(entry);

      // Trim to max entries (keep most recent)
      if (entries.length > maxLogEntries) {
        entries.removeRange(0, entries.length - maxLogEntries);
      }

      // Save back
      await box.put(
        _logKey,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );

      debugPrint('SyncOperationLog: ${entry.toString()}');
    } catch (e) {
      debugPrint('SyncOperationLog: Failed to log - $e');
    }
  }

  /// Get all log entries
  Future<List<SyncLogEntry>> getEntries() async {
    try {
      final box = await _getBox();
      final entriesJson = box.get(_logKey, defaultValue: '[]') as String;
      return (jsonDecode(entriesJson) as List)
          .map((e) => SyncLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SyncOperationLog: Failed to get entries - $e');
      return [];
    }
  }

  /// Get recent entries (last N)
  Future<List<SyncLogEntry>> getRecentEntries({int count = 50}) async {
    final entries = await getEntries();
    if (entries.length <= count) return entries;
    return entries.sublist(entries.length - count);
  }

  /// Get entries for a specific entity type
  Future<List<SyncLogEntry>> getEntriesForEntity(String entityType) async {
    final entries = await getEntries();
    return entries.where((e) => e.entityType == entityType).toList();
  }

  /// Get failed entries only
  Future<List<SyncLogEntry>> getFailedEntries() async {
    final entries = await getEntries();
    return entries.where((e) => !e.success).toList();
  }

  /// Get statistics
  Future<SyncLogStats> getStats() async {
    final entries = await getEntries();
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final lastHour = now.subtract(const Duration(hours: 1));

    final recent24h = entries.where((e) => e.timestamp.isAfter(last24Hours));
    final recentHour = entries.where((e) => e.timestamp.isAfter(lastHour));

    return SyncLogStats(
      totalEntries: entries.length,
      successCount: entries.where((e) => e.success).length,
      failureCount: entries.where((e) => !e.success).length,
      last24HoursSuccess: recent24h.where((e) => e.success).length,
      last24HoursFailure: recent24h.where((e) => !e.success).length,
      lastHourSuccess: recentHour.where((e) => e.success).length,
      lastHourFailure: recentHour.where((e) => !e.success).length,
      oldestEntry: entries.isNotEmpty ? entries.first.timestamp : null,
      newestEntry: entries.isNotEmpty ? entries.last.timestamp : null,
    );
  }

  /// Clear all log entries
  Future<void> clear() async {
    try {
      final box = await _getBox();
      await box.delete(_logKey);
      debugPrint('SyncOperationLog: Cleared');
    } catch (e) {
      debugPrint('SyncOperationLog: Failed to clear - $e');
    }
  }

  /// Export log as JSON string (for debugging)
  Future<String> exportAsJson() async {
    final entries = await getEntries();
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }
}

/// Statistics about sync operations
class SyncLogStats {
  final int totalEntries;
  final int successCount;
  final int failureCount;
  final int last24HoursSuccess;
  final int last24HoursFailure;
  final int lastHourSuccess;
  final int lastHourFailure;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;

  const SyncLogStats({
    required this.totalEntries,
    required this.successCount,
    required this.failureCount,
    required this.last24HoursSuccess,
    required this.last24HoursFailure,
    required this.lastHourSuccess,
    required this.lastHourFailure,
    this.oldestEntry,
    this.newestEntry,
  });

  double get successRate =>
      totalEntries > 0 ? successCount / totalEntries * 100 : 0;

  double get last24HoursSuccessRate {
    final total = last24HoursSuccess + last24HoursFailure;
    return total > 0 ? last24HoursSuccess / total * 100 : 0;
  }

  @override
  String toString() {
    return 'SyncLogStats(total: $totalEntries, success: $successCount, '
        'failure: $failureCount, rate: ${successRate.toStringAsFixed(1)}%)';
  }
}

/// Provider for SyncOperationLog
final syncOperationLogProvider = Provider<SyncOperationLog>((ref) {
  return SyncOperationLog();
});
