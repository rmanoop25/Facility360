import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../models/issue_model.dart';
import '../models/paginated_response.dart';
import '../models/service_provider_model.dart';
import '../models/time_slot_model.dart';

/// Remote data source for admin issue operations
class AdminIssueRemoteDataSource {
  final ApiClient _apiClient;

  AdminIssueRemoteDataSource(this._apiClient);

  /// Get paginated list of all issues (admin view)
  Future<PaginatedResponse<IssueModel>> getIssues({
    String? status,
    String? priority,
    int? categoryId,
    int? tenantId,
    String? search,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };

      if (status != null) queryParams['status'] = status;
      if (priority != null) queryParams['priority'] = priority;
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (tenantId != null) queryParams['tenant_id'] = tenantId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _apiClient.get(
        ApiConstants.adminIssues,
        queryParameters: queryParams,
      );

      final data = response['data'] as List<dynamic>;
      final issues = data
          .map((json) => IssueModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return PaginatedResponse(
        data: issues,
        currentPage: response['meta']?['current_page'] as int? ?? page,
        lastPage: response['meta']?['last_page'] as int? ?? 1,
        perPage: response['meta']?['per_page'] as int? ?? perPage,
        total: response['meta']?['total'] as int? ?? issues.length,
      );
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: getIssues error - $e');
      rethrow;
    }
  }

  /// Get single issue by ID (admin view with full details)
  Future<IssueModel> getIssue(int id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.adminIssueDetail(id),
      );

