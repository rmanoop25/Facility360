import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_operation.dart';
import '../../core/sync/sync_queue_service.dart';
import '../datasources/admin_consumable_remote_datasource.dart';
import '../datasources/consumable_local_datasource.dart';
import '../local/adapters/consumable_hive_model.dart';
import '../models/consumable_model.dart';
import '../models/paginated_response.dart';

/// Repository for admin consumable CRUD operations
/// Supports full offline-first functionality with sync queue
class AdminConsumableRepository {
  final AdminConsumableRemoteDataSource _remoteDataSource;
  final ConsumableLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;
  final SyncQueueService _syncQueueService;

  AdminConsumableRepository({
    required AdminConsumableRemoteDataSource remoteDataSource,
    required ConsumableLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
    required SyncQueueService syncQueueService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivityService = connectivityService,
        _syncQueueService = syncQueueService;

  /// Check if online
  bool get isOnline => _connectivityService.isOnline;

  /// Get paginated list of consumables with optional filters
  /// Returns cached data if offline, refreshes in background if online
  Future<PaginatedResponse<ConsumableModel>> getConsumables({
    String? search,
    int? categoryId,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    // Get cached data first for offline fallback
    final cachedConsumables = await _localDataSource.getAllConsumables();

    // If offline, use cached data with local pagination
    if (!isOnline) {
      // Apply filters locally
      var filtered = cachedConsumables.where((c) {
        if (isActive != null && c.isActive != isActive) return false;
        if (categoryId != null && c.categoryId != categoryId) return false;
        if (search != null && search.isNotEmpty) {
          final lowerSearch = search.toLowerCase();
          return c.nameEn.toLowerCase().contains(lowerSearch) ||
              c.nameAr.toLowerCase().contains(lowerSearch);
        }
        return true;
      }).toList();

      // Apply pagination
      final startIndex = (page - 1) * perPage;
      final endIndex = startIndex + perPage;
      final paginatedList = filtered.length > startIndex
          ? filtered.sublist(startIndex, endIndex.clamp(0, filtered.length))
          : <ConsumableHiveModel>[];

      return PaginatedResponse(
        data: _localDataSource.toModels(paginatedList),
        currentPage: page,
        lastPage: (filtered.length / perPage).ceil(),
        perPage: perPage,
        total: filtered.length,
      );
    }

    // Online: fetch from server for all pages
    try {
      final response = await _remoteDataSource.getConsumables(
        search: search,
        categoryId: categoryId,
        isActive: isActive,
        page: page,
        perPage: perPage,
      );

      // If this is page 1 with no filters, replace all cached data
      if (page == 1 && search == null && categoryId == null && isActive == null) {
        await _localDataSource.replaceAllFromServer(response.data);
      }

      return response;
    } catch (e) {
      debugPrint('AdminConsumableRepository: getConsumables error - $e');
      // Fallback to cached data on error
      if (cachedConsumables.isNotEmpty) {
        debugPrint('Falling back to cached consumables');
        return PaginatedResponse(
          data: _localDataSource.toModels(cachedConsumables),
          currentPage: 1,
          lastPage: 1,
          perPage: cachedConsumables.length,
          total: cachedConsumables.length,
        );
      }
      rethrow;
    }
  }

  /// Get a single consumable by ID
  /// Returns cached data if offline
  Future<ConsumableModel> getConsumable(int id) async {
    // Try cache first
    final cached = await _localDataSource.getConsumableById(id);

    if (!isOnline) {
      if (cached != null) {
        return cached.toModel();
      }
      throw Exception('Consumable not found in cache and device is offline');
    }

    // Online: fetch from server
    try {
      final consumable = await _remoteDataSource.getConsumable(id);
      // Update cache
      await _localDataSource.saveConsumable(ConsumableHiveModel.fromModel(consumable));
      return consumable;
    } catch (e) {
      debugPrint('AdminConsumableRepository: getConsumable error - $e');
      // Fallback to cache on error
      if (cached != null) {
        return cached.toModel();
      }
      rethrow;
    }
  }

  /// Create a new consumable
  /// Saves locally and queues for sync if offline
  Future<ConsumableModel> createConsumable({
    required String nameEn,
    required String nameAr,
    required int categoryId,
    bool isActive = true,
  }) async {
    if (isOnline) {
      // Online: create on server
      try {
        final consumable = await _remoteDataSource.createConsumable(
          nameEn: nameEn,
          nameAr: nameAr,
          categoryId: categoryId,
          isActive: isActive,
        );
        // Save to cache
        await _localDataSource.saveConsumable(ConsumableHiveModel.fromModel(consumable));
        return consumable;
      } catch (e) {
        debugPrint('AdminConsumableRepository: createConsumable error - $e');
        rethrow;
      }
    } else {
      // Offline: save locally and queue for sync
      final localId = const Uuid().v4();
      final localConsumable = ConsumableModel(
        id: -localId.hashCode.abs(), // Negative ID for local items
        nameEn: nameEn,
        nameAr: nameAr,
        categoryId: categoryId,
        isActive: isActive,
      );

      // Save to local storage
      await _localDataSource.saveConsumable(ConsumableHiveModel.fromModel(localConsumable));

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.create,
        entity: SyncEntityType.consumable,
        localId: localId,
        data: {
          'name_en': nameEn,
          'name_ar': nameAr,
          'category_id': categoryId,
          'is_active': isActive,
        },
      );

      debugPrint('Consumable created offline, queued for sync');
      return localConsumable;
    }
  }

  /// Update an existing consumable
  /// Updates locally and queues for sync if offline
  Future<ConsumableModel> updateConsumable(
    int id, {
    String? nameEn,
    String? nameAr,
    int? categoryId,
    bool? isActive,
  }) async {
    if (isOnline) {
      // Online: update on server
      try {
        final consumable = await _remoteDataSource.updateConsumable(
          id,
          nameEn: nameEn,
          nameAr: nameAr,
          categoryId: categoryId,
          isActive: isActive,
        );
        // Update cache
        await _localDataSource.saveConsumable(ConsumableHiveModel.fromModel(consumable));
        return consumable;
      } catch (e) {
        debugPrint('AdminConsumableRepository: updateConsumable error - $e');
        rethrow;
      }
    } else {
      // Offline: update locally and queue for sync
      final cached = await _localDataSource.getConsumableById(id);
      if (cached == null) {
        throw Exception('Consumable not found in cache');
      }

      // Update local model
      final updatedConsumable = cached.toModel().copyWith(
        nameEn: nameEn,
        nameAr: nameAr,
        categoryId: categoryId,
        isActive: isActive,
      );

      // Save updated model
      await _localDataSource.saveConsumable(ConsumableHiveModel.fromModel(updatedConsumable));

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.consumable,
        localId: id.toString(),
        data: {
          'server_id': id,
          if (nameEn != null) 'name_en': nameEn,
          if (nameAr != null) 'name_ar': nameAr,
          if (categoryId != null) 'category_id': categoryId,
          if (isActive != null) 'is_active': isActive,
        },
      );

      debugPrint('Consumable updated offline, queued for sync');
      return updatedConsumable;
    }
  }

  /// Delete a consumable
  /// Deletes locally and queues for sync if offline
  Future<void> deleteConsumable(int id) async {
    if (isOnline) {
      // Online: delete on server
      try {
        await _remoteDataSource.deleteConsumable(id);
        // Remove from cache
        await _localDataSource.deleteConsumable(id);
      } catch (e) {
        debugPrint('AdminConsumableRepository: deleteConsumable error - $e');
        rethrow;
      }
    } else {
      // Offline: remove locally and queue for sync
      await _localDataSource.deleteConsumable(id);

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.delete,
        entity: SyncEntityType.consumable,
        localId: id.toString(),
        data: {'server_id': id},
      );

      debugPrint('Consumable deleted offline, queued for sync');
    }
  }

