import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/adapters/last_location_hive_model.dart';

/// Local data source for last known location using Hive
/// Used for map picker default location when offline
class LastLocationLocalDataSource {
  static const String _boxName = 'last_location';
  static const String _locationKey = 'last_location';

  /// Get or open the last location box
  Future<Box<LastLocationHiveModel>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<LastLocationHiveModel>(_boxName);
    }
    return Hive.openBox<LastLocationHiveModel>(_boxName);
  }

  /// Save the last known location
  Future<void> saveLastLocation({
    required double latitude,
    required double longitude,
    String? address,
    int? userId,
  }) async {
    final box = await _getBox();
    final location = LastLocationHiveModel.create(
      latitude: latitude,
      longitude: longitude,
      address: address,
      userId: userId,
    );
    await box.put(_locationKey, location);
    debugPrint('LastLocationLocalDataSource: Saved location ($latitude, $longitude)');
  }

  /// Get the last known location
  Future<LastLocationHiveModel?> getLastLocation() async {
    final box = await _getBox();
    return box.get(_locationKey);
  }

  /// Get the last location for a specific user
  Future<LastLocationHiveModel?> getLastLocationForUser(int userId) async {
    final location = await getLastLocation();
    if (location != null && location.userId == userId) {
      return location;
    }
    return null;
  }

  /// Get recent last location (within 24 hours)
  Future<LastLocationHiveModel?> getRecentLastLocation() async {
    final location = await getLastLocation();
    if (location != null && location.isRecent) {
      return location;
    }
    return null;
  }

  /// Update the location
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final box = await _getBox();
    final existing = box.get(_locationKey);

    if (existing != null) {
      existing.updateLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      await existing.save();
      debugPrint('LastLocationLocalDataSource: Updated location');
    } else {
      await saveLastLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
    }
  }

  /// Update only the address (when geocoding completes later)
  Future<void> updateAddress(String address) async {
    final box = await _getBox();
    final existing = box.get(_locationKey);

    if (existing != null) {
      existing.updateAddress(address);
      await existing.save();
      debugPrint('LastLocationLocalDataSource: Updated address');
    }
  }

  /// Check if we have a last known location
  Future<bool> hasLastLocation() async {
    final box = await _getBox();
    return box.containsKey(_locationKey);
  }

  /// Check if we have a recent location (within 24 hours)
  Future<bool> hasRecentLocation() async {
    final location = await getLastLocation();
    return location?.isRecent ?? false;
  }

  /// Get location age in hours
  Future<int?> getLocationAgeHours() async {
    final location = await getLastLocation();
    return location?.ageInHours;
  }

  /// Clear last location
  Future<void> clearLastLocation() async {
    final box = await _getBox();
    await box.delete(_locationKey);
    debugPrint('LastLocationLocalDataSource: Cleared last location');
  }

  /// Delete all location data (for logout/clear data)
  Future<void> deleteAll() async {
    final box = await _getBox();
    await box.clear();
    debugPrint('LastLocationLocalDataSource: Deleted all location data');
  }
}

/// Provider for LastLocationLocalDataSource
final lastLocationLocalDataSourceProvider =
    Provider<LastLocationLocalDataSource>((ref) {
  return LastLocationLocalDataSource();
});
