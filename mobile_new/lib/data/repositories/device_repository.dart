import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../datasources/device_remote_datasource.dart';

/// Repository for FCM device token operations with offline-first support
///
/// Strategy:
/// 1. Store token locally first (SecureStorage)
/// 2. Sync with backend if online
/// 3. Queue for later sync if offline
/// 4. Auto-retry on connectivity restore
class DeviceRepository {
  final DeviceRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivityService;
  final SecureStorageService _storageService;

  DeviceRepository({
    required DeviceRemoteDataSource remoteDataSource,
    required ConnectivityService connectivityService,
    required SecureStorageService storageService,
  })  : _remoteDataSource = remoteDataSource,
        _connectivityService = connectivityService,
        _storageService = storageService;

  static const String _tokenKey = 'fcm_token';
  static const String _tokenSyncedKey = 'fcm_token_synced';

  /// Register FCM token (offline-first)
  ///
  /// Stores token locally first, then syncs with backend when online.
  /// If offline, marks token as pending sync.
  Future<bool> registerToken(String token, {String? deviceType}) async {
    try {
      // Store locally first
      await _storageService.write(_tokenKey,token);
      debugPrint('DeviceRepository: Stored token locally');

      // Try to sync with backend if online
      if (_connectivityService.isOnline) {
        try {
          await _remoteDataSource.registerToken(token, deviceType: deviceType);
          await _storageService.write(_tokenSyncedKey,'true');
          debugPrint('DeviceRepository: Token synced with backend');
          return true;
        } on ApiException catch (e) {
          debugPrint('DeviceRepository: Failed to sync token - ${e.message}');
          // Mark as pending sync
          await _storageService.write(_tokenSyncedKey,'false');
          // Don't throw - token is stored locally
          return false;
        }
      }

      // Offline - mark as pending sync
      await _storageService.write(_tokenSyncedKey,'false');
      debugPrint('DeviceRepository: Offline - token pending sync');
      return false;
    } catch (e) {
      debugPrint('DeviceRepository: Failed to register token - $e');
      return false;
    }
  }

  /// Remove token from backend (requires online)
  ///
  /// Also clears local storage.
  Future<bool> removeToken(String token) async {
    try {
      if (_connectivityService.isOnline) {
        await _remoteDataSource.removeToken(token);
        debugPrint('DeviceRepository: Token removed from backend');
      }

      // Clear local storage
      await clearToken();
      return true;
    } catch (e) {
      debugPrint('DeviceRepository: Failed to remove token - $e');
      return false;
    }
  }

  /// Get stored FCM token from local storage
  Future<String?> getStoredToken() async {
    return await _storageService.read(_tokenKey);
  }

  /// Check if token is synced with backend
  Future<bool> isTokenSynced() async {
    final synced = await _storageService.read(_tokenSyncedKey);
    return synced == 'true';
  }

  /// Clear stored token (on logout)
  Future<void> clearToken() async {
    await _storageService.delete(_tokenKey);
    await _storageService.delete(_tokenSyncedKey);
    debugPrint('DeviceRepository: Token cleared from local storage');
  }

  /// Retry failed token registration
  ///
  /// Call this when connectivity is restored to sync pending token.
  Future<void> retryRegistration() async {
    try {
      final token = await getStoredToken();
      if (token == null) {
        debugPrint('DeviceRepository: No token to retry');
        return;
      }

      final isSynced = await isTokenSynced();
      if (isSynced) {
        debugPrint('DeviceRepository: Token already synced');
        return;
      }

      if (_connectivityService.isOnline) {
        debugPrint('DeviceRepository: Retrying token registration');
        await registerToken(token);
      }
    } catch (e) {
      debugPrint('DeviceRepository: Retry registration failed - $e');
    }
  }
}

/// Provider for DeviceRepository
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final remoteDataSource = ref.watch(deviceRemoteDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final storageService = ref.watch(secureStorageServiceProvider);

  return DeviceRepository(
    remoteDataSource: remoteDataSource,
    connectivityService: connectivityService,
    storageService: storageService,
  );
});
