import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/user_hive_model.dart';
import '../models/user_model.dart';

/// Local data source for user operations using Hive
/// Used for caching current user and known users
class UserLocalDataSource {
  static const String _boxName = 'users';
  static const String _currentUserKey = 'current_user';

  /// Get or open the users box
  Future<Box<UserHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<UserHiveModel>(_boxName);
    }
    return Hive.openBox<UserHiveModel>(_boxName);
  }

  /// Save a user to local storage
  Future<void> saveUser(UserHiveModel user) async {
    final box = await _getBox();
    await box.put(user.serverId.toString(), user);
    debugPrint('UserLocalDataSource: Saved user ${user.serverId}');
  }

  /// Save the current logged-in user
  Future<void> saveCurrentUser(UserModel user) async {
    final box = await _getBox();

    // Clear previous current user flag
    for (final existingUser in box.values) {
      if (existingUser.isCurrentUser) {
        existingUser.isCurrentUser = false;
        await existingUser.save();
      }
    }

    // Save new current user
    final hiveModel = UserHiveModel.fromModel(user, isCurrentUser: true);
    await box.put(user.id.toString(), hiveModel);
    debugPrint('UserLocalDataSource: Saved current user ${user.id}');
  }

  /// Get the current logged-in user
  Future<UserHiveModel?> getCurrentUser() async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((user) => user.isCurrentUser);
    } catch (_) {
      return null;
    }
  }

  /// Get the current user as UserModel
  Future<UserModel?> getCurrentUserModel() async {
    final hiveUser = await getCurrentUser();
    return hiveUser?.toModel();
  }

  /// Get a user by server ID
  Future<UserHiveModel?> getUserById(int serverId) async {
    final box = await _getBox();
    return box.get(serverId.toString());
  }

  /// Get all cached users
  Future<List<UserHiveModel>> getAllUsers() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Update the current user from server response
  Future<void> updateCurrentUser(UserModel serverUser) async {
    final box = await _getBox();
    final currentUser = await getCurrentUser();

    if (currentUser != null) {
      currentUser.updateFromServer(serverUser);
      await currentUser.save();
      debugPrint('UserLocalDataSource: Updated current user from server');
    } else {
      // If no current user exists, save as new current user
      await saveCurrentUser(serverUser);
    }
  }

  /// Clear current user (on logout)
  Future<void> clearCurrentUser() async {
    final box = await _getBox();
    final currentUser = await getCurrentUser();

    if (currentUser != null) {
      await box.delete(currentUser.serverId.toString());
      debugPrint('UserLocalDataSource: Cleared current user');
    }
  }

  /// Delete all users (for complete logout/clear data)
  Future<void> deleteAllUsers() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('UserLocalDataSource: Deleted all users');
  }

  /// Check if a current user is cached
  Future<bool> hasCurrentUser() async {
    final currentUser = await getCurrentUser();
    return currentUser != null;
  }

  /// Get user's last sync time
  Future<DateTime?> getLastSyncTime() async {
    final currentUser = await getCurrentUser();
    return currentUser?.syncedAt;
  }
}

/// Provider for UserLocalDataSource
final userLocalDataSourceProvider = Provider<UserLocalDataSource>((ref) {
  return UserLocalDataSource();
});
