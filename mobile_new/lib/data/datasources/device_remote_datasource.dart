import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';

/// Remote data source for device FCM token operations
class DeviceRemoteDataSource {
  final ApiClient _apiClient;

  DeviceRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Register FCM token with backend
  ///
  /// [token] - The FCM registration token
  /// [deviceType] - The device platform (android, ios, etc.)
  Future<bool> registerToken(String token, {String? deviceType}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.registerDevice,
        data: {
          'token': token,
          'device_type': deviceType ?? Platform.operatingSystem,
        },
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to register device',
        );
      }

      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Failed to register device: $e',
      );
    }
  }

  /// Remove FCM token from backend
  ///
  /// [token] - The FCM token to remove
  Future<bool> removeToken(String token) async {
    try {
      final response = await _apiClient.delete(ApiConstants.removeDevice(token));

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to remove device',
        );
      }

      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Failed to remove device: $e',
      );
    }
  }
}

/// Provider for DeviceRemoteDataSource
final deviceRemoteDataSourceProvider = Provider<DeviceRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DeviceRemoteDataSource(apiClient: apiClient);
});
