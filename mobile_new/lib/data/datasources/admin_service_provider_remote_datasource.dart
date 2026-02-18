import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/service_provider_model.dart';
import '../models/paginated_response.dart';

/// Remote data source for admin service provider CRUD operations
class AdminServiceProviderRemoteDataSource {
  final ApiClient _apiClient;

  AdminServiceProviderRemoteDataSource(this._apiClient);

  /// Get paginated list of service providers with optional filters
  Future<PaginatedResponse<ServiceProviderModel>> getServiceProviders({
    String? search,
    int? categoryId,
    bool? isAvailable,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }
      if (isAvailable != null) {
        queryParams['is_available'] = isAvailable ? '1' : '0';
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive ? '1' : '0';
      }

      final response = await _apiClient.get(
        ApiConstants.serviceProviders,
        queryParameters: queryParams,
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to fetch service providers',
        );
      }

      final data = response['data'] as List<dynamic>;
      final providers = data
          .map((json) => ServiceProviderModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return PaginatedResponse(
        data: providers,
        currentPage: response['meta']?['current_page'] as int? ?? page,
        lastPage: response['meta']?['last_page'] as int? ?? 1,
        perPage: response['meta']?['per_page'] as int? ?? perPage,
        total: response['meta']?['total'] as int? ?? providers.length,
      );
    } catch (e) {
      debugPrint('AdminServiceProviderRemoteDataSource: getServiceProviders error - $e');
      rethrow;
    }
  }

  /// Get a single service provider by ID with full details (categories, time slots)
  Future<ServiceProviderModel> getServiceProvider(int id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.adminServiceProviderDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Service provider not found',
        );
      }

      return ServiceProviderModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminServiceProviderRemoteDataSource: getServiceProvider error - $e');
      rethrow;
    }
  }

  /// Create a new service provider with user account
  Future<ServiceProviderModel> createServiceProvider({
    required String name,
    required String email,
    required String password,
    required List<int> categoryIds,
    String? phone,
    bool isAvailable = true,
    File? profilePhoto,
  }) async {
    try {
      Map<String, dynamic> response;

      if (profilePhoto != null) {
        // Use multipart upload when profile photo is provided
        final formData = <String, dynamic>{
          'name': name,
          'email': email,
          'password': password,
          'is_available': isAvailable,
          if (phone != null) 'phone': phone,
        };

        // Add category IDs as array
        for (var i = 0; i < categoryIds.length; i++) {
          formData['category_ids[$i]'] = categoryIds[i];
        }

        // Add profile photo
        formData['profile_photo'] = await MultipartFile.fromFile(
          profilePhoto.path,
          filename: profilePhoto.path.split('/').last,
        );

        response = await _apiClient.postMultipart(
          ApiConstants.serviceProviders,
          data: formData,
        );
      } else {
        // Regular JSON request
        response = await _apiClient.post(
          ApiConstants.serviceProviders,
          data: {
            'name': name,
            'email': email,
            'password': password,
            'category_ids': categoryIds,
            if (phone != null) 'phone': phone,
            'is_available': isAvailable,
          },
        );
      }

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to create service provider',
          data: response['errors'],
        );
      }

      return ServiceProviderModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminServiceProviderRemoteDataSource: createServiceProvider error - $e');
      rethrow;
    }
  }

  /// Update an existing service provider
  Future<ServiceProviderModel> updateServiceProvider(
    int id, {
    String? name,
    String? email,
    String? password,
    List<int>? categoryIds,
    String? phone,
    bool? isAvailable,
    bool? isActive,
    File? profilePhoto,
  }) async {
    try {
      Map<String, dynamic> response;

      if (profilePhoto != null) {
        // Use multipart upload when profile photo is provided
        final formData = <String, dynamic>{
          '_method': 'PUT', // Laravel requires this for multipart PUT requests
        };

        if (name != null) formData['name'] = name;
        if (email != null) formData['email'] = email;
        if (password != null && password.isNotEmpty) formData['password'] = password;
        if (phone != null) formData['phone'] = phone;
        if (isAvailable != null) formData['is_available'] = isAvailable;
        if (isActive != null) formData['is_active'] = isActive;

        // Add category IDs as array
        if (categoryIds != null) {
          for (var i = 0; i < categoryIds.length; i++) {
            formData['category_ids[$i]'] = categoryIds[i];
          }
        }

        // Add profile photo
        formData['profile_photo'] = await MultipartFile.fromFile(
          profilePhoto.path,
          filename: profilePhoto.path.split('/').last,
        );

        response = await _apiClient.postMultipart(
          ApiConstants.adminServiceProviderDetail(id),
          data: formData,
        );
      } else {
        // Regular JSON request
        final data = <String, dynamic>{};
        if (name != null) data['name'] = name;
        if (email != null) data['email'] = email;
        if (password != null && password.isNotEmpty) data['password'] = password;
        if (categoryIds != null) data['category_ids'] = categoryIds;
        if (phone != null) data['phone'] = phone;
        if (isAvailable != null) data['is_available'] = isAvailable;
        if (isActive != null) data['is_active'] = isActive;

        response = await _apiClient.put(
          ApiConstants.adminServiceProviderDetail(id),
          data: data,
        );
      }

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to update service provider',
          data: response['errors'],
        );
      }

      return ServiceProviderModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminServiceProviderRemoteDataSource: updateServiceProvider error - $e');
      rethrow;
    }
  }

  /// Delete a service provider
  Future<void> deleteServiceProvider(int id) async {
    try {
      final response = await _apiClient.delete(
        ApiConstants.adminServiceProviderDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to delete service provider',
        );
      }
    } catch (e) {
      debugPrint('AdminServiceProviderRemoteDataSource: deleteServiceProvider error - $e');
      rethrow;
    }
  }

  /// Toggle service provider active status
  Future<ServiceProviderModel> toggleActive(int id) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.adminServiceProviderToggle(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to toggle service provider status',
        );
      }

      return ServiceProviderModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminServiceProviderRemoteDataSource: toggleActive error - $e');
      rethrow;
    }
  }

  /// Toggle service provider availability
  Future<ServiceProviderModel> toggleAvailability(int id) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.adminServiceProviderDetail(id)}/toggle-availability',
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to toggle service provider availability',
        );
      }

      return ServiceProviderModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminServiceProviderRemoteDataSource: toggleAvailability error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminServiceProviderRemoteDataSource
final adminServiceProviderRemoteDataSourceProvider =
    Provider<AdminServiceProviderRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminServiceProviderRemoteDataSource(apiClient);
});
