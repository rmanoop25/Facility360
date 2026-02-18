import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/tenant_hive_model.dart';
import '../models/tenant_model.dart';

/// Local data source for tenant operations using Hive
/// Supports full offline CRUD with sync queue
class TenantLocalDataSource {
  static const String _boxName = 'tenants';

  /// Get or open the tenants box
  Future<Box<TenantHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<TenantHiveModel>(_boxName);
    }
    return Hive.openBox<TenantHiveModel>(_boxName);
  }

  /// Save a tenant to local storage
  Future<void> saveTenant(TenantHiveModel tenant) async {
    final box = await _getBox();
    await box.put(tenant.localId, tenant);
    debugPrint('TenantLocalDataSource: Saved tenant ${tenant.localId}');
  }

  /// Save multiple tenants to local storage
  Future<void> saveTenants(List<TenantHiveModel> tenants) async {
    final box = await _getBox();
    final map = {for (var tenant in tenants) tenant.localId: tenant};
    await box.putAll(map);
    debugPrint('TenantLocalDataSource: Saved ${tenants.length} tenants');
  }

  /// Get all tenants from local storage (excluding deleted)
  Future<List<TenantHiveModel>> getAllTenants() async {
    final box = await _getBox();
    return box.values.where((t) => !t.isDeleted).toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Get active tenants only (excluding deleted and inactive users)
  Future<List<TenantHiveModel>> getActiveTenants() async {
    final box = await _getBox();
    return box.values
        .where((t) => !t.isDeleted && t.userIsActive)
        .toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Get a tenant by local ID
  Future<TenantHiveModel?> getTenantByLocalId(String localId) async {
    final box = await _getBox();
    return box.get(localId);
  }

  /// Get a tenant by server ID
  Future<TenantHiveModel?> getTenantByServerId(int serverId) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((t) => t.serverId == serverId && !t.isDeleted);
    } catch (_) {
      return null;
    }
  }

  /// Get a tenant by ID (convenience method that checks both local and server IDs)
  Future<TenantHiveModel?> getTenantById(int id) async {
    // First try by server ID
    final byServerId = await getTenantByServerId(id);
    if (byServerId != null) return byServerId;

    // Then try by local ID (for locally created items with negative IDs)
    return getTenantByLocalId(id.toString());
  }

  /// Mark a tenant as deleted (alias for softDeleteTenant, used for offline delete)
  Future<void> markAsDeleted(String localId) async {
    await softDeleteTenant(localId);
  }

  /// Get tenants that need to be synced
  Future<List<TenantHiveModel>> getPendingSyncTenants() async {
    final box = await _getBox();
    return box.values.where((t) => t.needsSync).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Search tenants by name, email, or unit
  Future<List<TenantHiveModel>> searchTenants(String query) async {
    final box = await _getBox();
    final lowerQuery = query.toLowerCase();
    return box.values.where((t) {
      if (t.isDeleted) return false;
      final name = (t.userName ?? '').toLowerCase();
      final email = (t.userEmail ?? '').toLowerCase();
      final unit = (t.unitNumber ?? '').toLowerCase();
      final building = (t.buildingName ?? '').toLowerCase();
      return name.contains(lowerQuery) ||
          email.contains(lowerQuery) ||
          unit.contains(lowerQuery) ||
          building.contains(lowerQuery);
    }).toList()
      ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
  }

  /// Mark a tenant as synced with server ID
  Future<void> markAsSynced(String localId, int serverId) async {
    final box = await _getBox();
    final tenant = box.get(localId);
    if (tenant != null) {
      tenant.markAsSynced(serverId);
      await tenant.save();
      debugPrint('TenantLocalDataSource: Marked $localId as synced (serverId: $serverId)');
    }
  }

  /// Mark a tenant sync as failed
  Future<void> markAsFailed(String localId) async {
    final box = await _getBox();
    final tenant = box.get(localId);
    if (tenant != null) {
      tenant.markAsFailed();
      await tenant.save();
      debugPrint('TenantLocalDataSource: Marked $localId as failed');
    }
  }

  /// Mark a tenant as syncing
  Future<void> markAsSyncing(String localId) async {
    final box = await _getBox();
    final tenant = box.get(localId);
    if (tenant != null) {
      tenant.markAsSyncing();
      await tenant.save();
    }
  }

  /// Update tenant from server response
  Future<void> updateFromServer(String localId, TenantModel serverTenant) async {
    final box = await _getBox();
    final tenant = box.get(localId);
    if (tenant != null) {
      tenant.updateFromServer(serverTenant);
      await tenant.save();
      debugPrint('TenantLocalDataSource: Updated $localId from server');
    }
  }

  /// Replace all cached tenants with server data
  /// IMPORTANT: Preserves local tenants with pending sync (needsSync = true)
  Future<void> replaceAllFromServer(List<TenantModel> serverTenants) async {
    final box = await _getBox();

    // Get ALL tenants that need to be synced (not just those without serverId)
    // This is critical for preserving offline changes to existing tenants
    final pendingSyncTenants = box.values
        .where((t) => t.needsSync)
        .toList();

    debugPrint('TenantLocalDataSource: Found ${pendingSyncTenants.length} pending sync tenants to preserve');

    // Clear the box
    await box.clear();

    // Add server tenants, but check for pending sync conflicts
    for (final serverTenant in serverTenants) {
      final localId = 'server_${serverTenant.id}';

      // Check if we have a pending sync version of this tenant
      final pendingLocal = pendingSyncTenants.firstWhere(
        (t) => t.serverId == serverTenant.id || t.localId == localId,
        orElse: () => TenantHiveModel.fromModel(serverTenant, localId: localId),
      );

      if (pendingLocal.needsSync) {
        // Preserve the local version with pending changes
        debugPrint('TenantLocalDataSource: Preserving pending sync tenant ${pendingLocal.localId}');
        await box.put(pendingLocal.localId, pendingLocal);
      } else {
        // Use server version
        final hiveModel = TenantHiveModel.fromModel(serverTenant, localId: localId);
        await box.put(hiveModel.localId, hiveModel);
      }
    }

    // Re-add any remaining pending sync tenants that weren't in server response
    for (final localTenant in pendingSyncTenants) {
      if (!box.containsKey(localTenant.localId)) {
        await box.put(localTenant.localId, localTenant);
        debugPrint('TenantLocalDataSource: Re-added pending sync tenant ${localTenant.localId}');
      }
    }

    debugPrint('TenantLocalDataSource: Replaced with ${serverTenants.length} server tenants (preserved ${pendingSyncTenants.length} pending)');
  }

  /// Create a new local tenant (admin creating offline)
  Future<TenantHiveModel> createLocalTenant({
    required String localId,
    required String userName,
    required String userEmail,
    String? userPhone,
    String? unitNumber,
    String? buildingName,
    bool userIsActive = true,
  }) async {
    final tenant = TenantHiveModel.createLocal(
      localId: localId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      unitNumber: unitNumber,
      buildingName: buildingName,
      userIsActive: userIsActive,
    );

    await saveTenant(tenant);
    return tenant;
  }

  /// Update a tenant locally (for offline edits)
  Future<void> updateLocally(String localId, {
    String? userName,
    String? userEmail,
    String? userPhone,
    String? unitNumber,
    String? buildingName,
    bool? userIsActive,
  }) async {
    final box = await _getBox();
    final tenant = box.get(localId);
    if (tenant != null) {
      tenant.updateLocally(
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        unitNumber: unitNumber,
        buildingName: buildingName,
        userIsActive: userIsActive,
      );
      await tenant.save();
      debugPrint('TenantLocalDataSource: Updated $localId locally');
    }
  }

  /// Soft delete a tenant (mark for sync)
  Future<void> softDeleteTenant(String localId) async {
    final box = await _getBox();
    final tenant = box.get(localId);
    if (tenant != null) {
      tenant.markAsDeleted();
      await tenant.save();
      debugPrint('TenantLocalDataSource: Soft deleted tenant $localId');
    }
  }

  /// Hard delete a tenant (after successful server delete)
  Future<void> deleteTenant(String localId) async {
    final box = await _getBox();
    await box.delete(localId);
    debugPrint('TenantLocalDataSource: Deleted tenant $localId');
  }

  /// Delete all tenants (for logout/clear data)
  Future<void> deleteAllTenants() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('TenantLocalDataSource: Deleted all tenants');
  }

  /// Get count of tenants (excluding deleted)
  Future<int> getTenantCount() async {
    final box = await _getBox();
    return box.values.where((t) => !t.isDeleted).length;
  }

  /// Get count of pending sync tenants
  Future<int> getPendingSyncCount() async {
    final box = await _getBox();
    return box.values.where((t) => t.needsSync).length;
  }

  /// Check if tenants have been cached
  Future<bool> hasCache() async {
    final box = await _getBox();
    return box.isNotEmpty;
  }

  /// Convert TenantHiveModel list to TenantModel list
  List<TenantModel> toModels(List<TenantHiveModel> hiveModels) {
    return hiveModels.map((h) => h.toModel()).toList();
  }
}

/// Provider for TenantLocalDataSource
final tenantLocalDataSourceProvider = Provider<TenantLocalDataSource>((ref) {
  return TenantLocalDataSource();
});
