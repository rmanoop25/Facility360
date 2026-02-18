import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_operation.dart';
import '../../core/sync/sync_queue_service.dart';
import '../datasources/admin_service_provider_remote_datasource.dart';
import '../datasources/service_provider_local_datasource.dart';
import '../local/adapters/service_provider_hive_model.dart';
import '../models/service_provider_model.dart';
import '../models/paginated_response.dart';

/// Repository for admin service provider CRUD operations
/// Supports offline-first with sync queue for updates
/// Note: Service provider creation requires password, which must be done online
class AdminServiceProviderRepository {
  final AdminServiceProviderRemoteDataSource _remoteDataSource;
  final ServiceProviderLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;
  final SyncQueueService _syncQueueService;

  AdminServiceProviderRepository({
    required AdminServiceProviderRemoteDataSource remoteDataSource,
    required ServiceProviderLocalDataSource localDataSource,
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

  /// Get paginated list of service providers with optional filters
  /// Returns cached data if offline
  Future<PaginatedResponse<ServiceProviderModel>> getServiceProviders({
    String? search,
    int? categoryId,
    bool? isAvailable,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    // Get cached data first
    final cachedProviders = await _localDataSource.getAllServiceProviders();

    // If offline, use cached data with local filtering and pagination
    if (!isOnline) {
      // Apply filters locally
      var filtered = cachedProviders.where((sp) {
        if (isActive != null && sp.userIsActive != isActive) return false;
        if (isAvailable != null && sp.isAvailable != isAvailable) return false;
        if (categoryId != null && !sp.categoryIds.contains(categoryId)) return false;
        if (search != null && search.isNotEmpty) {
          final lowerSearch = search.toLowerCase();
          return (sp.userName?.toLowerCase().contains(lowerSearch) ?? false) ||
              (sp.userEmail?.toLowerCase().contains(lowerSearch) ?? false);
        }
        return true;
      }).toList();

      // Apply pagination
      final startIndex = (page - 1) * perPage;
      final endIndex = startIndex + perPage;
      final paginatedList = filtered.length > startIndex
          ? filtered.sublist(startIndex, endIndex.clamp(0, filtered.length))
          : <ServiceProviderHiveModel>[];

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
      final response = await _remoteDataSource.getServiceProviders(
        search: search,
        categoryId: categoryId,
        isAvailable: isAvailable,
        isActive: isActive,
        page: page,
        perPage: perPage,
      );

      // If this is page 1 with no filters, replace all cached data
      if (page == 1 && search == null && categoryId == null && isAvailable == null && isActive == null) {
        await _localDataSource.replaceAllFromServer(response.data);
      }

      return response;
    } catch (e) {
      debugPrint('AdminServiceProviderRepository: getServiceProviders error - $e');
      // Fallback to cached data on error
      if (cachedProviders.isNotEmpty) {
        debugPrint('Falling back to cached service providers');
        return PaginatedResponse(
          data: _localDataSource.toModels(cachedProviders),
          currentPage: 1,
          lastPage: 1,
          perPage: cachedProviders.length,
          total: cachedProviders.length,
        );
      }
      rethrow;
    }
  }

  /// Get a single service provider by ID with full details
  /// Returns cached data if offline or if local has pending sync
  Future<ServiceProviderModel> getServiceProvider(int id) async {
    // Try cache first
    final cached = await _localDataSource.getServiceProviderById(id);

    // If local service provider has pending sync, return it without overwriting
    if (cached != null && cached.needsSync) {
      debugPrint('AdminServiceProviderRepository: Returning local SP $id with pending sync');
      return cached.toModel();
    }

    if (!isOnline) {
      if (cached != null) {
        return cached.toModel();
      }
      throw Exception('Service provider not found in cache and device is offline');
    }

    // Online: fetch from server
    try {
      final provider = await _remoteDataSource.getServiceProvider(id);
      // Update cache (safe because we checked needsSync above)
      await _localDataSource.saveServiceProvider(ServiceProviderHiveModel.fromModel(provider));
      return provider;
    } catch (e) {
      debugPrint('AdminServiceProviderRepository: getServiceProvider error - $e');
      // Fallback to cache on error
      if (cached != null) {
        return cached.toModel();
      }
      rethrow;
    }
  }

  /// Create a new service provider with user account
  /// NOTE: This operation REQUIRES online as it needs password
  Future<ServiceProviderModel> createServiceProvider({
    required String name,
    required String email,
    required String password,
    required List<int> categoryIds,
    String? phone,
    bool isAvailable = true,
    File? profilePhoto,
  }) async {
    _requireOnline(); // Password operations must be online

    try {
      final provider = await _remoteDataSource.createServiceProvider(
        name: name,
        email: email,
        password: password,
        categoryIds: categoryIds,
        phone: phone,
        isAvailable: isAvailable,
        profilePhoto: profilePhoto,
      );
      // Save to cache
      await _localDataSource.saveServiceProvider(ServiceProviderHiveModel.fromModel(provider));
      return provider;
    } catch (e) {
      debugPrint('AdminServiceProviderRepository: createServiceProvider error - $e');
      rethrow;
    }
  }

  /// Update an existing service provider
  /// Updates locally and queues for sync if offline
  /// NOTE: Profile photo upload requires online
  Future<ServiceProviderModel> updateServiceProvider(
    int id, {
    String? name,
    String? email,
    String? password,
    List<int>? categoryIds,
    String? phone,
    bool? isAvailable,
    bool? isActive,
    File? profilePhoto,
  }) async {
    // If password or profile photo is provided, require online
    if ((password != null && password.isNotEmpty) || profilePhoto != null) {
      _requireOnline();
    }

    if (isOnline) {
      // Online: update on server
      try {
        final provider = await _remoteDataSource.updateServiceProvider(
          id,
          name: name,
          email: email,
          password: password,
          categoryIds: categoryIds,
          phone: phone,
          isAvailable: isAvailable,
          isActive: isActive,
          profilePhoto: profilePhoto,
        );
        // Update cache
        await _localDataSource.saveServiceProvider(ServiceProviderHiveModel.fromModel(provider));
        return provider;
      } catch (e) {
        debugPrint('AdminServiceProviderRepository: updateServiceProvider error - $e');
        rethrow;
      }
    } else {
      // Offline: update locally and queue for sync
      final cached = await _localDataSource.getServiceProviderById(id);
      if (cached == null) {
        throw Exception('Service provider not found in cache');
      }

      // Update local model (can't update password or profile photo offline)
      cached.updateLocally(
        userName: name,
        userEmail: email,
        userPhone: phone,
        categoryIds: categoryIds,
        isAvailable: isAvailable,
        userIsActive: isActive,
      );
      await cached.save();

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.serviceProvider,
        localId: id.toString(),
        data: {
          'server_id': id,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (categoryIds != null) 'category_ids': categoryIds,
          if (phone != null) 'phone': phone,
          if (isAvailable != null) 'is_available': isAvailable,
          if (isActive != null) 'is_active': isActive,
        },
      );

      debugPrint('Service provider updated offline, queued for sync');
      return cached.toModel();
    }
  }

  /// Delete a service provider
  /// Marks as deleted locally and queues for sync if offline
  Future<void> deleteServiceProvider(int id) async {
    if (isOnline) {
      // Online: delete on server
      try {
        await _remoteDataSource.deleteServiceProvider(id);
        // Remove from cache
        await _localDataSource.deleteServiceProvider(id.toString());
      } catch (e) {
        debugPrint('AdminServiceProviderRepository: deleteServiceProvider error - $e');
        rethrow;
      }
    } else {
      // Offline: mark as deleted locally and queue for sync
      await _localDataSource.markAsDeleted(id.toString());

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.delete,
        entity: SyncEntityType.serviceProvider,
        localId: id.toString(),
        data: {'server_id': id},
      );

      debugPrint('Service provider marked for deletion offline, queued for sync');
    }
  }

  /// Toggle service provider active status
  /// Toggles locally and queues for sync if offline
  Future<ServiceProviderModel> toggleActive(int id) async {
    if (isOnline) {
      // Online: toggle on server
      try {
        final provider = await _remoteDataSource.toggleActive(id);
        // Update cache
        await _localDataSource.saveServiceProvider(ServiceProviderHiveModel.fromModel(provider));
        return provider;
      } catch (e) {
        debugPrint('AdminServiceProviderRepository: toggleActive error - $e');
        rethrow;
      }
    } else {
      // Offline: toggle locally and queue for sync
      final cached = await _localDataSource.getServiceProviderById(id);
      if (cached == null) {
        throw Exception('Service provider not found in cache');
      }

      // Toggle isActive
      cached.updateLocally(userIsActive: !cached.userIsActive);
      await cached.save();

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.serviceProvider,
        localId: id.toString(),
        data: {
          'server_id': id,
          'is_active': cached.userIsActive,
        },
      );

      debugPrint('Service provider toggled offline, queued for sync');
      return cached.toModel();
    }
  }

