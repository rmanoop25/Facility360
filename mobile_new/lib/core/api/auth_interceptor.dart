import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';
import 'api_constants.dart';

/// Interceptor for handling JWT authentication
/// - Adds Bearer token to requests
/// - Auto-refreshes token on 401
/// - Queues concurrent 401 requests to wait for refresh
/// - Notifies via [onSessionExpired] when refresh fails
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storageService;
  final Dio _refreshDio; // Separate Dio instance for refresh to avoid infinite loop
  final VoidCallback? _onSessionExpired;
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required SecureStorageService storageService,
    required Dio refreshDio,
    VoidCallback? onSessionExpired,
  })  : _storageService = storageService,
        _refreshDio = refreshDio,
        _onSessionExpired = onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for login endpoint
    if (options.path.contains('/auth/login')) {
      return handler.next(options);
    }

    final token = await _storageService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized - attempt token refresh
    if (err.response?.statusCode == 401) {
      // Don't refresh if it's already a refresh request that failed
      if (err.requestOptions.path.contains('/auth/refresh') ||
          err.requestOptions.path.contains('/auth/login')) {
        return handler.next(err);
      }

      // If another request is already refreshing, wait for it
      if (_isRefreshing) {
        final newToken = await _refreshCompleter?.future;
        if (newToken != null) {
          // Retry original request with new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          try {
            final retryResponse = await _refreshDio.fetch(options);
            return handler.resolve(retryResponse);
          } catch (e) {
            return handler.next(err);
          }
        }
        return handler.next(err);
      }

      _isRefreshing = true;
      _refreshCompleter = Completer<String?>();

      try {
        final currentToken = await _storageService.getAccessToken();
        if (currentToken == null) {
          _refreshCompleter!.complete(null);
          _isRefreshing = false;
          _onSessionExpired?.call();
          return handler.next(err);
        }

        // Attempt refresh using separate Dio instance
        final response = await _refreshDio.post(
          '${ApiConstants.baseUrl}${ApiConstants.refresh}',
          options: Options(
            headers: {'Authorization': 'Bearer $currentToken'},
          ),
        );

        if (response.statusCode == 200 && response.data['success'] == true) {
          final data = response.data['data'] as Map<String, dynamic>;
          final newToken = data['access_token'] as String;
          final expiresIn = data['expires_in'] as int;

          // Save new token
          await _storageService.saveAccessToken(newToken);
          await _storageService.saveTokenExpiry(
            DateTime.now().add(Duration(seconds: expiresIn)),
          );

          // Notify waiting requests that refresh succeeded
          _refreshCompleter!.complete(newToken);
          _isRefreshing = false;

          // Retry original request with new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';

          final retryResponse = await _refreshDio.fetch(options);
          return handler.resolve(retryResponse);
        } else {
          // Non-200 or success=false — session expired
          _refreshCompleter!.complete(null);
          _isRefreshing = false;
          await _storageService.clearAll();
          _onSessionExpired?.call();
        }
      } catch (e) {
        debugPrint('AuthInterceptor: token refresh failed - $e');
        // Refresh failed - user needs to login again
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        await _storageService.clearAll();
        _onSessionExpired?.call();
      }
    }

    return handler.next(err);
  }
}
