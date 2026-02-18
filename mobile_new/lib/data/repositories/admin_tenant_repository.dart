import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_operation.dart';
import '../../core/sync/sync_queue_service.dart';
import '../datasources/admin_tenant_remote_datasource.dart';
import '../datasources/tenant_local_datasource.dart';
import '../local/adapters/tenant_hive_model.dart';
import '../models/tenant_model.dart';
import '../models/paginated_response.dart';

/// Repository for admin tenant CRUD operations
/// Supports offline-first with sync queue for updates
/// Note: Tenant creation requires password, which must be done online
class AdminTenantRepository {
  final AdminTenantRemoteDataSource _remoteDataSource;
  final TenantLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;
  final SyncQueueService _syncQueueService;

  AdminTenantRepository({
    required AdminTenantRemoteDataSource remoteDataSource,
    required TenantLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
    required SyncQueueService syncQueueService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivityService = connectivityService,
        _syncQueueService = syncQueueService;

  /// Check if online
  bool get isOnline => _connectivityService.isOnline;

  /// Check if online, throw if not (for operations that require online)
  void _requireOnline() {
    if (!isOnline) {
      throw const ApiException(
        message: 'This operation requires an internet connection',
      );
    }
  }

  /// Get paginated list of tenants with optional filters
  /// Returns cached data if offline
  Future<PaginatedResponse<TenantModel>> getTenants({
    String? search,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    // Get cached data first
    final cachedTenants = await _localDataSource.getAllTenants();

    // If offline or page > 1, use cached data
    if (!isOnline || page > 1) {
      // Apply filters locally
      var filtered = cachedTenants.where((t) {
        if (isActive != null && t.userIsActive != isActive) return false;
        if (search != null && search.isNotEmpty) {
          final lowerSearch = search.toLowerCase();
          return (t.userName?.toLowerCase().contains(lowerSearch) ?? false) ||
              (t.userEmail?.toLowerCase().contains(lowerSearch) ?? false) ||
              (t.unitNumber?.toLowerCase().contains(lowerSearch) ?? false) ||
              (t.buildingName?.toLowerCase().contains(lowerSearch) ?? false);
        }
        return true;
      }).toList();

      // Apply pagination
      final startIndex = (page - 1) * perPage;
      final endIndex = startIndex + perPage;
      final paginatedList = filtered.length > startIndex
          ? filtered.sublist(startIndex, endIndex.clamp(0, filtered.length))
          : <TenantHiveModel>[];

      return PaginatedResponse(
        data: _localDataSource.toModels(paginatedList),
        currentPage: page,
        lastPage: (filtered.length / perPage).ceil(),
        perPage: perPage,
        total: filtered.length,
      );
    }

    // Online: fetch from server and update cache
    try {
      final response = await _remoteDataSource.getTenants(
        search: search,
        isActive: isActive,
        page: page,
        perPage: perPage,
      );

      // If this is page 1 with no filters, replace all cached data
      if (page == 1 && search == null && isActive == null) {
        await _localDataSource.replaceAllFromServer(response.data);
      }

      return response;
    } catch (e) {
      debugPrint('AdminTenantRepository: getTenants error - $e');
      // Fallback to cached data on error
      if (cachedTenants.isNotEmpty) {
        debugPrint('Falling back to cached tenants');
        return PaginatedResponse(
          data: _localDataSource.toModels(cachedTenants),
          currentPage: 1,
          lastPage: 1,
          perPage: cachedTenants.length,
          total: cachedTenants.length,
        );
      }
      rethrow;
    }
  }

  /// Get a single tenant by ID with full details
  /// Returns cached data if offline or if local has pending sync
  Future<TenantModel> getTenant(int id) async {
    // Try cache first
    final cached = await _localDataSource.getTenantById(id);

    // If local tenant has pending sync, return it without overwriting
    if (cached != null && cached.needsSync) {
      debugPrint('AdminTenantRepository: Returning local tenant $id with pending sync');
      return cached.toModel();
    }

    if (!isOnline) {
      if (cached != null) {
        return cached.toModel();
      }
      throw Exception('Tenant not found in cache and device is offline');
    }

    // Online: fetch from server
    try {
      final tenant = await _remoteDataSource.getTenant(id);
      // Update cache (safe because we checked needsSync above)
      await _localDataSource.saveTenant(TenantHiveModel.fromModel(tenant));
      return tenant;
    } catch (e) {
      debugPrint('AdminTenantRepository: getTenant error - $e');
      // Fallback to cache on error
      if (cached != null) {
        return cached.toModel();
      }
      rethrow;
    }
  }

  /// Create a new tenant with user account
  /// NOTE: This operation REQUIRES online as it needs password
  Future<TenantModel> createTenant({
    required String name,
    required String email,
    required String password,
    required String unitNumber,
    required String buildingName,
    String? phone,
    File? profilePhoto,
  }) async {
    _requireOnline(); // Password operations must be online

    try {
      final tenant = await _remoteDataSource.createTenant(
        name: name,
        email: email,
        password: password,
        unitNumber: unitNumber,
        buildingName: buildingName,
        phone: phone,
        profilePhoto: profilePhoto,
      );
      // Save to cache
      await _localDataSource.saveTenant(TenantHiveModel.fromModel(tenant));
      return tenant;
    } catch (e) {
      debugPrint('AdminTenantRepository: createTenant error - $e');
      rethrow;
    }
  }

  /// Update an existing tenant
  /// Updates locally and queues for sync if offline
  Future<TenantModel> updateTenant(
    int id, {
    String? name,
    String? email,
    String? password,
    String? unitNumber,
    String? buildingName,
    String? phone,
    bool? isActive,
    File? profilePhoto,
  }) async {
    // If password or photo is provided, require online
    if ((password != null && password.isNotEmpty) || profilePhoto != null) {
      _requireOnline();
    }

    if (isOnline) {
      // Online: update on server
      try {
        final tenant = await _remoteDataSource.updateTenant(
          id,
          name: name,
          email: email,
          password: password,
          unitNumber: unitNumber,
          buildingName: buildingName,
          phone: phone,
          isActive: isActive,
          profilePhoto: profilePhoto,
        );
        // Update cache
        await _localDataSource.saveTenant(TenantHiveModel.fromModel(tenant));
        return tenant;
      } catch (e) {
        debugPrint('AdminTenantRepository: updateTenant error - $e');
        rethrow;
      }
    } else {
      // Offline: update locally and queue for sync
      final cached = await _localDataSource.getTenantById(id);
      if (cached == null) {
        throw Exception('Tenant not found in cache');
      }

      // Update local model (can't update password or photo offline)
      cached.updateLocally(
        userName: name,
        userEmail: email,
        userPhone: phone,
        unitNumber: unitNumber,
        buildingName: buildingName,
        userIsActive: isActive,
      );
      await cached.save();

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.tenant,
        localId: id.toString(),
        data: {
          'server_id': id,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (unitNumber != null) 'unit_number': unitNumber,
          if (buildingName != null) 'building_name': buildingName,
          if (phone != null) 'phone': phone,
          if (isActive != null) 'is_active': isActive,
        },
      );

      debugPrint('Tenant updated offline, queued for sync');
      return cached.toModel();
    }
  }

  /// Delete a tenant (soft delete, super_admin only)
  /// Marks as deleted locally and queues for sync if offline
  Future<void> deleteTenant(int id) async {
    if (isOnline) {
      // Online: delete on server
      try {
        await _remoteDataSource.deleteTenant(id);
        // Remove from cache
        await _localDataSource.deleteTenant(id.toString());
      } catch (e) {
        debugPrint('AdminTenantRepository: deleteTenant error - $e');
        rethrow;
      }
    } else {
      // Offline: mark as deleted locally and queue for sync
      await _localDataSource.markAsDeleted(id.toString());

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.delete,
        entity: SyncEntityType.tenant,
        localId: id.toString(),
        data: {'server_id': id},
      );

      debugPrint('Tenant marked for deletion offline, queued for sync');
    }
  }

  /// Toggle tenant active status
  /// Toggles locally and queues for sync if offline
  Future<TenantModel> toggleActive(int id) async {
    if (isOnline) {
      // Online: toggle on server
      try {
        final tenant = await _remoteDataSource.toggleActive(id);
        // Update cache
        await _localDataSource.saveTenant(TenantHiveModel.fromModel(tenant));
        return tenant;
      } catch (e) {
        debugPrint('AdminTenantRepository: toggleActive error - $e');
        rethrow;
      }
    } else {
      // Offline: toggle locally and queue for sync
      final cached = await _localDataSource.getTenantById(id);
      if (cached == null) {
        throw Exception('Tenant not found in cache');
      }

      // Toggle isActive
      cached.updateLocally(userIsActive: !cached.userIsActive);
      await cached.save();

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.tenant,
        localId: id.toString(),
        data: {
          'server_id': id,
          'is_active': cached.userIsActive,
        },
      );

      debugPrint('Tenant toggled offline, queued for sync');
      return cached.toModel();
    }
  }

  /// Refresh tenants from server (force refresh)
  Future<void> refreshFromServer() async {
    if (!isOnline) {
      debugPrint('Cannot refresh: offline');
      return;
    }

    try {
      // Fetch all tenants (paginated)
      int page = 1;
      final allTenants = <TenantModel>[];

      while (true) {
        final response = await _remoteDataSource.getTenants(
          page: page,
          perPage: 50,
        );
        allTenants.addAll(response.data);

        if (page >= response.lastPage) break;
        page++;
      }

      // Replace local cache
      await _localDataSource.replaceAllFromServer(allTenants);
      debugPrint('Refreshed ${allTenants.length} tenants from server');
    } catch (e) {
      debugPrint('AdminTenantRepository: refreshFromServer error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminTenantRepository
final adminTenantRepositoryProvider = Provider<AdminTenantRepository>((ref) {
  final remoteDataSource = ref.watch(adminTenantRemoteDataSourceProvider);
  final localDataSource = ref.watch(tenantLocalDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncQueueService = ref.watch(syncQueueServiceProvider);

  return AdminTenantRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    connectivityService: connectivityService,
    syncQueueService: syncQueueService,
  );
});
