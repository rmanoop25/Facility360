import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage_service.dart';
import 'api_constants.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Main API client using Dio
class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storageService;

  /// Stream that emits when the session has expired (token refresh failed).
  /// Auth provider listens to this to trigger logout and redirect to login.
  final _sessionExpiredController = StreamController<void>.broadcast();
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  ApiClient({required SecureStorageService storageService})
      : _storageService = storageService {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Create separate Dio instance for token refresh (avoids interceptor loop)
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Add auth interceptor
    _dio.interceptors.add(
      AuthInterceptor(
        storageService: _storageService,
        refreshDio: refreshDio,
        onSessionExpired: () => _sessionExpiredController.add(null),
      ),
    );

    // Add logging in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  /// Generic GET request
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Generic POST request
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Multipart POST request (for file uploads)
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, dynamic> data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final formData = FormData.fromMap(data);
      final response = await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Generic PUT request
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Generic DELETE request
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle successful response
  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw const ApiException(message: 'Invalid response format');
  }

  /// Convert DioException to ApiException
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(message: 'Connection timed out');

      case DioExceptionType.connectionError:
        if (error.error is SocketException) {
          return const NetworkException();
        }
        return const NetworkException(message: 'Connection error');

      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);

      case DioExceptionType.cancel:
        return const ApiException(message: 'Request cancelled');

      case DioExceptionType.unknown:
        // Check if error is a JSON parsing issue
        if (error.error is FormatException) {
          return const ApiException(
            message: 'Invalid response format from server',
          );
        }
        return ApiException(
          message: error.message ?? 'Unknown error',
          statusCode: error.response?.statusCode,
        );

      default:
        return ApiException(
          message: error.message ?? 'Unknown error',
          statusCode: error.response?.statusCode,
        );
    }
  }

  /// Handle bad HTTP responses
  ApiException _handleBadResponse(Response? response) {
    if (response == null) {
      return const ServerException();
    }

    final statusCode = response.statusCode;
    final data = response.data;

    switch (statusCode) {
      case 401:
        return const UnauthorizedException();

      case 422:
        // Validation error
        if (data is Map<String, dynamic> && data['errors'] != null) {
          final errors = <String, List<String>>{};
          (data['errors'] as Map).forEach((key, value) {
            errors[key.toString()] = List<String>.from(value as List);
          });
          return ValidationException(errors: errors);
        }
        return ValidationException(
          errors: {},
          message: data is Map ? data['message'] ?? 'Validation failed' : 'Validation failed',
        );

      case 403:
        return ApiException(
          message: data is Map ? data['message'] ?? 'Forbidden' : 'Forbidden',
          statusCode: 403,
        );

      case 404:
        return ApiException(
          message: data is Map ? data['message'] ?? 'Not found' : 'Not found',
          statusCode: 404,
        );

      case 500:
      case 502:
      case 503:
        return ServerException(
          message: 'Server error',
          statusCode: statusCode,
        );

      default:
        String message = 'Request failed';
        if (data is Map<String, dynamic> && data['message'] != null) {
          message = data['message'] as String;
        }
        return ApiException(message: message, statusCode: statusCode);
    }
  }
}

/// Provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  return ApiClient(storageService: storageService);
});
