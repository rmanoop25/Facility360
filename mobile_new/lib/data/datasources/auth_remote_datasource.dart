import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Remote data source for authentication operations
class AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Login with email and password
  /// Returns auth response with token and user data
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      data: {
        'email': email,
        'password': password,
      },
    );

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Login failed',
      );
    }

    return AuthResponseModel.fromJson(response);
  }

  /// Logout (invalidate current token on server)
  Future<void> logout() async {
    try {
      await _apiClient.post(ApiConstants.logout);
    } catch (e) {
      // Ignore errors on logout - we'll clear local data anyway
      // Server might already have invalidated the token
    }
  }

  /// Get current user profile with full permissions
  /// Call this after login to get complete user data
  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get(ApiConstants.me);

    if (response['success'] != true) {
      throw const ApiException(message: 'Failed to get user profile');
    }

    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Refresh the authentication token
  /// Returns new auth response with fresh token
  Future<AuthResponseModel> refreshToken() async {
    final response = await _apiClient.post(ApiConstants.refresh);

    if (response['success'] != true) {
      throw const UnauthorizedException(message: 'Token refresh failed');
    }

    return AuthResponseModel.fromJson(response);
  }
}

/// Provider for AuthRemoteDataSource
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRemoteDataSource(apiClient: apiClient);
});
