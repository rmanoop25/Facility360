import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/work_type_hive_model.dart';
import '../models/work_type_model.dart';

/// Local data source for work type operations using Hive
/// Master data - uses server-wins conflict resolution
class WorkTypeLocalDataSource {
  static const String _boxName = 'work_types';

  /// Get or open the work types box
  Future<Box<WorkTypeHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<WorkTypeHiveModel>(_boxName);
    }
    return Hive.openBox<WorkTypeHiveModel>(_boxName);
  }

  /// Save a work type to local storage
  Future<void> saveWorkType(WorkTypeHiveModel workType) async {
    final box = await _getBox();
    await box.put('work_type_${workType.serverId}', workType);
    debugPrint('WorkTypeLocalDataSource: Saved work type ${workType.serverId}');
  }

  /// Save multiple work types to local storage (replaces all - server wins)
  Future<void> saveWorkTypes(List<WorkTypeModel> workTypes) async {
    final box = await _getBox();

    // Clear existing data (server-authoritative)
    await box.clear();

    // Save new data
    final hiveModels = workTypes.map((wt) => WorkTypeHiveModel.fromModel(wt)).toList();
    for (final model in hiveModels) {
      await box.put('work_type_${model.serverId}', model);
    }

    debugPrint('WorkTypeLocalDataSource: Saved ${workTypes.length} work types');
  }

  /// Get all work types from local storage
  Future<List<WorkTypeModel>> getAllWorkTypes() async {
    final box = await _getBox();
    return box.values.map((hive) => hive.toModel()).toList();
  }

  /// Get active work types only
  Future<List<WorkTypeModel>> getActiveWorkTypes() async {
    final box = await _getBox();
    return box.values
        .where((wt) => wt.isActive)
        .map((hive) => hive.toModel())
        .toList();
  }

  /// Get work types for a specific category
  Future<List<WorkTypeModel>> getWorkTypesForCategory(int categoryId) async {
    final box = await _getBox();
    return box.values
        .where((wt) => wt.categoryIds.contains(categoryId) && wt.isActive)
        .map((hive) => hive.toModel())
        .toList();
  }

  /// Get a single work type by ID
  Future<WorkTypeModel?> getWorkTypeById(int id) async {
    final box = await _getBox();
    final hiveModel = box.get('work_type_$id');
    return hiveModel?.toModel();
  }

  /// Search work types by name
  Future<List<WorkTypeModel>> searchWorkTypes(String query, String locale) async {
    final box = await _getBox();
    final lowerQuery = query.toLowerCase();
    return box.values.where((wt) {
      final name = wt.localizedName(locale).toLowerCase();
      return name.contains(lowerQuery);
    }).map((hive) => hive.toModel()).toList();
  }

  /// Delete a work type by ID
  Future<void> deleteWorkType(int id) async {
    final box = await _getBox();
    await box.delete('work_type_$id');
    debugPrint('WorkTypeLocalDataSource: Deleted work type $id');
  }

  /// Delete all work types (for logout/clear data)
  Future<void> deleteAllWorkTypes() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('WorkTypeLocalDataSource: Deleted all work types');
  }

  /// Get count of work types
  Future<int> getWorkTypeCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// Check if work types have been cached
  Future<bool> hasCache() async {
    final box = await _getBox();
    return box.isNotEmpty;
  }

  /// Get last sync time (most recent syncedAt from any work type)
  Future<DateTime?> getLastSyncTime() async {
    final box = await _getBox();
    if (box.isEmpty) return null;

    DateTime? latest;
    for (final wt in box.values) {
      if (latest == null || wt.syncedAt.isAfter(latest)) {
        latest = wt.syncedAt;
      }
    }
    return latest;
  }

  /// Convert WorkTypeHiveModel list to WorkTypeModel list
  List<WorkTypeModel> toModels(List<WorkTypeHiveModel> hiveModels) {
    return hiveModels.map((h) => h.toModel()).toList();
  }
}

/// Provider for WorkTypeLocalDataSource
final workTypeLocalDataSourceProvider = Provider<WorkTypeLocalDataSource>((ref) {
  return WorkTypeLocalDataSource();
});
