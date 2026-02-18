import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../datasources/category_remote_datasource.dart';
import '../models/category_model.dart';

/// Repository for category data with offline caching
///
/// Categories are master data that rarely change, so we cache them
/// in Hive and refresh from server when online.
class CategoryRepository {
  final CategoryRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivityService;

  static const String _boxName = 'categories_cache';
  static const String _cacheKey = 'categories';
  static const String _lastFetchKey = 'last_fetch';
  static const Duration _cacheValidity = Duration(hours: 24);

  CategoryRepository({
    required CategoryRemoteDataSource remoteDataSource,
    required ConnectivityService connectivityService,
  })  : _remoteDataSource = remoteDataSource,
        _connectivityService = connectivityService;

  /// Get all categories
  ///
  /// Strategy:
  /// 1. Return cached data immediately if available
  /// 2. Fetch from server in background if online and cache is stale
  /// 3. Update cache with fresh data
  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async {
    final box = await Hive.openBox(_boxName);

    // Check if we have cached data
    final cachedJson = box.get(_cacheKey) as String?;
    final lastFetch = box.get(_lastFetchKey) as DateTime?;
    final isCacheValid = lastFetch != null &&
        DateTime.now().difference(lastFetch) < _cacheValidity;

    // If cache is valid and no force refresh, return cached data
    if (cachedJson != null && isCacheValid && !forceRefresh) {
      debugPrint('CategoryRepository: Returning cached categories');
      return _parseCachedCategories(cachedJson);
    }

    // If online, fetch from server
    if (_connectivityService.isOnline) {
      try {
        debugPrint('CategoryRepository: Fetching categories from server');
        final categories = await _remoteDataSource.getCategories();

        // Cache the result
        await _cacheCategories(box, categories);

        return categories;
      } on ApiException catch (e) {
        debugPrint('CategoryRepository: API error - ${e.message}');
        // If API fails but we have cached data, return it
        if (cachedJson != null) {
          debugPrint('CategoryRepository: Falling back to cached data');
          return _parseCachedCategories(cachedJson);
        }
        rethrow;
      }
    }

    // Offline - return cached data if available
    if (cachedJson != null) {
      debugPrint('CategoryRepository: Offline, returning cached categories');
      return _parseCachedCategories(cachedJson);
    }

    // No data available
    throw const ApiException(
      message: 'No categories available. Please connect to the internet.',
    );
  }

  /// Get a single category by ID
  Future<CategoryModel?> getCategory(int id) async {
    final categories = await getCategories();
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Refresh categories from server
  Future<List<CategoryModel>> refreshCategories() async {
    return getCategories(forceRefresh: true);
  }

  /// Clear cached categories
  Future<void> clearCache() async {
    final box = await Hive.openBox(_boxName);
    await box.delete(_cacheKey);
    await box.delete(_lastFetchKey);
  }

  /// Check if categories are cached
  Future<bool> hasCachedCategories() async {
    final box = await Hive.openBox(_boxName);
    return box.containsKey(_cacheKey);
  }

  /// Parse cached JSON to list of CategoryModel
  List<CategoryModel> _parseCachedCategories(String json) {
    final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Cache categories to Hive
  Future<void> _cacheCategories(
    Box box,
    List<CategoryModel> categories,
  ) async {
    final json = jsonEncode(categories.map((c) => c.toJson()).toList());
    await box.put(_cacheKey, json);
    await box.put(_lastFetchKey, DateTime.now());
    debugPrint('CategoryRepository: Cached ${categories.length} categories');
  }
}

/// Provider for CategoryRepository
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final remoteDataSource = ref.watch(categoryRemoteDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  return CategoryRepository(
    remoteDataSource: remoteDataSource,
    connectivityService: connectivityService,
  );
});
