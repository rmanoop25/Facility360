import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/tenant_model.dart';
import '../models/paginated_response.dart';

/// Remote data source for admin tenant CRUD operations
class AdminTenantRemoteDataSource {
  final ApiClient _apiClient;

  AdminTenantRemoteDataSource(this._apiClient);

  /// Get paginated list of tenants with optional filters
  Future<PaginatedResponse<TenantModel>> getTenants({
    String? search,
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
      if (isActive != null) {
        queryParams['is_active'] = isActive ? '1' : '0';
      }

      final response = await _apiClient.get(
        ApiConstants.adminTenants,
        queryParameters: queryParams,
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to fetch tenants',
        );
      }

      final data = response['data'] as List<dynamic>;
      final tenants = data
          .map((json) => TenantModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return PaginatedResponse(
        data: tenants,
        currentPage: response['meta']?['current_page'] as int? ?? page,
        lastPage: response['meta']?['last_page'] as int? ?? 1,
        perPage: response['meta']?['per_page'] as int? ?? perPage,
        total: response['meta']?['total'] as int? ?? tenants.length,
      );
    } catch (e) {
      debugPrint('AdminTenantRemoteDataSource: getTenants error - $e');
      rethrow;
    }
  }

  /// Get a single tenant by ID with full details
  Future<TenantModel> getTenant(int id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.adminTenantDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Tenant not found',
        );
      }

      return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminTenantRemoteDataSource: getTenant error - $e');
      rethrow;
    }
  }

  /// Create a new tenant with user account
  Future<TenantModel> createTenant({
    required String name,
    required String email,
    required String password,
    required String unitNumber,
    required String buildingName,
    String? phone,
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
          'unit_number': unitNumber,
          'building_name': buildingName,
          if (phone != null) 'phone': phone,
        };

        // Add profile photo
        formData['profile_photo'] = await MultipartFile.fromFile(
          profilePhoto.path,
          filename: profilePhoto.path.split('/').last,
        );

        response = await _apiClient.postMultipart(
          ApiConstants.adminTenants,
          data: formData,
        );
      } else {
        // Regular JSON request
        response = await _apiClient.post(
          ApiConstants.adminTenants,
          data: {
            'name': name,
            'email': email,
            'password': password,
            'unit_number': unitNumber,
            'building_name': buildingName,
            if (phone != null) 'phone': phone,
          },
        );
      }

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to create tenant',
          data: response['errors'],
        );
      }

      return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminTenantRemoteDataSource: createTenant error - $e');
      rethrow;
    }
  }

  /// Update an existing tenant
  Future<TenantModel> updateTenant(
    int id, {
    String? name,
    String? email,
    String? password,
    String? unitNumber,
    String? buildingName,
    String? phone,
    bool? isActive,
    File? profilePhoto,
  }) async {
    try {
      Map<String, dynamic> response;

      if (profilePhoto != null) {
        // Use multipart upload when profile photo is provided
        final formData = <String, dynamic>{
          '_method': 'PUT', // Laravel method spoofing for multipart
        };

        if (name != null) formData['name'] = name;
        if (email != null) formData['email'] = email;
        if (password != null && password.isNotEmpty) formData['password'] = password;
        if (unitNumber != null) formData['unit_number'] = unitNumber;
        if (buildingName != null) formData['building_name'] = buildingName;
        if (phone != null) formData['phone'] = phone;
        if (isActive != null) formData['is_active'] = isActive;

        // Add profile photo
        formData['profile_photo'] = await MultipartFile.fromFile(
          profilePhoto.path,
          filename: profilePhoto.path.split('/').last,
        );

        response = await _apiClient.postMultipart(
          ApiConstants.adminTenantDetail(id),
          data: formData,
        );
      } else {
        // Regular JSON request
        final data = <String, dynamic>{};
        if (name != null) data['name'] = name;
        if (email != null) data['email'] = email;
        if (password != null && password.isNotEmpty) data['password'] = password;
        if (unitNumber != null) data['unit_number'] = unitNumber;
        if (buildingName != null) data['building_name'] = buildingName;
        if (phone != null) data['phone'] = phone;
        if (isActive != null) data['is_active'] = isActive;

        response = await _apiClient.put(
          ApiConstants.adminTenantDetail(id),
          data: data,
        );
      }

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to update tenant',
          data: response['errors'],
        );
      }

      return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminTenantRemoteDataSource: updateTenant error - $e');
      rethrow;
    }
  }

  /// Delete a tenant (soft delete, super_admin only)
  Future<void> deleteTenant(int id) async {
    try {
      final response = await _apiClient.delete(
        ApiConstants.adminTenantDetail(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to delete tenant',
        );
      }
    } catch (e) {
      debugPrint('AdminTenantRemoteDataSource: deleteTenant error - $e');
      rethrow;
    }
  }

  /// Toggle tenant active status
  Future<TenantModel> toggleActive(int id) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.adminTenantToggle(id),
      );

      if (response['success'] != true) {
        throw ApiException(
          message: response['message'] as String? ?? 'Failed to toggle tenant status',
        );
      }

      return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AdminTenantRemoteDataSource: toggleActive error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminTenantRemoteDataSource
final adminTenantRemoteDataSourceProvider =
    Provider<AdminTenantRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminTenantRemoteDataSource(apiClient);
});
