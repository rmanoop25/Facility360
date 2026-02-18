import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_operation.dart';
import '../../core/sync/sync_queue_service.dart';
import '../../domain/enums/assignment_status.dart';
import '../../domain/enums/sync_status.dart';
import '../datasources/assignment_local_datasource.dart';
import '../datasources/assignment_remote_datasource.dart';
import '../local/adapters/assignment_hive_model.dart';
import '../models/assignment_model.dart';
import '../models/paginated_response.dart';

/// Repository for assignment operations with offline-first support
class AssignmentRepository {
  final AssignmentRemoteDataSource _remoteDataSource;
  final AssignmentLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;
  final SyncQueueService _syncQueueService;

  AssignmentRepository({
    required AssignmentRemoteDataSource remoteDataSource,
    required AssignmentLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
    required SyncQueueService syncQueueService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivityService = connectivityService,
        _syncQueueService = syncQueueService;

  /// Get paginated list of assignments
  Future<PaginatedResponse<AssignmentModel>> getAssignments({
    String? status,
    String? date,
    bool? activeOnly,
    bool? inProgressOnly,
    int page = 1,
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    // For subsequent pages, always fetch from server
    if (page > 1) {
      if (!_connectivityService.isOnline) {
        throw const ApiException(
          message: 'Cannot load more assignments while offline',
        );
      }
      return _remoteDataSource.getAssignments(
        status: status,
        date: date,
        activeOnly: activeOnly,
        inProgressOnly: inProgressOnly,
        page: page,
        perPage: perPage,
      );
    }

    // For first page, try to return local data first
    if (!forceRefresh) {
      final localAssignments = await _localDataSource.getAllAssignments();
      if (localAssignments.isNotEmpty) {
        // Filter local assignments based on parameters
        var filtered = localAssignments;
        if (status != null) {
          filtered = filtered.where((a) => a.status == status).toList();
        }
        if (activeOnly == true) {
          filtered = filtered.where((a) {
            final s = AssignmentStatus.fromValue(a.status);
            return s?.isActive ?? false;
          }).toList();
        }
        if (inProgressOnly == true) {
          filtered = filtered
              .where((a) => a.status == AssignmentStatus.inProgress.value)
              .toList();
        }

        // Return local data and refresh ALL assignments from server in background
        // (no filters to ensure complete cache is maintained)
        if (_connectivityService.isOnline) {
          _refreshFromServer();
        }

        return PaginatedResponse(
          data: filtered.map((a) => a.toModel()).toList(),
          currentPage: 1,
          lastPage: 1,
          perPage: perPage,
          total: filtered.length,
        );
      }
    }

    // No local data or force refresh - fetch from server
    if (_connectivityService.isOnline) {
      try {
        final response = await _remoteDataSource.getAssignments(
          status: status,
          date: date,
          activeOnly: activeOnly,
          inProgressOnly: inProgressOnly,
          page: page,
          perPage: perPage,
        );

        // Cache server response locally (preserves pending local assignments)
        await _localDataSource.replaceAllFromServer(response.data);

        // Return merged data from Hive (includes both server and local pending assignments)
        // This ensures local unsynced items are displayed alongside server data
        final mergedAssignments = await _localDataSource.getAllAssignments();
        var filtered = mergedAssignments;
        if (status != null) {
          filtered = filtered.where((a) => a.status == status).toList();
        }
        if (activeOnly == true) {
          filtered = filtered.where((a) {
            final s = AssignmentStatus.fromValue(a.status);
            return s?.isActive ?? false;
          }).toList();
        }
        if (inProgressOnly == true) {
          filtered = filtered
              .where((a) => a.status == AssignmentStatus.inProgress.value)
              .toList();
        }

        return PaginatedResponse(
          data: filtered.map((a) => a.toModel()).toList(),
          currentPage: response.currentPage,
          lastPage: response.lastPage,
          perPage: response.perPage,
          total: filtered.length,
        );
      } on ApiException {
        // If API fails, try local data
        final localAssignments = await _localDataSource.getAllAssignments();
        if (localAssignments.isNotEmpty) {
          return PaginatedResponse.fromList(
            localAssignments.map((a) => a.toModel()).toList(),
          );
        }
        rethrow;
      }
    }

    // Offline - return local data
    final localAssignments = await _localDataSource.getAllAssignments();
    if (localAssignments.isEmpty) {
      throw const ApiException(
        message: 'No assignments available. Please connect to the internet.',
      );
    }

    return PaginatedResponse.fromList(
      localAssignments.map((a) => a.toModel()).toList(),
    );
  }

  /// Get a single assignment by issue ID
  Future<AssignmentModel> getAssignment(int issueId) async {
    // Check local cache first
    final localAssignment =
        await _localDataSource.getAssignmentByIssueId(issueId);

    // If local assignment has pending sync, return it without overwriting
    if (localAssignment != null && localAssignment.needsSync) {
      debugPrint('AssignmentRepository: Returning local assignment for issue $issueId with pending sync');
      return localAssignment.toModel();
    }

    // Try server if online
    if (_connectivityService.isOnline) {
      try {
        final serverAssignment =
            await _remoteDataSource.getAssignment(issueId);

        // Update local cache (safe because we checked needsSync above)
        if (localAssignment != null) {
          await _localDataSource.updateFromServer(
              localAssignment.localId, serverAssignment);
        } else {
          // Save to local
          final hiveModel = AssignmentHiveModel.fromModel(
            serverAssignment,
            localId: 'server_${serverAssignment.id}',
          );
          await _localDataSource.saveAssignment(hiveModel);
        }

        return serverAssignment;
      } on ApiException catch (e) {
        if (e.statusCode == 404 && localAssignment != null) {
          return localAssignment.toModel();
        }
        rethrow;
      }
    }

    // Offline - get from local storage
    if (localAssignment != null) {
      return localAssignment.toModel();
    }

    throw const ApiException(
      message: 'Assignment not found. Please connect to the internet.',
    );
  }

  /// Start work on assignment
  Future<AssignmentModel> startWork(int issueId) async {
    final localAssignment =
        await _localDataSource.getAssignmentByIssueId(issueId);

    if (_connectivityService.isOnline) {
      try {
        if (localAssignment != null) {
          await _localDataSource.markAsSyncing(localAssignment.localId);
        }

        final updatedAssignment = await _remoteDataSource.startWork(issueId);

        if (localAssignment != null) {
          await _localDataSource.updateFromServer(
              localAssignment.localId, updatedAssignment);
        }

        return updatedAssignment;
      } on ApiException {
        if (localAssignment != null) {
          await _localDataSource.markAsFailed(localAssignment.localId);
        }
        rethrow;
      }
    }

    // Offline - update locally and queue for sync
    if (localAssignment == null) {
      throw const ApiException(
        message: 'Cannot start work while offline. Assignment not cached.',
      );
    }

    await _localDataSource.updateStatus(
        localAssignment.localId, AssignmentStatus.inProgress);
    await _queueStatusSync(
        localAssignment.localId, issueId, 'start', localAssignment);

    return localAssignment.toModel().copyWith(
          status: AssignmentStatus.inProgress,
          startedAt: DateTime.now(),
          syncStatus: SyncStatus.pending,
        );
  }

  /// Hold work on assignment
  Future<AssignmentModel> holdWork(int issueId, {String? reason}) async {
    final localAssignment =
        await _localDataSource.getAssignmentByIssueId(issueId);

    if (_connectivityService.isOnline) {
      try {
        if (localAssignment != null) {
          await _localDataSource.markAsSyncing(localAssignment.localId);
        }

        final updatedAssignment =
            await _remoteDataSource.holdWork(issueId, reason: reason);

        if (localAssignment != null) {
          await _localDataSource.updateFromServer(
              localAssignment.localId, updatedAssignment);
        }

        return updatedAssignment;
      } on ApiException {
        if (localAssignment != null) {
          await _localDataSource.markAsFailed(localAssignment.localId);
        }
        rethrow;
      }
    }

    // Offline - update locally and queue for sync
    if (localAssignment == null) {
      throw const ApiException(
        message: 'Cannot hold work while offline. Assignment not cached.',
      );
    }

    await _localDataSource.updateStatus(
        localAssignment.localId, AssignmentStatus.onHold);
    if (reason != null) {
      await _localDataSource.setNotes(localAssignment.localId, reason);
    }
    await _queueStatusSync(
        localAssignment.localId, issueId, 'hold', localAssignment,
        reason: reason);

    return localAssignment.toModel().copyWith(
          status: AssignmentStatus.onHold,
          heldAt: DateTime.now(),
          notes: reason,
          syncStatus: SyncStatus.pending,
        );
  }

  /// Resume work on assignment
  Future<AssignmentModel> resumeWork(int issueId) async {
    final localAssignment =
        await _localDataSource.getAssignmentByIssueId(issueId);

    if (_connectivityService.isOnline) {
      try {
        if (localAssignment != null) {
          await _localDataSource.markAsSyncing(localAssignment.localId);
        }

        final updatedAssignment = await _remoteDataSource.resumeWork(issueId);

        if (localAssignment != null) {
          await _localDataSource.updateFromServer(
              localAssignment.localId, updatedAssignment);
        }

        return updatedAssignment;
      } on ApiException {
        if (localAssignment != null) {
          await _localDataSource.markAsFailed(localAssignment.localId);
        }
        rethrow;
      }
    }

    // Offline - update locally and queue for sync
    if (localAssignment == null) {
      throw const ApiException(
        message: 'Cannot resume work while offline. Assignment not cached.',
      );
    }

    await _localDataSource.updateStatus(
        localAssignment.localId, AssignmentStatus.inProgress);
    await _queueStatusSync(
        localAssignment.localId, issueId, 'resume', localAssignment);

    return localAssignment.toModel().copyWith(
          status: AssignmentStatus.inProgress,
          resumedAt: DateTime.now(),
          syncStatus: SyncStatus.pending,
        );
  }

  /// Finish work on assignment
  Future<AssignmentModel> finishWork(
    int issueId, {
    String? notes,
    List<File>? proofs,
    List<ConsumableUsage>? consumables,
  }) async {
    final localAssignment =
        await _localDataSource.getAssignmentByIssueId(issueId);

    if (_connectivityService.isOnline) {
      try {
        if (localAssignment != null) {
          await _localDataSource.markAsSyncing(localAssignment.localId);
        }

        final updatedAssignment = await _remoteDataSource.finishWork(
          issueId,
          notes: notes,
          proofs: proofs,
          consumables: consumables,
        );

        if (localAssignment != null) {
          await _localDataSource.updateFromServer(
              localAssignment.localId, updatedAssignment);
        }

        return updatedAssignment;
      } on ApiException {
        if (localAssignment != null) {
          await _localDataSource.markAsFailed(localAssignment.localId);
        }
        rethrow;
      }
    }

    // Offline - save proofs locally and queue for sync
    if (localAssignment == null) {
      throw const ApiException(
        message: 'Cannot finish work while offline. Assignment not cached.',
      );
    }

    // Save proof paths locally
    final proofPaths = proofs?.map((f) => f.path).toList() ?? [];
    if (proofPaths.isNotEmpty) {
      await _localDataSource.addLocalProofs(localAssignment.localId, proofPaths);
    }
    if (notes != null) {
      await _localDataSource.setNotes(localAssignment.localId, notes);
    }

    await _localDataSource.updateStatus(
        localAssignment.localId, AssignmentStatus.finished);
    await _queueFinishSync(localAssignment.localId, issueId, localAssignment,
        notes: notes,
        proofPaths: proofPaths,
        consumables: consumables);

    return localAssignment.toModel().copyWith(
          status: AssignmentStatus.finished,
          finishedAt: DateTime.now(),
          notes: notes,
          syncStatus: SyncStatus.pending,
        );
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    return _localDataSource.getPendingSyncCount();
  }

  /// Get assignments from local cache only (instant, no network)
  /// Used for WhatsApp-like instant display on app start
  Future<List<AssignmentModel>> getCachedAssignments() async {
    final localAssignments = await _localDataSource.getAllAssignments();
    return localAssignments.map((a) => a.toModel()).toList()
      ..sort((a, b) => (b.scheduledDate ?? DateTime.now()).compareTo(a.scheduledDate ?? DateTime.now()));
  }

  /// Refresh ALL assignments from server (background operation)
  /// No filters are used to ensure complete cache is maintained
  Future<void> _refreshFromServer() async {
    try {
      debugPrint('AssignmentRepository: Refreshing all assignments from server');
      final response = await _remoteDataSource.getAssignments(
        // No filters - fetch ALL assignments for complete cache
      );
      await _localDataSource.replaceAllFromServer(response.data);
      debugPrint(
          'AssignmentRepository: Refreshed ${response.data.length} assignments');
    } catch (e) {
      debugPrint('AssignmentRepository: Background refresh failed - $e');
    }
  }

  /// Queue status change for sync
  Future<void> _queueStatusSync(
    String localId,
    int issueId,
    String action,
    AssignmentHiveModel assignment, {
    String? reason,
  }) async {
    await _syncQueueService.enqueue(
      type: SyncOperationType.update,
      entity: SyncEntityType.assignment,
      localId: localId,
      data: {
        'issue_id': issueId,
        'action': action,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Queue finish work for sync
  Future<void> _queueFinishSync(
    String localId,
    int issueId,
    AssignmentHiveModel assignment, {
    String? notes,
    List<String>? proofPaths,
    List<ConsumableUsage>? consumables,
  }) async {
    await _syncQueueService.enqueue(
      type: SyncOperationType.update,
      entity: SyncEntityType.assignment,
      localId: localId,
      data: {
        'issue_id': issueId,
        'action': 'finish',
        if (notes != null) 'notes': notes,
        if (proofPaths != null && proofPaths.isNotEmpty)
          'proof_paths': proofPaths,
        if (consumables != null && consumables.isNotEmpty)
          'consumables': consumables.map((c) => c.toJson()).toList(),
      },
    );
  }

  /// Sync a specific assignment action (called by sync queue service)
  Future<void> syncAssignmentAction(
      String localId, Map<String, dynamic> data) async {
    final issueId = data['issue_id'] as int;
    final action = data['action'] as String;

    await _localDataSource.markAsSyncing(localId);

    try {
      AssignmentModel updatedAssignment;

      switch (action) {
        case 'start':
          updatedAssignment = await _remoteDataSource.startWork(issueId);
          break;
        case 'hold':
          updatedAssignment = await _remoteDataSource.holdWork(
            issueId,
            reason: data['reason'] as String?,
          );
          break;
        case 'resume':
          updatedAssignment = await _remoteDataSource.resumeWork(issueId);
          break;
        case 'finish':
          // Convert local proof paths to files
          final proofPaths =
              (data['proof_paths'] as List<dynamic>?)?.cast<String>() ?? [];
          final proofFiles = proofPaths
              .map((path) => File(path))
              .where((file) => file.existsSync())
              .toList();

          final consumablesData =
              (data['consumables'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final consumables = consumablesData
              .map((c) => ConsumableUsage(
                    consumableId: c['consumable_id'] as int,
                    quantity: c['quantity'] as int,
                    notes: c['notes'] as String?,
                  ))
              .toList();

          updatedAssignment = await _remoteDataSource.finishWork(
            issueId,
            notes: data['notes'] as String?,
            proofs: proofFiles.isNotEmpty ? proofFiles : null,
            consumables: consumables.isNotEmpty ? consumables : null,
          );
          break;
        default:
          throw ApiException(message: 'Unknown action: $action');
      }

      await _localDataSource.updateFromServer(localId, updatedAssignment);
      debugPrint('AssignmentRepository: Successfully synced $action for $localId');
    } on ApiException catch (e) {
      debugPrint('AssignmentRepository: Sync failed for $localId - ${e.message}');
      await _localDataSource.markAsFailed(localId);
      rethrow;
    }
  }

  /// Clear all local assignments (for logout)
  Future<void> clearLocalData() async {
    await _localDataSource.deleteAllAssignments();
  }
}

/// Provider for AssignmentRepository
final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  final remoteDataSource = ref.watch(assignmentRemoteDataSourceProvider);
  final localDataSource = ref.watch(assignmentLocalDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncQueueService = ref.watch(syncQueueServiceProvider);

  return AssignmentRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    connectivityService: connectivityService,
    syncQueueService: syncQueueService,
  );
});
