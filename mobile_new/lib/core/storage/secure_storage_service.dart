import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/user_model.dart';
import '../api/api_constants.dart';

/// Service for securely storing authentication data
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  // Token Management

  /// Save JWT access token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: ApiConstants.accessTokenKey, value: token);
  }

  /// Get stored JWT access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: ApiConstants.accessTokenKey);
  }

  /// Save token expiry timestamp
  Future<void> saveTokenExpiry(DateTime expiry) async {
    await _storage.write(
      key: ApiConstants.tokenExpiryKey,
      value: expiry.toIso8601String(),
    );
  }

  /// Get stored token expiry timestamp
  Future<DateTime?> getTokenExpiry() async {
    final expiryString = await _storage.read(key: ApiConstants.tokenExpiryKey);
    if (expiryString == null) return null;
    return DateTime.tryParse(expiryString);
  }

  /// Check if token is expired (with 5 minute safety margin)
  Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    // Consider token expired 5 minutes before actual expiry for safety
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)));
  }

  // User Data Management

  /// Save user data for offline access
  Future<void> saveUserData(UserModel user) async {
    final jsonString = jsonEncode(user.toJson());
    await _storage.write(key: ApiConstants.userDataKey, value: jsonString);
  }

  /// Get stored user data
  Future<UserModel?> getUserData() async {
    final jsonString = await _storage.read(key: ApiConstants.userDataKey);
    if (jsonString == null) return null;
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserModel.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Clear all authentication data (for logout)
  Future<void> clearAll() async {
    await _storage.delete(key: ApiConstants.accessTokenKey);
    await _storage.delete(key: ApiConstants.tokenExpiryKey);
    await _storage.delete(key: ApiConstants.userDataKey);
  }

  /// Check if user has a valid session (token exists and not expired)
  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    if (token == null) return false;
    return !(await isTokenExpired());
  }

  // Generic Key-Value Storage

  /// Read a value by key
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Write a value by key
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Delete a value by key
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

/// Provider for SecureStorageService
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
