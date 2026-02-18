import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../models/issue_model.dart';
import '../models/paginated_response.dart';

/// Remote data source for issue operations (Tenant endpoints)
class IssueRemoteDataSource {
  final ApiClient _apiClient;

  IssueRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Fetch paginated list of issues for the current tenant
  ///
  /// [status] - Filter by issue status (pending, assigned, in_progress, etc.)
  /// [priority] - Filter by priority (low, medium, high)
  /// [activeOnly] - If true, only return active issues (not completed/cancelled)
  /// [page] - Page number for pagination
  /// [perPage] - Items per page (default: 15)
  Future<PaginatedResponse<IssueModel>> getIssues({
    String? status,
    String? priority,
    bool? activeOnly,
    int page = 1,
    int perPage = 15,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;
    if (activeOnly != null) queryParams['active_only'] = activeOnly;

    final response = await _apiClient.get(
      ApiConstants.issues,
      queryParameters: queryParams,
    );

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Failed to fetch issues',
      );
    }

    return PaginatedResponse.fromJson(response, IssueModel.fromJson);
  }

  /// Fetch a single issue by ID with full details
  Future<IssueModel> getIssue(int id) async {
    final response = await _apiClient.get(ApiConstants.issueDetail(id));

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Issue not found',
      );
    }

    return IssueModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Create a new issue
  ///
  /// [title] - Issue title (required)
  /// [description] - Issue description
  /// [categoryIds] - List of category IDs (required)
  /// [priority] - Issue priority (default: medium)
  /// [latitude] - Location latitude
  /// [longitude] - Location longitude
  /// [address] - Location address (from reverse geocoding)
  /// [mediaFiles] - List of media files to upload
  Future<IssueModel> createIssue({
    required String title,
    String? description,
    required List<int> categoryIds,
    String priority = 'medium',
    double? latitude,
    double? longitude,
    String? address,
    List<File>? mediaFiles,
  }) async {
    // Build form data for multipart upload
    final formData = <String, dynamic>{
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
      ApiConstants.issues,
      data: formData,
    );

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Failed to create issue',
      );
    }

    return IssueModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Cancel an issue
  ///
  /// [id] - Issue ID to cancel
  /// [reason] - Optional cancellation reason
  Future<IssueModel> cancelIssue(int id, {String? reason}) async {
    final data = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) {
      data['reason'] = reason;
    }

    final response = await _apiClient.post(
      ApiConstants.cancelIssue(id),
      data: data.isNotEmpty ? data : null,
    );

    if (response['success'] != true) {
      throw ApiException(
        message: response['message'] as String? ?? 'Failed to cancel issue',
      );
    }

    return IssueModel.fromJson(response['data'] as Map<String, dynamic>);
  }
}

/// Provider for IssueRemoteDataSource
final issueRemoteDataSourceProvider = Provider<IssueRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return IssueRemoteDataSource(apiClient: apiClient);
});
