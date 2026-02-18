import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/enums/assignment_status.dart';
import '../local/adapters/assignment_hive_model.dart';
import '../models/assignment_model.dart';

/// Local data source for assignment operations using Hive
class AssignmentLocalDataSource {
  static const String _boxName = 'assignments';

  /// Get or open the assignments box
  Future<Box<AssignmentHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<AssignmentHiveModel>(_boxName);
    }
    return Hive.openBox<AssignmentHiveModel>(_boxName);
  }

  /// Save an assignment to local storage
  Future<void> saveAssignment(AssignmentHiveModel assignment) async {
    final box = await _getBox();
    await box.put(assignment.localId, assignment);
    debugPrint(
      'AssignmentLocalDataSource: Saved assignment ${assignment.localId}',
    );
  }

  /// Save multiple assignments to local storage
  Future<void> saveAssignments(List<AssignmentHiveModel> assignments) async {
    final box = await _getBox();
    final map = {for (var a in assignments) a.localId: a};
    await box.putAll(map);
    debugPrint(
      'AssignmentLocalDataSource: Saved ${assignments.length} assignments',
    );
  }

  /// Get all assignments from local storage
  Future<List<AssignmentHiveModel>> getAllAssignments() async {
    final box = await _getBox();
    return box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get an assignment by local ID
  Future<AssignmentHiveModel?> getAssignmentByLocalId(String localId) async {
    final box = await _getBox();
    return box.get(localId);
  }

  /// Get an assignment by server ID
  Future<AssignmentHiveModel?> getAssignmentByServerId(int serverId) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((a) => a.serverId == serverId);
    } catch (_) {
      return null;
    }
  }

  /// Get an assignment by issue ID
  Future<AssignmentHiveModel?> getAssignmentByIssueId(int issueId) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((a) => a.issueId == issueId);
    } catch (_) {
      return null;
    }
  }

  /// Get all assignments for a specific issue ID
  Future<List<AssignmentHiveModel>> getAssignmentsByIssueId(int issueId) async {
    final box = await _getBox();
    return box.values.where((a) => a.issueId == issueId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get assignments that need to be synced
  Future<List<AssignmentHiveModel>> getPendingSyncAssignments() async {
    final box = await _getBox();
    return box.values.where((a) => a.needsSync).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get assignments filtered by status
  Future<List<AssignmentHiveModel>> getAssignmentsByStatus(
    String status,
  ) async {
    final box = await _getBox();
    return box.values.where((a) => a.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get active assignments (not completed/cancelled)
  Future<List<AssignmentHiveModel>> getActiveAssignments() async {
    final box = await _getBox();
    return box.values.where((a) {
      final status = AssignmentStatus.fromValue(a.status);
      return status?.isActive ?? false;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Mark an assignment as synced with server ID
  Future<void> markAsSynced(String localId, int serverId) async {
    final box = await _getBox();
    final assignment = box.get(localId);
    if (assignment != null) {
      assignment.markAsSynced(serverId);
      await assignment.save();
      debugPrint(
        'AssignmentLocalDataSource: Marked $localId as synced (serverId: $serverId)',
      );
    }
  }

  /// Mark an assignment sync as failed
  Future<void> markAsFailed(String localId) async {
    final box = await _getBox();
    final assignment = box.get(localId);
    if (assignment != null) {
      assignment.markAsFailed();
      await assignment.save();
      debugPrint('AssignmentLocalDataSource: Marked $localId as failed');
    }
  }

  /// Mark an assignment as syncing
  Future<void> markAsSyncing(String localId) async {
    final box = await _getBox();
    final assignment = box.get(localId);
    if (assignment != null) {
      assignment.markAsSyncing();
      await assignment.save();
    }
  }

  /// Update assignment status locally
  Future<void> updateStatus(String localId, AssignmentStatus newStatus) async {
    final box = await _getBox();
    final assignment = box.get(localId);
    if (assignment != null) {
      assignment.updateStatus(newStatus);
      await assignment.save();
      debugPrint(
        'AssignmentLocalDataSource: Updated $localId status to ${newStatus.value}',
      );
    }
  }

  /// Update assignment from server response
  Future<void> updateFromServer(
    String localId,
    AssignmentModel serverAssignment,
  ) async {
    final box = await _getBox();
    final assignment = box.get(localId);
    if (assignment != null) {
      assignment.updateFromServer(serverAssignment);
      await assignment.save();
      debugPrint('AssignmentLocalDataSource: Updated $localId from server');
    }
  }

  /// Delete an assignment by local ID
  Future<void> deleteAssignment(String localId) async {
    final box = await _getBox();
    await box.delete(localId);
    debugPrint('AssignmentLocalDataSource: Deleted assignment $localId');
  }

  /// Delete all assignments (for logout/clear data)
  Future<void> deleteAllAssignments() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('AssignmentLocalDataSource: Deleted all assignments');
  }

  /// Get count of pending sync assignments
  Future<int> getPendingSyncCount() async {
    final box = await _getBox();
    return box.values.where((a) => a.needsSync).length;
  }

  /// Check if an assignment exists locally
  Future<bool> assignmentExists(String localId) async {
    final box = await _getBox();
    return box.containsKey(localId);
  }

  /// Replace all cached assignments with server data
  /// IMPORTANT: Preserves local assignments with pending sync (needsSync = true)
  Future<void> replaceAllFromServer(
    List<AssignmentModel> serverAssignments,
  ) async {
    final box = await _getBox();

    // Get ALL assignments that need to be synced (not just those without serverId)
    // This is critical for preserving offline changes to existing assignments
    final pendingSyncAssignments = box.values
        .where((a) => a.needsSync)
        .toList();

    debugPrint(
      'AssignmentLocalDataSource: Found ${pendingSyncAssignments.length} pending sync assignments to preserve',
    );

    // Clear the box
    await box.clear();

    // Add server assignments, but check for pending sync conflicts
    for (final serverAssignment in serverAssignments) {
      final localId =
          serverAssignment.localId ?? 'server_${serverAssignment.id}';

      // Check if we have a pending sync version of this assignment
      final pendingLocal = pendingSyncAssignments.firstWhere(
        (a) => a.serverId == serverAssignment.id || a.localId == localId,
        orElse: () =>
            AssignmentHiveModel.fromModel(serverAssignment, localId: localId),
      );

      if (pendingLocal.needsSync) {
        // Preserve the local version with pending changes
        debugPrint(
          'AssignmentLocalDataSource: Preserving pending sync assignment ${pendingLocal.localId} (status: ${pendingLocal.status})',
        );
        await box.put(pendingLocal.localId, pendingLocal);
      } else {
        // Use server version
        final hiveModel = AssignmentHiveModel.fromModel(
          serverAssignment,
          localId: localId,
        );
        await box.put(hiveModel.localId, hiveModel);
      }
    }

    // Re-add any remaining pending sync assignments that weren't in server response
    // (e.g., locally created assignments)
    for (final localAssignment in pendingSyncAssignments) {
      if (!box.containsKey(localAssignment.localId)) {
        await box.put(localAssignment.localId, localAssignment);
        debugPrint(
          'AssignmentLocalDataSource: Re-added pending sync assignment ${localAssignment.localId}',
        );
      }
    }

    debugPrint(
      'AssignmentLocalDataSource: Replaced with ${serverAssignments.length} server assignments (preserved ${pendingSyncAssignments.length} pending)',
    );
  }

  /// Add local proof paths to an assignment
  Future<void> addLocalProofs(String localId, List<String> proofPaths) async {
    final box = await _getBox();
    final assignment = box.get(localId);
    if (assignment != null) {
      assignment.localProofPaths = [
        ...assignment.localProofPaths,
        ...proofPaths,
      ];
      await assignment.save();
      debugPrint(
        'AssignmentLocalDataSource: Added ${proofPaths.length} proofs to $localId',
      );
    }
  }

  /// Set notes for an assignment
  Future<void> setNotes(String localId, String? notes) async {
    final box = await _getBox();
    final assignment = box.get(localId);
    if (assignment != null) {
      assignment.notes = notes;
      await assignment.save();
    }
  }

  /// Migrate assignment from localId key to server_* key after successful sync
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

    debugPrint(
      'AssignmentLocalDataSource: Migrated $oldLocalId to $newLocalId',
    );
  }
}

/// Provider for AssignmentLocalDataSource
final assignmentLocalDataSourceProvider = Provider<AssignmentLocalDataSource>((
  ref,
) {
  return AssignmentLocalDataSource();
});
