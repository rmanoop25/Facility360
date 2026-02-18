import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/service_provider_hive_model.dart';
import '../models/service_provider_model.dart';

/// Local data source for service provider operations using Hive
/// Supports full offline CRUD with sync queue
class ServiceProviderLocalDataSource {
  static const String _boxName = 'service_providers';

  /// Get or open the service providers box
  Future<Box<ServiceProviderHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<ServiceProviderHiveModel>(_boxName);
    }
    return Hive.openBox<ServiceProviderHiveModel>(_boxName);
  }

  /// Save a service provider to local storage
  Future<void> saveServiceProvider(ServiceProviderHiveModel sp) async {
    final box = await _getBox();
    await box.put(sp.localId, sp);
    debugPrint('ServiceProviderLocalDataSource: Saved SP ${sp.localId}');
  }

  /// Save multiple service providers to local storage
  Future<void> saveServiceProviders(List<ServiceProviderHiveModel> providers) async {
    final box = await _getBox();
    final map = {for (var sp in providers) sp.localId: sp};
    await box.putAll(map);
    debugPrint('ServiceProviderLocalDataSource: Saved ${providers.length} service providers');
  }

  /// Get all service providers from local storage (excluding deleted)
  Future<List<ServiceProviderHiveModel>> getAllServiceProviders() async {
    final box = await _getBox();
    return box.values.where((sp) => !sp.isDeleted).toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Get available service providers only
  Future<List<ServiceProviderHiveModel>> getAvailableServiceProviders() async {
    final box = await _getBox();
    return box.values
        .where((sp) => !sp.isDeleted && sp.isAvailable)
        .toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Get service providers by category ID
  Future<List<ServiceProviderHiveModel>> getByCategory(int categoryId) async {
    final box = await _getBox();
    return box.values
        .where((sp) => !sp.isDeleted && sp.categoryIds.contains(categoryId))
        .toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Get available service providers by category ID
  Future<List<ServiceProviderHiveModel>> getAvailableByCategory(int categoryId) async {
    final box = await _getBox();
    return box.values
        .where((sp) =>
            !sp.isDeleted && sp.isAvailable && sp.categoryIds.contains(categoryId))
        .toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Get a service provider by local ID
  Future<ServiceProviderHiveModel?> getByLocalId(String localId) async {
    final box = await _getBox();
    return box.get(localId);
  }

  /// Get a service provider by server ID
  Future<ServiceProviderHiveModel?> getByServerId(int serverId) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((sp) => sp.serverId == serverId && !sp.isDeleted);
    } catch (_) {
      return null;
    }
  }

  /// Get a service provider by ID (convenience method that checks both local and server IDs)
  Future<ServiceProviderHiveModel?> getServiceProviderById(int id) async {
    // First try by server ID
    final byServerId = await getByServerId(id);
    if (byServerId != null) return byServerId;

    // Then try by local ID (for locally created items with negative IDs)
    return getByLocalId(id.toString());
  }

  /// Mark a service provider as deleted (alias for softDeleteServiceProvider, used for offline delete)
  Future<void> markAsDeleted(String localId) async {
    await softDeleteServiceProvider(localId);
  }

  /// Get service providers that need to be synced
  Future<List<ServiceProviderHiveModel>> getPendingSyncProviders() async {
    final box = await _getBox();
    return box.values.where((sp) => sp.needsSync).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Search service providers by name or email
  Future<List<ServiceProviderHiveModel>> searchServiceProviders(String query) async {
    final box = await _getBox();
    final lowerQuery = query.toLowerCase();
    return box.values.where((sp) {
      if (sp.isDeleted) return false;
      final name = (sp.userName ?? '').toLowerCase();
      final email = (sp.userEmail ?? '').toLowerCase();
      return name.contains(lowerQuery) || email.contains(lowerQuery);
    }).toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Mark a service provider as synced with server ID
  Future<void> markAsSynced(String localId, int serverId) async {
    final box = await _getBox();
    final sp = box.get(localId);
    if (sp != null) {
      sp.markAsSynced(serverId);
      await sp.save();
      debugPrint('ServiceProviderLocalDataSource: Marked $localId as synced');
    }
  }

  /// Mark a service provider sync as failed
  Future<void> markAsFailed(String localId) async {
    final box = await _getBox();
    final sp = box.get(localId);
    if (sp != null) {
      sp.markAsFailed();
      await sp.save();
      debugPrint('ServiceProviderLocalDataSource: Marked $localId as failed');
    }
  }

  /// Mark a service provider as syncing
  Future<void> markAsSyncing(String localId) async {
    final box = await _getBox();
    final sp = box.get(localId);
    if (sp != null) {
      sp.markAsSyncing();
      await sp.save();
    }
  }

  /// Update service provider from server response
  Future<void> updateFromServer(String localId, ServiceProviderModel serverSp) async {
    final box = await _getBox();
    final sp = box.get(localId);
    if (sp != null) {
      sp.updateFromServer(serverSp);
      await sp.save();
      debugPrint('ServiceProviderLocalDataSource: Updated $localId from server');
    }
  }

  /// Replace all cached service providers with server data
  /// IMPORTANT: Preserves local providers with pending sync (needsSync = true)
  Future<void> replaceAllFromServer(List<ServiceProviderModel> serverProviders) async {
    final box = await _getBox();

    // Get ALL providers that need to be synced (not just those without serverId)
    // This is critical for preserving offline changes to existing providers
    final pendingSyncProviders = box.values
        .where((sp) => sp.needsSync)
        .toList();

    debugPrint('ServiceProviderLocalDataSource: Found ${pendingSyncProviders.length} pending sync providers to preserve');

    // Clear the box
    await box.clear();

    // Add server providers, but check for pending sync conflicts
    for (final serverSp in serverProviders) {
      final localId = 'server_${serverSp.id}';

      // Check if we have a pending sync version of this provider
      final pendingLocal = pendingSyncProviders.firstWhere(
        (sp) => sp.serverId == serverSp.id || sp.localId == localId,
        orElse: () => ServiceProviderHiveModel.fromModel(serverSp, localId: localId),
      );

      if (pendingLocal.needsSync) {
        // Preserve the local version with pending changes
        debugPrint('ServiceProviderLocalDataSource: Preserving pending sync provider ${pendingLocal.localId}');
        await box.put(pendingLocal.localId, pendingLocal);
      } else {
        // Use server version
        final hiveModel = ServiceProviderHiveModel.fromModel(serverSp, localId: localId);
        await box.put(hiveModel.localId, hiveModel);
      }
    }

    // Re-add any remaining pending sync providers that weren't in server response
    for (final localSp in pendingSyncProviders) {
      if (!box.containsKey(localSp.localId)) {
        await box.put(localSp.localId, localSp);
        debugPrint('ServiceProviderLocalDataSource: Re-added pending sync provider ${localSp.localId}');
      }
    }

    debugPrint('ServiceProviderLocalDataSource: Replaced with ${serverProviders.length} server providers (preserved ${pendingSyncProviders.length} pending)');
  }

  /// Create a new local service provider (admin creating offline)
  Future<ServiceProviderHiveModel> createLocalServiceProvider({
    required String localId,
    required String userName,
    required String userEmail,
    String? userPhone,
    required List<int> categoryIds,
    double? latitude,
    double? longitude,
    bool isAvailable = true,
  }) async {
    final sp = ServiceProviderHiveModel.createLocal(
      localId: localId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      categoryIds: categoryIds,
      latitude: latitude,
      longitude: longitude,
      isAvailable: isAvailable,
    );

    await saveServiceProvider(sp);
    return sp;
  }

  /// Update a service provider locally (for offline edits)
  Future<void> updateLocally(String localId, {
    String? userName,
    String? userEmail,
    String? userPhone,
    List<int>? categoryIds,
    double? latitude,
    double? longitude,
    bool? isAvailable,
    bool? userIsActive,
  }) async {
    final box = await _getBox();
    final sp = box.get(localId);
    if (sp != null) {
      sp.updateLocally(
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        categoryIds: categoryIds,
        latitude: latitude,
        longitude: longitude,
        isAvailable: isAvailable,
        userIsActive: userIsActive,
      );
      await sp.save();
      debugPrint('ServiceProviderLocalDataSource: Updated $localId locally');
    }
  }

  /// Toggle availability locally
  Future<void> toggleAvailability(String localId) async {
    final box = await _getBox();
    final sp = box.get(localId);
    if (sp != null) {
      sp.toggleAvailability();
      await sp.save();
      debugPrint('ServiceProviderLocalDataSource: Toggled availability for $localId');
    }
  }

  /// Soft delete a service provider (mark for sync)
  Future<void> softDeleteServiceProvider(String localId) async {
    final box = await _getBox();
    final sp = box.get(localId);
    if (sp != null) {
      sp.markAsDeleted();
      await sp.save();
      debugPrint('ServiceProviderLocalDataSource: Soft deleted SP $localId');
    }
  }

  /// Hard delete a service provider (after successful server delete)
  Future<void> deleteServiceProvider(String localId) async {
    final box = await _getBox();
    await box.delete(localId);
    debugPrint('ServiceProviderLocalDataSource: Deleted SP $localId');
  }

  /// Delete all service providers (for logout/clear data)
  Future<void> deleteAllServiceProviders() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('ServiceProviderLocalDataSource: Deleted all service providers');
  }

  /// Get count of service providers (excluding deleted)
  Future<int> getServiceProviderCount() async {
    final box = await _getBox();
    return box.values.where((sp) => !sp.isDeleted).length;
  }

  /// Get count of pending sync service providers
  Future<int> getPendingSyncCount() async {
    final box = await _getBox();
    return box.values.where((sp) => sp.needsSync).length;
  }

  /// Check if service providers have been cached
  Future<bool> hasCache() async {
    final box = await _getBox();
    return box.isNotEmpty;
  }

  /// Convert ServiceProviderHiveModel list to ServiceProviderModel list
  List<ServiceProviderModel> toModels(List<ServiceProviderHiveModel> hiveModels) {
    return hiveModels.map((h) => h.toModel()).toList();
  }
}

/// Provider for ServiceProviderLocalDataSource
final serviceProviderLocalDataSourceProvider =
    Provider<ServiceProviderLocalDataSource>((ref) {
  return ServiceProviderLocalDataSource();
});
