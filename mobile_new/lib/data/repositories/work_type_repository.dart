import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_service.dart';
import '../datasources/work_type_local_datasource.dart';
import '../datasources/work_type_remote_datasource.dart';
import '../models/work_type_model.dart';

/// Repository for work type data with offline-first architecture
///
/// Work types are master data that rarely change, so we cache them
/// locally and refresh from server when online.
class WorkTypeRepository {
  final WorkTypeRemoteDataSource _remoteDataSource;
  final WorkTypeLocalDataSource _localDataSource;
  final ConnectivityService _connectivityService;

  WorkTypeRepository({
    required WorkTypeRemoteDataSource remoteDataSource,
    required WorkTypeLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivityService = connectivityService;

  /// Get all work types with offline-first pattern
  ///
  /// Strategy:
  /// 1. Return local cache immediately if available
  /// 2. Fetch from server if online to get fresh data
  /// 3. Save to local cache (master data - server wins)
  /// 4. Fallback to cache on error
  Future<List<WorkTypeModel>> getWorkTypes({
    int? categoryId,
    bool? isActive,
    bool forceRefresh = false,
  }) async {
    // 1. Return local cache immediately if available (and not forcing refresh)
    final hasCache = await _localDataSource.hasCache();
    if (hasCache && !forceRefresh && !_connectivityService.isOnline) {
      debugPrint('WorkTypeRepository: Offline, returning cached work types');
      return categoryId != null
          ? await _localDataSource.getWorkTypesForCategory(categoryId)
          : await _localDataSource.getAllWorkTypes();
    }

    // 2. Fetch from server if online
    if (_connectivityService.isOnline || forceRefresh) {
      try {
        debugPrint('WorkTypeRepository: Fetching work types from server');
        final serverWorkTypes = await _remoteDataSource.getWorkTypes(
          categoryId: categoryId,
          isActive: isActive,
        );

        // 3. Save to local cache (master data - server wins)
        await _localDataSource.saveWorkTypes(serverWorkTypes);

        return serverWorkTypes;
      } catch (e) {
        debugPrint('WorkTypeRepository: Server fetch failed - $e');

        // 4. Fallback to cache on error
        if (hasCache) {
          debugPrint('WorkTypeRepository: Falling back to cached data');
          return categoryId != null
              ? await _localDataSource.getWorkTypesForCategory(categoryId)
              : await _localDataSource.getAllWorkTypes();
        }
        rethrow;
      }
    }

    // Offline - return cache
    if (hasCache) {
      return categoryId != null
          ? await _localDataSource.getWorkTypesForCategory(categoryId)
          : await _localDataSource.getAllWorkTypes();
    }

    throw Exception('No work types available. Please connect to the internet.');
  }

  /// Convenience method for getting work types for a specific category
  ///
  /// This is the method used by the assign screen
  Future<List<WorkTypeModel>> getWorkTypesForCategory(int categoryId) async {
    return getWorkTypes(categoryId: categoryId, isActive: true);
  }

  /// Get a single work type by ID
  Future<WorkTypeModel?> getWorkType(int id) async {
    // Check cache first
    final cached = await _localDataSource.getWorkTypeById(id);
    if (cached != null && !_connectivityService.isOnline) {
      return cached;
    }

    // Fetch from server if online
    if (_connectivityService.isOnline) {
      try {
        final serverWorkType = await _remoteDataSource.getWorkType(id);
        // Note: We don't cache individual work type here since saveWorkTypes
        // replaces all. The work type will be in cache from the full fetch.
        return serverWorkType;
      } catch (e) {
        debugPrint('WorkTypeRepository: Failed to fetch work type $id - $e');
        return cached; // Fallback to cache
      }
    }

    return cached;
  }

  /// Force refresh work types from server
  Future<List<WorkTypeModel>> refreshWorkTypes() async {
    return getWorkTypes(forceRefresh: true);
  }

  /// Clear cached work types (for logout/data clear)
  Future<void> clearCache() async {
    await _localDataSource.deleteAllWorkTypes();
  }

  /// Check if work types are cached
  Future<bool> hasCachedWorkTypes() async {
    return _localDataSource.hasCache();
  }
}

/// Provider for WorkTypeRepository
final workTypeRepositoryProvider = Provider<WorkTypeRepository>((ref) {
  return WorkTypeRepository(
    remoteDataSource: ref.watch(workTypeRemoteDataSourceProvider),
    localDataSource: ref.watch(workTypeLocalDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});
