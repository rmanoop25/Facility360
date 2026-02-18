import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/secure_storage_service.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

/// Repository handling authentication business logic
/// Coordinates between remote API and local storage
class AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepository({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService storageService,
  })  : _remoteDataSource = remoteDataSource,
        _storageService = storageService;

  /// Login user with email and password
  /// - Calls login API
  /// - Stores JWT token
  /// - Fetches full user profile with permissions
  /// - Stores user data for offline access
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // Call login API
    final authResponse = await _remoteDataSource.login(
      email: email,
      password: password,
    );

    // Store token and expiry
    await _storageService.saveAccessToken(authResponse.accessToken);
    await _storageService.saveTokenExpiry(authResponse.tokenExpiry);

    // Fetch full user profile with permissions
    final fullUser = await _remoteDataSource.getCurrentUser();

    // Store user data for offline access
    await _storageService.saveUserData(fullUser);

    return fullUser;
  }

  /// Logout user
  /// - Calls logout API to invalidate token on server
  /// - Clears all local storage
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } finally {
      // Always clear local data, even if API call fails
      await _storageService.clearAll();
    }
  }

  /// Check if user has a valid session
  Future<bool> hasValidSession() async {
    return await _storageService.hasValidSession();
  }

  /// Get stored user data (for offline access)
  Future<UserModel?> getStoredUser() async {
    return await _storageService.getUserData();
  }

  /// Restore session from stored data
  /// Called on app startup to check if user is already logged in
  /// Returns user if valid session exists, null otherwise
  Future<UserModel?> restoreSession() async {
    final hasSession = await hasValidSession();
    if (!hasSession) return null;

    // Try to get fresh user data from API
    try {
      final user = await _remoteDataSource.getCurrentUser();
      await _storageService.saveUserData(user);
      return user;
    } on ApiException {
      // If API fails (e.g., no network), return stored user data
      return await _storageService.getUserData();
    }
  }

  /// Refresh the authentication token
  /// Called automatically by interceptor on 401
  Future<bool> refreshToken() async {
    try {
      final authResponse = await _remoteDataSource.refreshToken();
      await _storageService.saveAccessToken(authResponse.accessToken);
      await _storageService.saveTokenExpiry(authResponse.tokenExpiry);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current access token (for debugging/testing)
  Future<String?> getAccessToken() async {
    return await _storageService.getAccessToken();
  }
}

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final storageService = ref.watch(secureStorageServiceProvider);
  return AuthRepository(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
