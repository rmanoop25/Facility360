import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/assignment_local_datasource.dart';
import '../../data/datasources/category_local_datasource.dart';
import '../../data/datasources/consumable_local_datasource.dart';
import '../../data/datasources/issue_local_datasource.dart';
import '../../data/datasources/last_location_local_datasource.dart';
import '../../data/datasources/service_provider_local_datasource.dart';
import '../../data/datasources/tenant_local_datasource.dart';
import '../../data/datasources/admin_category_remote_datasource.dart';
import '../../data/datasources/admin_consumable_remote_datasource.dart';
import '../../data/datasources/admin_tenant_remote_datasource.dart';
import '../../data/datasources/admin_service_provider_remote_datasource.dart';
import '../../data/datasources/issue_remote_datasource.dart';
import '../../data/datasources/assignment_remote_datasource.dart';
import '../../data/repositories/time_extension_repository.dart';
import '../network/connectivity_service.dart';
import '../services/location_service.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/assignment_provider.dart';
import '../../presentation/providers/issue_provider.dart';
import 'sync_operation.dart';
import 'sync_operation_log.dart';

/// Service for managing offline sync queue
class SyncQueueService {
  SyncQueueService(this._ref);

  final Ref _ref;
  static const String _boxName = 'sync_queue';
  Box<SyncOperation>? _box;
  bool _isProcessing = false;
  final _pendingCountController = StreamController<int>.broadcast();

  /// Stream of pending operations count
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Current pending operations count
  int get pendingCount => _box?.length ?? 0;

  /// Check if queue is being processed
  bool get isProcessing => _isProcessing;

