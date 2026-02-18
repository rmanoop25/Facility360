import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/consumable_hive_model.dart';
import '../models/consumable_model.dart';

/// Local data source for consumable operations using Hive
/// Master data - uses server-wins conflict resolution
class ConsumableLocalDataSource {
  static const String _boxName = 'consumables';

  /// Get or open the consumables box
  Future<Box<ConsumableHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<ConsumableHiveModel>(_boxName);
    }
    return Hive.openBox<ConsumableHiveModel>(_boxName);
  }

  /// Save a consumable to local storage
  Future<void> saveConsumable(ConsumableHiveModel consumable) async {
    final box = await _getBox();
    await box.put(consumable.serverId.toString(), consumable);
    debugPrint('ConsumableLocalDataSource: Saved consumable ${consumable.serverId}');
  }

  /// Save multiple consumables to local storage
  Future<void> saveConsumables(List<ConsumableHiveModel> consumables) async {
    final box = await _getBox();
    final map = {for (var con in consumables) con.serverId.toString(): con};
    await box.putAll(map);
    debugPrint('ConsumableLocalDataSource: Saved ${consumables.length} consumables');
  }

  /// Get all consumables from local storage
  Future<List<ConsumableHiveModel>> getAllConsumables() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get active consumables only
  Future<List<ConsumableHiveModel>> getActiveConsumables() async {
    final box = await _getBox();
    return box.values.where((con) => con.isActive).toList();
  }

  /// Get consumables by category ID
  Future<List<ConsumableHiveModel>> getByCategory(int categoryId) async {
    final box = await _getBox();
    return box.values.where((con) => con.categoryId == categoryId).toList();
  }

  /// Get active consumables by category ID
  Future<List<ConsumableHiveModel>> getActiveByCategoryId(int categoryId) async {
    final box = await _getBox();
    return box.values
        .where((con) => con.categoryId == categoryId && con.isActive)
        .toList();
  }

  /// Get a consumable by server ID
  Future<ConsumableHiveModel?> getConsumableById(int serverId) async {
    final box = await _getBox();
    return box.get(serverId.toString());
  }

  /// Search consumables by name
  Future<List<ConsumableHiveModel>> searchConsumables(String query, String locale) async {
    final box = await _getBox();
    final lowerQuery = query.toLowerCase();
    return box.values.where((con) {
      final name = con.localizedName(locale).toLowerCase();
      return name.contains(lowerQuery);
    }).toList();
  }

  /// Replace all cached consumables with server data (server-wins)
  Future<void> replaceAllFromServer(List<ConsumableModel> serverConsumables) async {
    final box = await _getBox();
    await box.clear();

    for (final serverConsumable in serverConsumables) {
      final hiveModel = ConsumableHiveModel.fromModel(serverConsumable);
      await box.put(hiveModel.serverId.toString(), hiveModel);
    }

    debugPrint('ConsumableLocalDataSource: Replaced with ${serverConsumables.length} server consumables');
  }

  /// Delete a consumable by server ID
  Future<void> deleteConsumable(int serverId) async {
    final box = await _getBox();
    await box.delete(serverId.toString());
    debugPrint('ConsumableLocalDataSource: Deleted consumable $serverId');
  }

  /// Delete all consumables (for logout/clear data)
  Future<void> deleteAllConsumables() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('ConsumableLocalDataSource: Deleted all consumables');
  }

  /// Get count of consumables
  Future<int> getConsumableCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// Check if consumables have been cached
  Future<bool> hasCache() async {
    final box = await _getBox();
    return box.isNotEmpty;
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final box = await _getBox();
    if (box.isEmpty) return null;

    DateTime? latest;
    for (final con in box.values) {
      if (latest == null || con.syncedAt.isAfter(latest)) {
        latest = con.syncedAt;
      }
    }
    return latest;
  }

  /// Convert ConsumableHiveModel list to ConsumableModel list
  List<ConsumableModel> toModels(List<ConsumableHiveModel> hiveModels) {
    return hiveModels.map((h) => h.toModel()).toList();
  }
}

/// Provider for ConsumableLocalDataSource
final consumableLocalDataSourceProvider = Provider<ConsumableLocalDataSource>((ref) {
  return ConsumableLocalDataSource();
});