  /// Toggle consumable active status
  /// Toggles locally and queues for sync if offline
  Future<ConsumableModel> toggleActive(int id) async {
    if (isOnline) {
      // Online: toggle on server
      try {
        final consumable = await _remoteDataSource.toggleActive(id);
        // Update cache
        await _localDataSource.saveConsumable(ConsumableHiveModel.fromModel(consumable));
        return consumable;
      } catch (e) {
        debugPrint('AdminConsumableRepository: toggleActive error - $e');
        rethrow;
      }
    } else {
      // Offline: toggle locally and queue for sync
      final cached = await _localDataSource.getConsumableById(id);
      if (cached == null) {
        throw Exception('Consumable not found in cache');
      }

      // Toggle isActive
      final updatedConsumable = cached.toModel().copyWith(
        isActive: !cached.isActive,
      );

      // Save updated model
      await _localDataSource.saveConsumable(ConsumableHiveModel.fromModel(updatedConsumable));

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.consumable,
        localId: id.toString(),
        data: {
          'server_id': id,
          'is_active': updatedConsumable.isActive,
        },
      );

      debugPrint('Consumable toggled offline, queued for sync');
      return updatedConsumable;
    }
  }

  /// Refresh consumables from server (force refresh)
  Future<void> refreshFromServer() async {
    if (!isOnline) {
      debugPrint('Cannot refresh: offline');
      return;
    }

    try {
      // Fetch all consumables (paginated)
      int page = 1;
      final allConsumables = <ConsumableModel>[];

      while (true) {
        final response = await _remoteDataSource.getConsumables(
          page: page,
          perPage: 50,
        );
        allConsumables.addAll(response.data);

        if (page >= response.lastPage) break;
        page++;
      }

      // Replace local cache
      await _localDataSource.replaceAllFromServer(allConsumables);
      debugPrint('Refreshed ${allConsumables.length} consumables from server');
    } catch (e) {
      debugPrint('AdminConsumableRepository: refreshFromServer error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminConsumableRepository
final adminConsumableRepositoryProvider = Provider<AdminConsumableRepository>((ref) {
  final remoteDataSource = ref.watch(adminConsumableRemoteDataSourceProvider);
  final localDataSource = ref.watch(consumableLocalDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncQueueService = ref.watch(syncQueueServiceProvider);

  return AdminConsumableRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    connectivityService: connectivityService,
    syncQueueService: syncQueueService,
  );
});