      final data = response['data'] as Map<String, dynamic>;
      return IssueModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: getIssue error - $e');
      rethrow;
    }
  }

  /// Create a new issue on behalf of a tenant (admin only)
  ///
  /// [tenantId] - ID of the tenant to create issue for (required)
  /// [title] - Issue title (required)
  /// [description] - Issue description
  /// [categoryIds] - List of category IDs (required)
  /// [priority] - Issue priority (default: medium)
  /// [latitude] - Location latitude
  /// [longitude] - Location longitude
  /// [address] - Location address (from reverse geocoding)
  /// [mediaFiles] - List of media files to upload
  Future<IssueModel> createIssue({
    required int tenantId,
    required String title,
    String? description,
    required List<int> categoryIds,
    String priority = 'medium',
    double? latitude,
    double? longitude,
    String? address,
    List<File>? mediaFiles,
  }) async {
    try {
      // Build form data for multipart upload
      final formData = <String, dynamic>{
        'tenant_id': tenantId,
        'title': title,
        'priority': priority,
      };

      if (description != null && description.isNotEmpty) {
        formData['description'] = description;
      }

      // Add category IDs as array
      for (var i = 0; i < categoryIds.length; i++) {
        formData['category_ids[$i]'] = categoryIds[i];
      }

      if (latitude != null) formData['latitude'] = latitude;
      if (longitude != null) formData['longitude'] = longitude;
      if (address != null) formData['address'] = address;

      // Add media files if provided
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var i = 0; i < mediaFiles.length; i++) {
          final file = mediaFiles[i];
          formData['media[$i]'] = await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          );
        }
      }

      final response = await _apiClient.postMultipart(
        ApiConstants.adminIssues,
        data: formData,
      );

      final data = response['data'] as Map<String, dynamic>;
      return IssueModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: createIssue error - $e');
      rethrow;
    }
  }

  /// Update an existing issue (admin only)
  ///
  /// Uses POST with _method=PUT for multipart form data support.
  /// [issueId] - ID of the issue to update
  /// [title] - Issue title (required)
  /// [description] - Issue description
  /// [priority] - Issue priority
  /// [categoryIds] - List of category IDs
  /// [latitude] - Location latitude
  /// [longitude] - Location longitude
  /// [address] - Location address (from reverse geocoding)
  /// [mediaFiles] - List of new media files to upload
  Future<IssueModel> updateIssue({
    required int issueId,
    required String title,
    String? description,
    String? priority,
    List<int>? categoryIds,
    double? latitude,
    double? longitude,
    String? address,
    List<File>? mediaFiles,
  }) async {
    try {
      final formData = <String, dynamic>{
        'title': title,
        '_method': 'PUT',
      };

      if (description != null) formData['description'] = description;
      if (priority != null) formData['priority'] = priority;
      if (latitude != null) formData['latitude'] = latitude;
      if (longitude != null) formData['longitude'] = longitude;
      if (address != null) formData['address'] = address;

      if (categoryIds != null) {
        for (var i = 0; i < categoryIds.length; i++) {
          formData['category_ids[$i]'] = categoryIds[i];
        }
      }

      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var i = 0; i < mediaFiles.length; i++) {
          final file = mediaFiles[i];
          formData['media[$i]'] = await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          );
        }
      }

      final response = await _apiClient.postMultipart(
        '${ApiConstants.adminIssues}/$issueId',
        data: formData,
      );

      final data = response['data'] as Map<String, dynamic>;
      return IssueModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: updateIssue error - $e');
      rethrow;
    }
  }

  /// Assign issue to a service provider
  Future<IssueModel> assignIssue(
    int issueId, {
    int? categoryId,
    required int serviceProviderId,
    int? workTypeId,
    int? allocatedDurationMinutes,
    bool? isCustomDuration,
    required String scheduledDate,
    int? timeSlotId, // Single slot (legacy/backward compatible)
    List<int>? timeSlotIds, // Multi-slot (new)
    String? scheduledEndDate, // For multi-day assignments
    String? assignedStartTime,
    String? assignedEndTime,
    String? notes,
  }) async {
    try {
      // Strip seconds from time format (H:i:s -> H:i)
      String? _stripSeconds(String? time) {
        if (time == null) return null;
        if (time.length >= 5) {
          return time.substring(0, 5); // Take only HH:mm
        }
        return time;
      }

      final response = await _apiClient.post(
        ApiConstants.assignIssue(issueId),
        data: {
          if (categoryId != null) 'category_id': categoryId,
          'service_provider_id': serviceProviderId,
          if (workTypeId != null) 'work_type_id': workTypeId,
          if (allocatedDurationMinutes != null)
            'allocated_duration_minutes': allocatedDurationMinutes,
          if (isCustomDuration != null) 'is_custom_duration': isCustomDuration,
          'scheduled_date': scheduledDate,
          if (scheduledEndDate != null) 'scheduled_end_date': scheduledEndDate,
          // Send either multi-slot IDs or single slot ID
          if (timeSlotIds != null && timeSlotIds.isNotEmpty)
            'time_slot_ids': timeSlotIds
          else if (timeSlotId != null)
            'time_slot_id': timeSlotId,
          if (assignedStartTime != null) 'assigned_start_time': _stripSeconds(assignedStartTime),
          if (assignedEndTime != null) 'assigned_end_time': _stripSeconds(assignedEndTime),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      final data = response['data'] as Map<String, dynamic>;
      return IssueModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: assignIssue error - $e');
      rethrow;
    }
  }

  /// Update an existing assignment
  Future<IssueModel> updateAssignment(
    int issueId,
    int assignmentId, {
    int? categoryId,
    required int serviceProviderId,
    int? workTypeId,
    int? allocatedDurationMinutes,
    bool? isCustomDuration,
    required String scheduledDate,
    int? timeSlotId,
    List<int>? timeSlotIds,
    String? scheduledEndDate,
    String? assignedStartTime,
    String? assignedEndTime,
    String? notes,
  }) async {
    try {
      // Strip seconds from time format (H:i:s -> H:i)
      String? _stripSeconds(String? time) {
        if (time == null) return null;
        if (time.length >= 5) {
          return time.substring(0, 5); // Take only HH:mm
        }
        return time;
      }

      final response = await _apiClient.put(
        ApiConstants.updateAssignment(issueId, assignmentId),
        data: {
          if (categoryId != null) 'category_id': categoryId,
          'service_provider_id': serviceProviderId,
          if (workTypeId != null) 'work_type_id': workTypeId,
          if (allocatedDurationMinutes != null)
            'allocated_duration_minutes': allocatedDurationMinutes,
          if (isCustomDuration != null) 'is_custom_duration': isCustomDuration,
          'scheduled_date': scheduledDate,
          if (scheduledEndDate != null) 'scheduled_end_date': scheduledEndDate,
          if (timeSlotId != null) 'time_slot_id': timeSlotId,
          if (timeSlotIds != null && timeSlotIds.isNotEmpty)
            'time_slot_ids': timeSlotIds,
          if (assignedStartTime != null) 'assigned_start_time': _stripSeconds(assignedStartTime),
          if (assignedEndTime != null) 'assigned_end_time': _stripSeconds(assignedEndTime),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      if (response['success'] != true) {
        throw Exception(
          response['message'] as String? ?? 'Failed to update assignment',
        );
      }

      final data = response['data'] as Map<String, dynamic>;
      return IssueModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: updateAssignment error - $e');
      rethrow;
    }
  }

  /// Approve finished work on an issue
  Future<IssueModel> approveIssue(int issueId) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.approveIssue(issueId),
      );

      final data = response['data'] as Map<String, dynamic>;
      return IssueModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: approveIssue error - $e');
      rethrow;
    }
  }

  /// Cancel an issue (admin)
  Future<IssueModel> cancelIssue(int issueId, {required String reason}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.adminCancelIssue(issueId),
        data: {'reason': reason},
      );

      final data = response['data'] as Map<String, dynamic>;
      return IssueModel.fromJson(data);
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: cancelIssue error - $e');
      rethrow;
    }
  }

  /// Get list of service providers (for assignment)
  Future<List<ServiceProviderModel>> getServiceProviders({
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;

      final response = await _apiClient.get(
        ApiConstants.serviceProviders,
        queryParameters: queryParams,
      );

      final data = response['data'] as List<dynamic>;
      return data
          .map((json) =>
              ServiceProviderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('AdminIssueRemoteDataSource: getServiceProviders error - $e');
      rethrow;
    }
  }

  /// Get service provider availability for a specific date
  Future<List<TimeSlotModel>> getServiceProviderAvailability(
    int serviceProviderId, {
    required String date,
    int? minDurationMinutes,
  }) async {
    try {
      final queryParams = {
        'date': date,
      };

      if (minDurationMinutes != null) {
        queryParams['min_duration_minutes'] = minDurationMinutes.toString();
      }

      final response = await _apiClient.get(
        ApiConstants.serviceProviderAvailability(serviceProviderId),
        queryParameters: queryParams,
      );

      // Parse response structure: data -> time_slots[]
      final data = response['data'] as Map<String, dynamic>;
      final timeSlots = data['time_slots'] as List<dynamic>;

      return timeSlots
          .map((json) => TimeSlotModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint(
          'AdminIssueRemoteDataSource: getServiceProviderAvailability error - $e');
      rethrow;
    }
  }

  /// Auto-select time slots across multiple days for a given duration
  Future<Map<String, dynamic>> autoSelectSlots(
    int serviceProviderId, {
    required String startDate,
    required int durationMinutes,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.serviceProviderAutoSelectSlots(serviceProviderId),
        data: {
          'start_date': startDate,
          'duration_minutes': durationMinutes,
        },
      );

      // Return the full data object
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint(
          'AdminIssueRemoteDataSource: autoSelectSlots error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminIssueRemoteDataSource
final adminIssueRemoteDataSourceProvider =
    Provider<AdminIssueRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminIssueRemoteDataSource(apiClient);
});
