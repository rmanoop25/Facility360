import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/enums/issue_priority.dart';
import '../local/adapters/issue_hive_model.dart';
import '../models/issue_model.dart';

/// Local data source for issue operations using Hive
class IssueLocalDataSource {
  static const String _boxName = 'issues';

  /// Get or open the issues box
  Future<Box<IssueHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<IssueHiveModel>(_boxName);
    }
    return Hive.openBox<IssueHiveModel>(_boxName);
  }

  /// Save an issue to local storage
  Future<void> saveIssue(IssueHiveModel issue) async {
    final box = await _getBox();
    await box.put(issue.localId, issue);
    debugPrint('IssueLocalDataSource: Saved issue ${issue.localId}');
  }

  /// Save multiple issues to local storage
  Future<void> saveIssues(List<IssueHiveModel> issues) async {
    final box = await _getBox();
    final map = {for (var issue in issues) issue.localId: issue};
    await box.putAll(map);
    debugPrint('IssueLocalDataSource: Saved ${issues.length} issues');
  }

  /// Get all issues from local storage
  Future<List<IssueHiveModel>> getAllIssues() async {
    final box = await _getBox();
    return box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get an issue by local ID
  Future<IssueHiveModel?> getIssueByLocalId(String localId) async {
    final box = await _getBox();
    return box.get(localId);
  }

  /// Get an issue by server ID
  Future<IssueHiveModel?> getIssueByServerId(int serverId) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((issue) => issue.serverId == serverId);
    } catch (_) {
      return null;
    }
  }

  /// Get issues that need to be synced
  Future<List<IssueHiveModel>> getPendingSyncIssues() async {
    final box = await _getBox();
    return box.values.where((issue) => issue.needsSync).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get issues filtered by status
  Future<List<IssueHiveModel>> getIssuesByStatus(String status) async {
    final box = await _getBox();
    return box.values.where((issue) => issue.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Mark an issue as synced with server ID
  Future<void> markAsSynced(String localId, int serverId) async {
    final box = await _getBox();
    final issue = box.get(localId);
    if (issue != null) {
      issue.markAsSynced(serverId);
      await issue.save();
      debugPrint('IssueLocalDataSource: Marked $localId as synced (serverId: $serverId)');
    }
  }

  /// Migrate issue from localId key to server_* key after successful sync
  /// This prevents duplicate entries when server data is refreshed
  Future<void> migrateToServerKey(String oldLocalId, int serverId) async {
    final box = await _getBox();
    final existing = box.get(oldLocalId);
    if (existing == null) return;

    final newLocalId = 'server_$serverId';

    // Skip if already using server_* key
    if (oldLocalId == newLocalId) return;

    // Update the localId field and ensure synced state
    existing.localId = newLocalId;
    existing.serverId = serverId;
    existing.syncStatus = 'synced';

    // Delete old entry and add with new key
    await box.delete(oldLocalId);
    await box.put(newLocalId, existing);

    debugPrint('IssueLocalDataSource: Migrated $oldLocalId to $newLocalId');
  }

  /// Mark an issue sync as failed
  Future<void> markAsFailed(String localId) async {
    final box = await _getBox();
    final issue = box.get(localId);
    if (issue != null) {
      issue.markAsFailed();
      await issue.save();
      debugPrint('IssueLocalDataSource: Marked $localId as failed');
    }
  }

  /// Mark an issue as syncing
  Future<void> markAsSyncing(String localId) async {
    final box = await _getBox();
    final issue = box.get(localId);
    if (issue != null) {
      issue.markAsSyncing();
      await issue.save();
    }
  }

  /// Update issue from server response
  Future<void> updateFromServer(String localId, IssueModel serverIssue) async {
    final box = await _getBox();
    final issue = box.get(localId);
    if (issue != null) {
      issue.updateFromServer(serverIssue);
      await issue.save();
      debugPrint('IssueLocalDataSource: Updated $localId from server');
    }
  }

  /// Delete an issue by local ID
  Future<void> deleteIssue(String localId) async {
    final box = await _getBox();
    await box.delete(localId);
    debugPrint('IssueLocalDataSource: Deleted issue $localId');
  }

  /// Delete all issues (for logout/clear data)
  Future<void> deleteAllIssues() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('IssueLocalDataSource: Deleted all issues');
  }

  /// Get count of pending sync issues
  Future<int> getPendingSyncCount() async {
    final box = await _getBox();
    return box.values.where((issue) => issue.needsSync).length;
  }

  /// Check if an issue exists locally
  Future<bool> issueExists(String localId) async {
    final box = await _getBox();
    return box.containsKey(localId);
  }

  /// Replace all cached issues with server data
  /// IMPORTANT: Preserves local issues with pending sync (needsSync = true)
  /// CRITICAL: Handles deduplication to prevent duplicate issues after sync
  Future<void> replaceAllFromServer(List<IssueModel> serverIssues) async {
    final box = await _getBox();

    // Step 1: Get ALL issues that need to be synced (not just those without serverId)
    // This is critical for preserving offline changes to existing issues
    final pendingSyncIssues = box.values
        .where((issue) => issue.needsSync)
        .toList();

    debugPrint('IssueLocalDataSource: Found ${pendingSyncIssues.length} pending sync issues to preserve');

    // Step 2: Build set of server IDs for deduplication
    final serverIds = serverIssues.map((i) => i.id).toSet();

    // Step 3: Clear the box
    await box.clear();

    // Step 4: Add server issues, but check for pending sync conflicts
    for (final serverIssue in serverIssues) {
      final localId = serverIssue.localId ?? 'server_${serverIssue.id}';

      // Check if we have a pending sync version of this issue
      final pendingLocal = pendingSyncIssues.firstWhere(
        (i) => i.serverId == serverIssue.id || i.localId == localId,
        orElse: () => IssueHiveModel.fromModel(serverIssue, localId: localId),
      );

      if (pendingLocal.needsSync) {
        // Preserve the local version with pending changes
        debugPrint('IssueLocalDataSource: Preserving pending sync issue ${pendingLocal.localId} (status: ${pendingLocal.status})');
        await box.put(pendingLocal.localId, pendingLocal);
      } else {
        // Use server version
        final hiveModel = IssueHiveModel.fromModel(serverIssue, localId: localId);
        await box.put(hiveModel.localId, hiveModel);
      }
    }

    // Step 5: Re-add ONLY pending sync issues that are NOT in server response
    // Skip issues whose serverId is already in server response (prevents duplicates)
    for (final localIssue in pendingSyncIssues) {
      // Skip if server already has this issue (by serverId) - prevents duplicates
      if (localIssue.serverId != null && serverIds.contains(localIssue.serverId)) {
        debugPrint('IssueLocalDataSource: Skipping synced issue ${localIssue.localId} (serverId: ${localIssue.serverId}) - already in server response');
        continue;
      }

      // Only re-add if not already in box (truly local-only issues)
      if (!box.containsKey(localIssue.localId)) {
        await box.put(localIssue.localId, localIssue);
        debugPrint('IssueLocalDataSource: Re-added pending sync issue ${localIssue.localId}');
      }
    }

    debugPrint('IssueLocalDataSource: Replaced with ${serverIssues.length} server issues (preserved pending: ${pendingSyncIssues.where((i) => i.serverId == null || !serverIds.contains(i.serverId)).length})');
  }

  /// Create a new local issue (before syncing to server)
  Future<IssueHiveModel> createLocalIssue({
    required String localId,
    required String title,
    String? description,
    required List<int> categoryIds,
    String priority = 'medium',
    double? latitude,
    double? longitude,
    String? address,
    List<String> localMediaPaths = const [],
    int? tenantId,
  }) async {
    final issue = IssueHiveModel.createLocal(
      localId: localId,
      title: title,
      description: description,
      categoryIds: categoryIds,
      priority: _priorityFromString(priority),
      latitude: latitude,
      longitude: longitude,
      address: address,
      localMediaPaths: localMediaPaths,
      tenantId: tenantId,
    );

    await saveIssue(issue);
    return issue;
  }

  /// Convert priority string to enum
  IssuePriority _priorityFromString(String priority) {
    return IssuePriority.fromValue(priority) ?? IssuePriority.medium;
  }
}

/// Provider for IssueLocalDataSource
final issueLocalDataSourceProvider = Provider<IssueLocalDataSource>((ref) {
  return IssueLocalDataSource();
});