  /// Toggle service provider availability
  /// Toggles locally and queues for sync if offline
  Future<ServiceProviderModel> toggleAvailability(int id) async {
    if (isOnline) {
      // Online: toggle on server
      try {
        final provider = await _remoteDataSource.toggleAvailability(id);
        // Update cache
        await _localDataSource.saveServiceProvider(ServiceProviderHiveModel.fromModel(provider));
        return provider;
      } catch (e) {
        debugPrint('AdminServiceProviderRepository: toggleAvailability error - $e');
        rethrow;
      }
    } else {
      // Offline: toggle locally and queue for sync
      final cached = await _localDataSource.getServiceProviderById(id);
      if (cached == null) {
        throw Exception('Service provider not found in cache');
      }

      // Toggle availability
      cached.updateLocally(isAvailable: !cached.isAvailable);
      await cached.save();

      // Queue for sync
      await _syncQueueService.enqueue(
        type: SyncOperationType.update,
        entity: SyncEntityType.serviceProvider,
        localId: id.toString(),
        data: {
          'server_id': id,
          'toggle_availability': true,
        },
      );

      debugPrint('Service provider availability toggled offline, queued for sync');
      return cached.toModel();
    }
  }

  /// Refresh service providers from server (force refresh)
  Future<void> refreshFromServer() async {
    if (!isOnline) {
      debugPrint('Cannot refresh: offline');
      return;
    }

    try {
      // Fetch all service providers (paginated)
      int page = 1;
      final allProviders = <ServiceProviderModel>[];

      while (true) {
        final response = await _remoteDataSource.getServiceProviders(
          page: page,
          perPage: 50,
        );
        allProviders.addAll(response.data);

        if (page >= response.lastPage) break;
        page++;
      }

      // Replace local cache
      await _localDataSource.replaceAllFromServer(allProviders);
      debugPrint('Refreshed ${allProviders.length} service providers from server');
    } catch (e) {
      debugPrint('AdminServiceProviderRepository: refreshFromServer error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminServiceProviderRepository
final adminServiceProviderRepositoryProvider = Provider<AdminServiceProviderRepository>((ref) {
  final remoteDataSource = ref.watch(adminServiceProviderRemoteDataSourceProvider);
  final localDataSource = ref.watch(serviceProviderLocalDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final syncQueueService = ref.watch(syncQueueServiceProvider);

  return AdminServiceProviderRepository(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    connectivityService: connectivityService,
    syncQueueService: syncQueueService,
  );
});
