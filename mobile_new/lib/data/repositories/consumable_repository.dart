import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../datasources/consumable_remote_datasource.dart';
import '../models/consumable_model.dart';

/// Repository for consumable data with offline caching
///
/// Consumables are master data that rarely change, so we cache them
/// in Hive and refresh from server when online.
class ConsumableRepository {
  final ConsumableRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivityService;

  static const String _boxName = 'consumables_cache';
  static const String _cacheKey = 'consumables';
  static const String _lastFetchKey = 'last_fetch';
  static const Duration _cacheValidity = Duration(hours: 24);

  ConsumableRepository({
    required ConsumableRemoteDataSource remoteDataSource,
    required ConnectivityService connectivityService,
  })  : _remoteDataSource = remoteDataSource,
        _connectivityService = connectivityService;

  /// Get all consumables, optionally filtered by category
  ///
  /// Strategy:
  /// 1. Return cached data immediately if available
  /// 2. Fetch from server if online and cache is stale
  /// 3. Filter by category if specified
  Future<List<ConsumableModel>> getConsumables({
    int? categoryId,
    bool forceRefresh = false,
  }) async {
    final box = await Hive.openBox(_boxName);

    // Check if we have cached data
    final cachedJson = box.get(_cacheKey) as String?;
    final lastFetch = box.get(_lastFetchKey) as DateTime?;
    final isCacheValid = lastFetch != null &&
        DateTime.now().difference(lastFetch) < _cacheValidity;

    List<ConsumableModel> consumables;

    // If cache is valid and no force refresh, use cached data
    if (cachedJson != null && isCacheValid && !forceRefresh) {
      debugPrint('ConsumableRepository: Returning cached consumables');
      consumables = _parseCachedConsumables(cachedJson);
    } else if (_connectivityService.isOnline) {
      // If online, fetch from server
      try {
        debugPrint('ConsumableRepository: Fetching consumables from server');
        consumables = await _remoteDataSource.getConsumables();

        // Cache the result
        await _cacheConsumables(box, consumables);
      } on ApiException catch (e) {
        debugPrint('ConsumableRepository: API error - ${e.message}');
        // If API fails but we have cached data, use it
        if (cachedJson != null) {
          debugPrint('ConsumableRepository: Falling back to cached data');
          consumables = _parseCachedConsumables(cachedJson);
        } else {
          rethrow;
        }
      }
    } else if (cachedJson != null) {
      // Offline - use cached data
      debugPrint('ConsumableRepository: Offline, returning cached consumables');
      consumables = _parseCachedConsumables(cachedJson);
    } else {
      // No data available
      throw const ApiException(
        message: 'No consumables available. Please connect to the internet.',
      );
    }

    // Filter by category if specified
    if (categoryId != null) {
      consumables =
          consumables.where((c) => c.categoryId == categoryId).toList();
    }

    return consumables;
  }

  /// Get consumables for a specific category
  Future<List<ConsumableModel>> getConsumablesByCategory(int categoryId) async {
    return getConsumables(categoryId: categoryId);
  }

  /// Get a single consumable by ID
  Future<ConsumableModel?> getConsumable(int id) async {
    final consumables = await getConsumables();
    try {
      return consumables.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Refresh consumables from server
  Future<List<ConsumableModel>> refreshConsumables() async {
    return getConsumables(forceRefresh: true);
  }

  /// Clear cached consumables
  Future<void> clearCache() async {
    final box = await Hive.openBox(_boxName);
    await box.delete(_cacheKey);
    await box.delete(_lastFetchKey);
  }

  /// Check if consumables are cached
  Future<bool> hasCachedConsumables() async {
    final box = await Hive.openBox(_boxName);
    return box.containsKey(_cacheKey);
  }

  /// Parse cached JSON to list of ConsumableModel
  List<ConsumableModel> _parseCachedConsumables(String json) {
    final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .map((item) => ConsumableModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Cache consumables to Hive
  Future<void> _cacheConsumables(
    Box box,
    List<ConsumableModel> consumables,
  ) async {
    final json = jsonEncode(consumables.map((c) => c.toJson()).toList());
    await box.put(_cacheKey, json);
    await box.put(_lastFetchKey, DateTime.now());
    debugPrint('ConsumableRepository: Cached ${consumables.length} consumables');
  }
}

/// Provider for ConsumableRepository
final consumableRepositoryProvider = Provider<ConsumableRepository>((ref) {
  final remoteDataSource = ref.watch(consumableRemoteDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  return ConsumableRepository(
    remoteDataSource: remoteDataSource,
    connectivityService: connectivityService,
  );
});
