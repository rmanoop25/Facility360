import 'package:flutter/foundation.dart';

/// Strategies for resolving sync conflicts
enum ConflictStrategy {
  /// Server data always wins (used for master data)
  serverWins,

  /// Client data always wins
  clientWins,

  /// Most recent update wins based on timestamp
  lastWriteWins,

  /// Merge changes from both sides (manual resolution)
  merge,
}

/// Represents a sync conflict between local and server data
class SyncConflict<T> {
  final String localId;
  final T? localData;
  final T? serverData;
  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;
  final ConflictStrategy strategy;

  const SyncConflict({
    required this.localId,
    this.localData,
    this.serverData,
    this.localUpdatedAt,
    this.serverUpdatedAt,
    required this.strategy,
  });

  /// Check if there is an actual conflict
  bool get hasConflict => localData != null && serverData != null;

  /// Determine which data wins based on strategy
  T? get resolvedData {
    if (!hasConflict) {
      return localData ?? serverData;
    }

    switch (strategy) {
      case ConflictStrategy.serverWins:
        return serverData;

      case ConflictStrategy.clientWins:
        return localData;

      case ConflictStrategy.lastWriteWins:
        if (localUpdatedAt == null) return serverData;
        if (serverUpdatedAt == null) return localData;
        return localUpdatedAt!.isAfter(serverUpdatedAt!) ? localData : serverData;

      case ConflictStrategy.merge:
        // Merge needs manual handling - return server by default
        return serverData;
    }
  }

  /// Check if local data wins
  bool get localWins => resolvedData == localData;
}

/// Service for resolving sync conflicts between local and server data
class ConflictResolver {
  ConflictResolver();

  /// Get the conflict strategy for an entity type
  ConflictStrategy getStrategyForEntity(String entityType) {
    switch (entityType) {
      // Master data: Server always wins
      case 'category':
      case 'consumable':
        return ConflictStrategy.serverWins;

      // User content: Last write wins
      case 'issue':
      case 'assignment':
        return ConflictStrategy.lastWriteWins;

      // Admin changes on users: Server wins for critical fields
      case 'tenant':
      case 'service_provider':
        return ConflictStrategy.serverWins;

      // Default: Server wins
      default:
        return ConflictStrategy.serverWins;
    }
  }

  /// Resolve a conflict between local and server data
  SyncConflict<Map<String, dynamic>> resolve({
    required String entityType,
    required String localId,
    Map<String, dynamic>? localData,
    Map<String, dynamic>? serverData,
    DateTime? localUpdatedAt,
    DateTime? serverUpdatedAt,
  }) {
    final strategy = getStrategyForEntity(entityType);

    final conflict = SyncConflict<Map<String, dynamic>>(
      localId: localId,
      localData: localData,
      serverData: serverData,
      localUpdatedAt: localUpdatedAt,
      serverUpdatedAt: serverUpdatedAt,
      strategy: strategy,
    );

    if (conflict.hasConflict) {
      debugPrint(
        'ConflictResolver: Conflict detected for $entityType:$localId - '
        'using ${strategy.name} strategy, ${conflict.localWins ? "local" : "server"} wins',
      );
    }

    return conflict;
  }

  /// Merge issue data (preserves local changes for non-critical fields)
  Map<String, dynamic> mergeIssueData({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
  }) {
    // Server-controlled fields (admin/system managed):
    // id, status, service_provider_id, assigned_at, started_at,
    // completed_at, approved_at, cancelled_at, created_at, updated_at
    // These are always taken from server data

    // Start with server data
    final merged = Map<String, dynamic>.from(serverData);

    // Preserve local changes for user-editable fields
    final userFields = ['title', 'description', 'priority', 'address'];
    for (final field in userFields) {
      if (localData.containsKey(field) && localData[field] != null) {
        // Only preserve if local was modified more recently
        final localUpdated = DateTime.tryParse(localData['updated_at'] ?? '');
        final serverUpdated = DateTime.tryParse(serverData['updated_at'] ?? '');

        if (localUpdated != null &&
            serverUpdated != null &&
            localUpdated.isAfter(serverUpdated)) {
          merged[field] = localData[field];
        }
      }
    }

    return merged;
  }

  /// Merge assignment data
  Map<String, dynamic> mergeAssignmentData({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
  }) {
    // Assignments are primarily server-controlled
    // Local changes are mainly status transitions
    final merged = Map<String, dynamic>.from(serverData);

    // Preserve local notes if more recent
    if (localData['notes'] != null) {
      final localUpdated = DateTime.tryParse(localData['updated_at'] ?? '');
      final serverUpdated = DateTime.tryParse(serverData['updated_at'] ?? '');

      if (localUpdated != null &&
          (serverUpdated == null || localUpdated.isAfter(serverUpdated))) {
        merged['notes'] = localData['notes'];
      }
    }

    // Preserve local consumables if not synced
    if (localData['consumables'] != null &&
        localData['sync_status'] == 'pending') {
      merged['consumables'] = localData['consumables'];
    }

    return merged;
  }

  /// Check if local data should be overwritten by server
  bool shouldOverwriteLocal({
    required String entityType,
    required DateTime? localUpdatedAt,
    required DateTime? serverUpdatedAt,
  }) {
    final strategy = getStrategyForEntity(entityType);

    switch (strategy) {
      case ConflictStrategy.serverWins:
        return true;

      case ConflictStrategy.clientWins:
        return false;

      case ConflictStrategy.lastWriteWins:
        if (localUpdatedAt == null) return true;
        if (serverUpdatedAt == null) return false;
        return serverUpdatedAt.isAfter(localUpdatedAt);

      case ConflictStrategy.merge:
        // Merge strategy needs manual handling
        return false;
    }
  }
}