  /// Initialize the sync queue
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    _box = await Hive.openBox<SyncOperation>(_boxName);
    _notifyPendingCount();
    debugPrint('SyncQueueService initialized with ${pendingCount} pending operations');
  }

  /// Enqueue a new sync operation
  Future<void> enqueue({
    required SyncOperationType type,
    required SyncEntityType entity,
    required String localId,
    required Map<String, dynamic> data,
  }) async {
    await init();

    // Get current user ID to track who created this operation
    final currentUserId = _ref.read(authStateProvider).user?.id;

    final operation = SyncOperation.create(
      id: const Uuid().v4(),
      type: type,
      entity: entity,
      localId: localId,
      dataJson: jsonEncode(data),
      userId: currentUserId,
    );

    await _box!.put(operation.id, operation);
    _notifyPendingCount();

    debugPrint('Enqueued: $operation (userId: $currentUserId)');

    // Try to process immediately if online
    _tryProcessQueue();
  }

  /// Remove a specific operation from the queue
  Future<void> remove(String operationId) async {
    await init();
    await _box!.delete(operationId);
    _notifyPendingCount();
  }

  /// Remove all operations for a specific local ID
  Future<void> removeByLocalId(String localId) async {
    await init();
    final toRemove = _box!.values.where((op) => op.localId == localId).toList();
    for (final op in toRemove) {
      await _box!.delete(op.id);
    }
    _notifyPendingCount();
  }

  /// Remove all operations for a specific user (called on logout)
  Future<void> clearOperationsForUser(int userId) async {
    await init();
    final toRemove = _box!.values.where((op) => op.userId == userId).toList();
    for (final op in toRemove) {
      await _box!.delete(op.id);
    }
    if (toRemove.isNotEmpty) {
      debugPrint('Cleared ${toRemove.length} sync operations for user $userId on logout');
    }
    _notifyPendingCount();
  }

  /// Get pending operations count for current user
  int getPendingCountForCurrentUser() {
    final currentUserId = _ref.read(authStateProvider).user?.id;
    if (_box == null || !_box!.isOpen) return 0;
    return _box!.values.where((op) =>
      op.shouldRetry && (op.userId == null || op.userId == currentUserId)
    ).length;
  }

  /// Get all pending operations
  List<SyncOperation> getPendingOperations() {
    if (_box == null || !_box!.isOpen) return [];
    return _box!.values.where((op) => op.shouldRetry).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get operations for a specific entity type
  List<SyncOperation> getOperationsForEntity(SyncEntityType entity) {
    return getPendingOperations().where((op) => op.entity == entity).toList();
  }

  /// Process the sync queue
  Future<void> processQueue() async {
    if (_isProcessing) {
      debugPrint('Queue processing already in progress');
      return;
    }

    final isOnline = _ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline) {
      debugPrint('Cannot process queue: offline');
      return;
    }

    await init();
    if (pendingCount == 0) {
      debugPrint('No pending operations to process');
      return;
    }

    _isProcessing = true;
    final currentUserId = _ref.read(authStateProvider).user?.id;
    debugPrint('Processing sync queue: $pendingCount operations (currentUser: $currentUserId)');

    try {
      final operations = getPendingOperations();

      for (final operation in operations) {
        // Check if still online before each operation
        if (!_ref.read(connectivityServiceProvider).isOnline) {
          debugPrint('Went offline during processing, stopping');
          break;
        }

        // Skip operations from other users to prevent 403 errors
        // Operations with null userId are from before this feature was added
        // and will be attempted anyway (may fail, which is acceptable)
        if (operation.userId != null && operation.userId != currentUserId) {
          debugPrint('Skipping operation from different user: ${operation.userId} (current: $currentUserId)');
          continue;
        }

        // Wait for backoff delay if needed
        if (operation.retryCount > 0) {
          final delay = operation.backoffDelay;
          debugPrint('Waiting ${delay.inSeconds}s before retry');
          await Future.delayed(delay);
        }

        await _processOperation(operation);
      }
    } finally {
      _isProcessing = false;
      _notifyPendingCount();
    }
  }

  /// Process a single operation
  Future<void> _processOperation(SyncOperation operation) async {
    debugPrint('Processing: $operation');
    final syncLog = _ref.read(syncOperationLogProvider);

    try {
      switch (operation.entity) {
        case SyncEntityType.issue:
          await _syncIssue(operation);
          break;
        case SyncEntityType.assignment:
          await _syncAssignment(operation);
          break;
        case SyncEntityType.proof:
          await _syncProof(operation);
          break;
        case SyncEntityType.category:
          await _syncCategory(operation);
          break;
        case SyncEntityType.consumable:
          await _syncConsumable(operation);
          break;
        case SyncEntityType.tenant:
          await _syncTenant(operation);
          break;
        case SyncEntityType.serviceProvider:
          await _syncServiceProvider(operation);
          break;
        case SyncEntityType.locationGeocode:
          await _syncLocationGeocode(operation);
          break;
        case SyncEntityType.timeExtension:
          await _syncTimeExtension(operation);
          break;
      }

      // Success - remove from queue and log
      await remove(operation.id);
      await syncLog.logSuccess(
        operationType: operation.operationType,
        entityType: operation.entityType,
        localId: operation.localId,
        retryCount: operation.retryCount,
      );
      debugPrint('Successfully synced: $operation');
    } catch (e) {
      debugPrint('Failed to sync: $operation - $e');
      operation.markAttempted(error: e.toString());
      await operation.save();

      // Log failure
      await syncLog.logFailure(
        operationType: operation.operationType,
        entityType: operation.entityType,
        localId: operation.localId,
        error: e.toString(),
        retryCount: operation.retryCount,
      );

      if (!operation.shouldRetry) {
        debugPrint('Max retries reached, removing: $operation');
        await remove(operation.id);
      }
    }
  }

  /// Sync issue operation
  Future<void> _syncIssue(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final localDs = _ref.read(issueLocalDataSourceProvider);
    final remoteDs = _ref.read(issueRemoteDataSourceProvider);

    switch (operation.type) {
      case SyncOperationType.create:
        // Mark as syncing
        await localDs.markAsSyncing(operation.localId);

        // Convert local media paths to files
        final localMediaPaths = (data['local_media_paths'] as List?)
                ?.map((p) => p.toString())
                .toList() ??
            [];
        final mediaFiles = localMediaPaths
            .map((path) => File(path))
            .where((file) => file.existsSync())
            .toList();

        // Create on server with media files
        final serverIssue = await remoteDs.createIssue(
          title: data['title'] as String,
          description: data['description'] as String?,
          categoryIds: (data['category_ids'] as List).cast<int>(),
          priority: data['priority'] as String? ?? 'medium',
          latitude: data['latitude'] as double?,
          longitude: data['longitude'] as double?,
          address: data['address'] as String?,
          mediaFiles: mediaFiles.isNotEmpty ? mediaFiles : null,
        );

        // Update local with server data
        await localDs.markAsSynced(operation.localId, serverIssue.id);
        await localDs.updateFromServer(operation.localId, serverIssue);

        // Migrate to server_* key to prevent duplicates on refresh
        await localDs.migrateToServerKey(operation.localId, serverIssue.id);

        // CRITICAL: Refresh the provider state to replace old local issue with synced version
        // This prevents duplicates when the user refreshes the list
        try {
          _ref.read(issueListProvider.notifier).refreshAfterSync(
            oldLocalId: operation.localId,
            newServerId: serverIssue.id,
          );
        } catch (e) {
          debugPrint('Warning: Could not refresh provider after sync: $e');
        }

        debugPrint('Issue created on server: ${serverIssue.id} with ${mediaFiles.length} media files');
        break;

      case SyncOperationType.update:
        // Issue updates not commonly used for tenants
        debugPrint('Issue update sync not implemented');
        break;

      case SyncOperationType.delete:
        // Issue cancel
        final serverId = data['server_id'] as int?;
        if (serverId != null) {
          await remoteDs.cancelIssue(serverId, reason: data['reason'] as String?);
          await localDs.deleteIssue(operation.localId);
          debugPrint('Issue cancelled on server: $serverId');
        }
        break;
    }
  }

  /// Sync assignment operation
  Future<void> _syncAssignment(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final localDs = _ref.read(assignmentLocalDataSourceProvider);
    final remoteDs = _ref.read(assignmentRemoteDataSourceProvider);
    final issueId = data['issue_id'] as int;

    switch (operation.type) {
      case SyncOperationType.create:
        // Assignments are created by admin, not SP
        debugPrint('Assignment create sync not implemented');
        break;

      case SyncOperationType.update:
        // Status change (start, hold, resume, finish)
        final action = data['action'] as String;
        await localDs.markAsSyncing(operation.localId);

        switch (action) {
          case 'start':
            final serverAssignment = await remoteDs.startWork(issueId);
            await localDs.updateFromServer(operation.localId, serverAssignment);
            // Migrate key and refresh provider to prevent duplicates
            await localDs.migrateToServerKey(operation.localId, serverAssignment.id);
            _refreshAssignmentProvider(operation.localId, serverAssignment.id);
            break;
          case 'hold':
            final serverAssignment = await remoteDs.holdWork(issueId);
            await localDs.updateFromServer(operation.localId, serverAssignment);
            // Migrate key and refresh provider to prevent duplicates
            await localDs.migrateToServerKey(operation.localId, serverAssignment.id);
            _refreshAssignmentProvider(operation.localId, serverAssignment.id);
            break;
          case 'resume':
            final serverAssignment = await remoteDs.resumeWork(issueId);
            await localDs.updateFromServer(operation.localId, serverAssignment);
            // Migrate key and refresh provider to prevent duplicates
            await localDs.migrateToServerKey(operation.localId, serverAssignment.id);
            _refreshAssignmentProvider(operation.localId, serverAssignment.id);
            break;
          case 'finish':
            final notes = data['notes'] as String?;

            // Convert proof paths to files
            final proofPaths = (data['proof_paths'] as List?)
                    ?.map((p) => p.toString())
                    .toList() ??
                [];
            final proofFiles = proofPaths
                .map((path) => File(path))
                .where((file) => file.existsSync())
                .toList();

            // Convert consumables data to ConsumableUsage objects
            final consumablesData = data['consumables'] as List?;
            final consumables = consumablesData?.map((c) {
              final map = c as Map<String, dynamic>;
              return ConsumableUsage(
                consumableId: map['consumable_id'] as int?,
                customName: map['custom_name'] as String?,
                quantity: map['quantity'] as int? ?? 1,
                notes: map['notes'] as String?,
              );
            }).toList();

            final serverAssignment = await remoteDs.finishWork(
              issueId,
              notes: notes,
              consumables: consumables,
              proofs: proofFiles.isNotEmpty ? proofFiles : null,
            );
            await localDs.updateFromServer(operation.localId, serverAssignment);
            // Migrate key and refresh provider to prevent duplicates
            await localDs.migrateToServerKey(operation.localId, serverAssignment.id);
            _refreshAssignmentProvider(operation.localId, serverAssignment.id);
            debugPrint('Finish synced with ${proofFiles.length} proofs');
            break;
        }
        debugPrint('Assignment $action synced for issue: $issueId');
        break;

      case SyncOperationType.delete:
        debugPrint('Assignment delete not supported');
        break;
    }
  }

  /// Sync proof operation (file upload)
  Future<void> _syncProof(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    // final remoteDs = _ref.read(assignmentRemoteDataSourceProvider);

    // Proof uploads are handled as part of finishWork
    // This is for individual proof uploads if needed
    debugPrint('Proof sync: ${data['file_path']}');
    // TODO: Implement individual proof upload if needed
  }

  /// Sync category operation (admin)
  Future<void> _syncCategory(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final localDs = _ref.read(categoryLocalDataSourceProvider);
    final remoteDs = _ref.read(adminCategoryRemoteDataSourceProvider);

    switch (operation.type) {
      case SyncOperationType.create:
        final serverCategory = await remoteDs.createCategory(
          nameEn: data['name_en'] as String,
          nameAr: data['name_ar'] as String,
          descriptionEn: data['description_en'] as String?,
          descriptionAr: data['description_ar'] as String?,
          icon: data['icon'] as String?,
          color: data['color'] as String?,
          sortOrder: data['sort_order'] as int? ?? 0,
          isActive: data['is_active'] as bool? ?? true,
        );
        // Update local with server data
        final localCat = await localDs.getCategoryById(
            int.tryParse(operation.localId) ?? 0);
        if (localCat != null) {
          localCat.updateFromServer(serverCategory);
          await localCat.save();
        }
        debugPrint('Category created on server: ${serverCategory.id}');
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        await remoteDs.updateCategory(
          serverId,
          nameEn: data['name_en'] as String?,
          nameAr: data['name_ar'] as String?,
          descriptionEn: data['description_en'] as String?,
          descriptionAr: data['description_ar'] as String?,
          icon: data['icon'] as String?,
          color: data['color'] as String?,
          sortOrder: data['sort_order'] as int?,
          isActive: data['is_active'] as bool?,
        );
        debugPrint('Category updated on server: $serverId');
        break;

      case SyncOperationType.delete:
        final serverId = data['server_id'] as int;
        await remoteDs.deleteCategory(serverId);
        await localDs.deleteCategory(serverId);
        debugPrint('Category deleted on server: $serverId');
        break;
    }
  }

  /// Sync consumable operation (admin)
  Future<void> _syncConsumable(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final localDs = _ref.read(consumableLocalDataSourceProvider);
    final remoteDs = _ref.read(adminConsumableRemoteDataSourceProvider);

    switch (operation.type) {
      case SyncOperationType.create:
        final serverConsumable = await remoteDs.createConsumable(
          nameEn: data['name_en'] as String,
          nameAr: data['name_ar'] as String,
          categoryId: data['category_id'] as int,
          isActive: data['is_active'] as bool? ?? true,
        );
        debugPrint('Consumable created on server: ${serverConsumable.id}');
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        await remoteDs.updateConsumable(
          serverId,
          nameEn: data['name_en'] as String?,
          nameAr: data['name_ar'] as String?,
          categoryId: data['category_id'] as int?,
          isActive: data['is_active'] as bool?,
        );
        debugPrint('Consumable updated on server: $serverId');
        break;

      case SyncOperationType.delete:
        final serverId = data['server_id'] as int;
        await remoteDs.deleteConsumable(serverId);
        await localDs.deleteConsumable(serverId);
        debugPrint('Consumable deleted on server: $serverId');
        break;
    }
  }

  /// Sync tenant operation (admin)
  Future<void> _syncTenant(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final localDs = _ref.read(tenantLocalDataSourceProvider);
    final remoteDs = _ref.read(adminTenantRemoteDataSourceProvider);

    switch (operation.type) {
      case SyncOperationType.create:
        // Tenant creation requires password - handled differently
        debugPrint('Tenant create requires online (password needed)');
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        await localDs.markAsSyncing(operation.localId);

        final serverTenant = await remoteDs.updateTenant(
          serverId,
          name: data['name'] as String?,
          email: data['email'] as String?,
          phone: data['phone'] as String?,
          unitNumber: data['unit_number'] as String?,
          buildingName: data['building_name'] as String?,
          isActive: data['is_active'] as bool?,
        );

        await localDs.updateFromServer(operation.localId, serverTenant);
        debugPrint('Tenant updated on server: $serverId');
        break;

      case SyncOperationType.delete:
        // Soft delete - toggle inactive
        final serverId = data['server_id'] as int;
        await remoteDs.toggleActive(serverId);
        await localDs.deleteTenant(operation.localId);
        debugPrint('Tenant deactivated on server: $serverId');
        break;
    }
  }

  /// Sync service provider operation (admin)
  Future<void> _syncServiceProvider(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final localDs = _ref.read(serviceProviderLocalDataSourceProvider);
    final remoteDs = _ref.read(adminServiceProviderRemoteDataSourceProvider);

    switch (operation.type) {
      case SyncOperationType.create:
        // SP creation requires password - handled differently
        debugPrint('Service provider create requires online (password needed)');
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        await localDs.markAsSyncing(operation.localId);

        // Toggle availability is the main update
        if (data['toggle_availability'] == true) {
          await remoteDs.toggleAvailability(serverId);
        }

        debugPrint('Service provider updated on server: $serverId');
        break;

      case SyncOperationType.delete:
        // Soft delete - toggle inactive
        final serverId = data['server_id'] as int;
        await remoteDs.toggleActive(serverId);
        await localDs.deleteServiceProvider(operation.localId);
        debugPrint('Service provider deactivated on server: $serverId');
        break;
    }
  }

  /// Sync location geocode operation
  Future<void> _syncLocationGeocode(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final localDs = _ref.read(lastLocationLocalDataSourceProvider);
    final locationService = _ref.read(locationServiceProvider);

    final latitude = data['latitude'] as double;
    final longitude = data['longitude'] as double;

    // Get address from coordinates
    final address = await locationService.getAddressFromCoordinates(
      latitude,
      longitude,
    );

    if (address != null) {
      await localDs.updateAddress(address);
      debugPrint('Location geocoded: $address');

      // If this was for an issue, update the issue too
      final issueLocalId = data['issue_local_id'] as String?;
      if (issueLocalId != null) {
        final issueLocalDs = _ref.read(issueLocalDataSourceProvider);
        final issue = await issueLocalDs.getIssueByLocalId(issueLocalId);
        if (issue != null) {
          issue.address = address;
          await issue.save();
          debugPrint('Updated issue address: $issueLocalId');
        }
      }
    }
  }

  /// Sync time extension request
  Future<void> _syncTimeExtension(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;
    final repository = _ref.read(timeExtensionRepositoryProvider);

    if (operation.type == SyncOperationType.create) {
      // Create extension request on server
      final serverId = await repository.syncExtensionRequest(
        operation.localId,
        data,
      );

      debugPrint('Synced time extension request: ${operation.localId} → $serverId');

      // Note: Extension requests don't need local ID mapping like issues
      // They're created, approved/rejected, and that's it - no ongoing updates
    } else {
      throw Exception('Unsupported operation type for time extension: ${operation.type}');
    }
  }

  /// Helper to refresh assignment provider after sync
  /// Wrapped in try-catch to prevent sync failure if provider refresh fails
  void _refreshAssignmentProvider(String oldLocalId, int serverId) {
    try {
      _ref.read(assignmentListProvider.notifier).refreshAfterSync(
        oldLocalId: oldLocalId,
        serverId: serverId,
      );
    } catch (e) {
      debugPrint('Warning: Could not refresh assignment provider: $e');
    }
  }

  /// Try to process queue if online
  void _tryProcessQueue() {
    final isOnline = _ref.read(connectivityServiceProvider).isOnline;
    if (isOnline && !_isProcessing) {
      processQueue();
    }
  }

  /// Reset retry counts for all pending operations
  /// Called when device comes back online to avoid exponential backoff delay
  Future<void> resetRetryCountsForOnlineRecovery() async {
    await init();
    final operations = _box!.values.where((op) => op.retryCount > 0).toList();
    for (final op in operations) {
      op.resetRetryCount();
      await op.save();
    }
    if (operations.isNotEmpty) {
      debugPrint('Reset retry counts for ${operations.length} operations after coming online');
    }
  }

  /// Notify listeners of pending count change
  void _notifyPendingCount() {
    _pendingCountController.add(pendingCount);
  }

  /// Dispose resources
  void dispose() {
    _pendingCountController.close();
  }
}

/// Provider for sync queue service
final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  final service = SyncQueueService(ref);
  ref.onDispose(() => service.dispose());

  // Listen for connectivity changes to trigger queue processing
  ref.listen(connectivityStreamProvider, (previous, next) {
    next.whenData((isOnline) async {
      if (isOnline) {
        debugPrint('Back online - resetting retry counts and processing sync queue');
        // Reset retry counts to avoid exponential backoff from offline failures
        await service.resetRetryCountsForOnlineRecovery();
        service.processQueue();
      }
    });
  });

  return service;
});

/// Provider for pending sync count
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(syncQueueServiceProvider);
  return service.pendingCountStream;
});

/// Provider to check if there are pending syncs
final hasPendingSyncsProvider = Provider<bool>((ref) {
  final asyncCount = ref.watch(pendingSyncCountProvider);
  return asyncCount.when(
    data: (count) => count > 0,
    loading: () => false,
    error: (_, __) => false,
  );
});
