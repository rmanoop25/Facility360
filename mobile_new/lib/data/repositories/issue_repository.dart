import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_operation.dart';
import '../../core/sync/sync_queue_service.dart';
import '../../domain/enums/sync_status.dart';
import '../datasources/assignment_local_datasource.dart';
import '../datasources/issue_local_datasource.dart';
import '../datasources/issue_remote_datasource.dart';
import '../local/adapters/issue_hive_model.dart';
import '../models/issue_model.dart';
import '../models/paginated_response.dart';

/// Repository for issue operations with offline-first support
///
/// Strategy:
/// 1. Write to Hive first (instant, works offline)
/// 2. Queue sync operation (if online, sync immediately; if offline, queue for later)
/// 3. Show sync status (clock icon for pending, checkmark for synced)
/// 4. Background sync when connectivity returns
class IssueRepository {
  final IssueRemoteDataSource _remoteDataSource;
  final IssueLocalDataSource _localDataSource;
  final AssignmentLocalDataSource _assignmentLocalDataSource;
  final ConnectivityService _connectivityService;
  final SyncQueueService _syncQueueService;

  IssueRepository({
    required IssueRemoteDataSource remoteDataSource,
    required IssueLocalDataSource localDataSource,
    required AssignmentLocalDataSource assignmentLocalDataSource,
    required ConnectivityService connectivityService,
    required SyncQueueService syncQueueService,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _assignmentLocalDataSource = assignmentLocalDataSource,
       _connectivityService = connectivityService,
       _syncQueueService = syncQueueService;

  /// Get paginated list of issues
  ///
  /// Returns local data first, then refreshes from server if online.
  /// For the first page, we show local data immediately and refresh in background.
  /// For subsequent pages, we only fetch from server (pagination doesn't work offline).
  Future<PaginatedResponse<IssueModel>> getIssues({
    String? status,
    String? priority,
    bool? activeOnly,
    int page = 1,
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    // For subsequent pages, always fetch from server
    if (page > 1) {
      if (!_connectivityService.isOnline) {
        throw const ApiException(
          message: 'Cannot load more issues while offline',
        );
      }
      return _remoteDataSource.getIssues(
        status: status,
        priority: priority,
        activeOnly: activeOnly,
        page: page,
        perPage: perPage,
      );
    }

    // For first page, try to return local data first
    if (!forceRefresh) {
      final localIssues = await _localDataSource.getAllIssues();
      if (localIssues.isNotEmpty) {
        // Filter local issues based on parameters
        var filtered = localIssues;
        if (status != null) {
          filtered = filtered.where((i) => i.status == status).toList();
        }
        if (priority != null) {
          filtered = filtered.where((i) => i.priority == priority).toList();
        }

        // Return local data and refresh ALL issues from server in background
        // (no filters to ensure complete cache is maintained)
        if (_connectivityService.isOnline) {
          _refreshFromServer();
        }

        return PaginatedResponse(
          data: filtered.map((i) => i.toModel()).toList(),
          currentPage: 1,
          lastPage: 1, // Unknown until server responds
          perPage: perPage,
          total: filtered.length,
        );
      }
    }

    // No local data or force refresh - fetch from server
    if (_connectivityService.isOnline) {
      try {
        final response = await _remoteDataSource.getIssues(
          status: status,
          priority: priority,
          activeOnly: activeOnly,
          page: page,
          perPage: perPage,
        );

        // Cache server response locally (preserves pending local issues)
        await _localDataSource.replaceAllFromServer(response.data);

        // Return merged data from Hive (includes both server and local pending issues)
        // This ensures local unsynced items are displayed alongside server data
        final mergedIssues = await _localDataSource.getAllIssues();
        var filtered = mergedIssues;
        if (status != null) {
          filtered = filtered.where((i) => i.status == status).toList();
        }
        if (priority != null) {
          filtered = filtered.where((i) => i.priority == priority).toList();
        }

        return PaginatedResponse(
          data: filtered.map((i) => i.toModel()).toList(),
          currentPage: response.currentPage,
          lastPage: response.lastPage,
          perPage: response.perPage,
          total: filtered.length,
        );
      } on ApiException {
        // If API fails, try local data
        final localIssues = await _localDataSource.getAllIssues();
        if (localIssues.isNotEmpty) {
          return PaginatedResponse.fromList(
            localIssues.map((i) => i.toModel()).toList(),
          );
        }
        rethrow;
      }
    }

    // Offline - return local data
    final localIssues = await _localDataSource.getAllIssues();
    if (localIssues.isEmpty) {
      throw const ApiException(
        message: 'No issues available. Please connect to the internet.',
      );
    }

    return PaginatedResponse.fromList(
      localIssues.map((i) => i.toModel()).toList(),
    );
  }

  /// Get a single issue by ID
  Future<IssueModel> getIssue(int id) async {
    // Check local cache first
    final localIssue = await _localDataSource.getIssueByServerId(id);

    // If local issue has pending sync, return it without overwriting
    if (localIssue != null && localIssue.needsSync) {
      debugPrint(
        'IssueRepository: Returning local issue $id with pending sync',
      );
      return localIssue.toModel();
    }

    // Try server if online
    if (_connectivityService.isOnline) {
      try {
        final serverIssue = await _remoteDataSource.getIssue(id);

        // Update local cache (safe because we checked needsSync above)
        if (localIssue != null) {
          await _localDataSource.updateFromServer(
            localIssue.localId,
            serverIssue,
          );
        }

        return serverIssue;
      } on ApiException catch (e) {
        // If not found on server but exists locally (local-only issue), return local
        if (e.statusCode == 404 && localIssue != null) {
          return localIssue.toModel();
        }
        rethrow;
      }
    }

    // Offline - get from local storage
    if (localIssue != null) {
      return localIssue.toModel();
    }

    throw const ApiException(
      message: 'Issue not found. Please connect to the internet.',
    );
  }

  /// Get issue by local ID (for locally created issues)
  Future<IssueModel?> getIssueByLocalId(String localId) async {
    final localIssue = await _localDataSource.getIssueByLocalId(localId);
    return localIssue?.toModel();
  }

  /// Create a new issue (offline-first)
  ///
  /// 1. Generate local ID
  /// 2. Save to Hive immediately with pending sync status
  /// 3. If online, try to sync immediately
  /// 4. If offline, queue for later sync
  Future<IssueModel> createIssue({
    required String title,
    String? description,
    required List<int> categoryIds,
    String priority = 'medium',
    double? latitude,
    double? longitude,
    String? address,
    List<File>? mediaFiles,
    int? tenantId,
  }) async {
    // Generate unique local ID
    final localId = const Uuid().v4();

    // Get local file paths for offline storage
    final localMediaPaths = mediaFiles?.map((f) => f.path).toList() ?? [];

    // Save locally first with pending status
    final localIssue = await _localDataSource.createLocalIssue(
      localId: localId,
      title: title,
      description: description,
      categoryIds: categoryIds,
      priority: priority,
      latitude: latitude,
      longitude: longitude,
      address: address,
      localMediaPaths: localMediaPaths,
      tenantId: tenantId,
    );

    debugPrint('IssueRepository: Created local issue $localId');

    // Try to sync immediately if online
    if (_connectivityService.isOnline) {
      try {
        await _localDataSource.markAsSyncing(localId);

        final serverIssue = await _remoteDataSource.createIssue(
          title: title,
          description: description,
          categoryIds: categoryIds,
          priority: priority,
          latitude: latitude,
          longitude: longitude,
          address: address,
          mediaFiles: mediaFiles,
        );

        // Update local with server data
        await _localDataSource.updateFromServer(localId, serverIssue);
        debugPrint(
          'IssueRepository: Synced issue $localId -> ${serverIssue.id}',
        );

        return serverIssue.copyWith(
          localId: localId,
          syncStatus: SyncStatus.synced,
        );
      } on ApiException catch (e) {
        debugPrint(
          'IssueRepository: Failed to sync issue $localId - ${e.message}',
        );
        await _localDataSource.markAsFailed(localId);

        // Queue for later retry
        await _queueIssueSync(localId, localIssue);

        // Return local version with failed status
        return localIssue.toModel().copyWith(syncStatus: SyncStatus.failed);
      }
    }

    // Offline - queue for later sync
    debugPrint('IssueRepository: Offline - queuing issue $localId for sync');
    await _queueIssueSync(localId, localIssue);

    return localIssue.toModel();
  }

  /// Cancel an issue (offline-first)
  /// If offline, marks locally as cancelled and queues for sync
  Future<IssueModel> cancelIssue(int id, {String? reason}) async {
    // Try to get local issue first
    final localIssue = await _localDataSource.getIssueByServerId(id);

    if (_connectivityService.isOnline) {
      try {
        final cancelledIssue = await _remoteDataSource.cancelIssue(
          id,
          reason: reason,
        );

        // Update local cache
        if (localIssue != null) {
          await _localDataSource.updateFromServer(
            localIssue.localId,
            cancelledIssue,
          );
        }

        return cancelledIssue;
      } catch (e) {
        debugPrint(
          'IssueRepository: Failed to cancel online, falling back to offline - $e',
        );
        // Fall through to offline handling
        if (localIssue == null) rethrow;
      }
    }

    // Offline: Mark locally as cancelled and queue for sync
    if (localIssue == null) {
      throw const ApiException(
        message: 'Issue not found in cache. Please connect to the internet.',
      );
    }

    // Update local issue to cancelled status
    localIssue.status = 'cancelled';
    localIssue.syncStatus = SyncStatus.pending.value;
    await localIssue.save();

    // Queue for sync
    await _syncQueueService.enqueue(
      type: SyncOperationType.delete,
      entity: SyncEntityType.issue,
      localId: localIssue.localId,
      data: {'server_id': id, 'reason': reason},
    );

    debugPrint('IssueRepository: Issue $id cancelled offline, queued for sync');
    return localIssue.toModel();
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    return _localDataSource.getPendingSyncCount();
  }

  /// Get issues from local cache only (instant, no network)
  /// Used for WhatsApp-like instant display on app start
  Future<List<IssueModel>> getCachedIssues() async {
    final localIssues = await _localDataSource.getAllIssues();

    // Convert issues and load their assignments
    final issuesWithAssignments = <IssueModel>[];
    for (final localIssue in localIssues) {
      var issue = localIssue.toModel();

      // If issue has no assignments loaded from fullDataJson, load them separately
      if (issue.assignments.isEmpty && issue.id > 0) {
        try {
          final assignments = await _assignmentLocalDataSource
              .getAssignmentsByIssueId(issue.id);
          if (assignments.isNotEmpty) {
            final assignmentModels = assignments
                .map((a) => a.toModel())
                .toList();
            issue = issue.copyWith(assignments: assignmentModels);
          }
        } catch (e) {
          debugPrint(
            'IssueRepository: Failed to load assignments for issue ${issue.id} - $e',
          );
          // Continue without assignments
        }
      }

      issuesWithAssignments.add(issue);
    }

    return issuesWithAssignments..sort(
      (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
        a.createdAt ?? DateTime.now(),
      ),
    );
  }

  /// Refresh ALL issues from server (background operation)
  /// No filters are used to ensure complete cache is maintained
  Future<void> _refreshFromServer() async {
    try {
      debugPrint('IssueRepository: Refreshing all issues from server');
      final response = await _remoteDataSource.getIssues(
        // No filters - fetch ALL issues for complete cache
      );
      await _localDataSource.replaceAllFromServer(response.data);
      debugPrint('IssueRepository: Refreshed ${response.data.length} issues');
    } catch (e) {
      debugPrint('IssueRepository: Background refresh failed - $e');
    }
  }

  /// Queue issue for sync
  Future<void> _queueIssueSync(String localId, IssueHiveModel issue) async {
    await _syncQueueService.enqueue(
      type: SyncOperationType.create,
      entity: SyncEntityType.issue,
      localId: localId,
      data: {
        'title': issue.title,
        'description': issue.description,
        'category_ids': issue.categoryIds,
        'priority': issue.priority,
        'latitude': issue.latitude,
        'longitude': issue.longitude,
        'address': issue.address,
        'local_media_paths': issue.localMediaPaths,
      },
    );
  }

  /// Sync a specific issue (called by sync queue service)
  Future<void> syncIssue(String localId, Map<String, dynamic> data) async {
    final localIssue = await _localDataSource.getIssueByLocalId(localId);
    if (localIssue == null) {
      debugPrint('IssueRepository: Issue $localId not found for sync');
      return;
    }

    await _localDataSource.markAsSyncing(localId);

    try {
      // Convert local media paths to files
      final localMediaPaths =
          (data['local_media_paths'] as List<dynamic>?)
              ?.map((p) => p.toString())
              .toList() ??
          [];
      final mediaFiles = localMediaPaths
          .map((path) => File(path))
          .where((file) => file.existsSync())
          .toList();

      final serverIssue = await _remoteDataSource.createIssue(
        title: data['title'] as String,
        description: data['description'] as String?,
        categoryIds: List<int>.from(data['category_ids'] as List),
        priority: data['priority'] as String? ?? 'medium',
        latitude: data['latitude'] as double?,
        longitude: data['longitude'] as double?,
        address: data['address'] as String?,
        mediaFiles: mediaFiles.isNotEmpty ? mediaFiles : null,
      );

      await _localDataSource.updateFromServer(localId, serverIssue);
      debugPrint('IssueRepository: Successfully synced issue $localId');
    } on ApiException catch (e) {
      debugPrint('IssueRepository: Sync failed for $localId - ${e.message}');
      await _localDataSource.markAsFailed(localId);
      rethrow;
    }
  }

  /// Clear all local issues (for logout)
  Future<void> clearLocalData() async {
    await _localDataSource.deleteAllIssues();
  }
}

/// Provider for IssueRepository
final issueRepositoryProvider = Provider<IssueRepository>((ref) {
  final remoteDataSource = ref.watch(issueRemoteDataSourceProvider);
  final localDataSource = ref.watch(issueLocalDataSourceProvider);
  final assignmentLocalDataSource = ref.watch(
    assignmentLocalDataSourceProvider,
  );
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncQueueService = ref.watch(syncQueueServiceProvider);

  return IssueRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    assignmentLocalDataSource: assignmentLocalDataSource,
    connectivityService: connectivityService,
    syncQueueService: syncQueueService,
  );
});
