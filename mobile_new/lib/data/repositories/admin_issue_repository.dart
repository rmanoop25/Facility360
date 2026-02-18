import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../datasources/admin_issue_remote_datasource.dart';
import '../models/issue_model.dart';
import '../models/paginated_response.dart';
import '../models/service_provider_model.dart';
import '../models/time_slot_model.dart';

/// Repository for admin issue operations
/// Note: Admin operations require online connectivity (no offline support)
class AdminIssueRepository {
  final AdminIssueRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivityService;

  AdminIssueRepository({
    required AdminIssueRemoteDataSource remoteDataSource,
    required ConnectivityService connectivityService,
  })  : _remoteDataSource = remoteDataSource,
        _connectivityService = connectivityService;

  /// Check if online, throw if not
  void _requireOnline() {
    if (!_connectivityService.isOnline) {
      throw const ApiException(
        message: 'This operation requires an internet connection',
      );
    }
  }

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
    _requireOnline();

    try {
      return await _remoteDataSource.getIssues(
        status: status,
        priority: priority,
        categoryId: categoryId,
        tenantId: tenantId,
        search: search,
        sortBy: sortBy,
        sortOrder: sortOrder,
        page: page,
        perPage: perPage,
      );
    } catch (e) {
      debugPrint('AdminIssueRepository: getIssues error - $e');
      rethrow;
    }
  }

  /// Get single issue by ID (admin view)
  Future<IssueModel> getIssue(int id) async {
    _requireOnline();

    try {
      return await _remoteDataSource.getIssue(id);
    } catch (e) {
      debugPrint('AdminIssueRepository: getIssue error - $e');
      rethrow;
    }
  }

  /// Create issue on behalf of a tenant (admin only)
  ///
  /// [tenantId] - ID of the tenant to create issue for
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
    _requireOnline();

    try {
      return await _remoteDataSource.createIssue(
        tenantId: tenantId,
        title: title,
        description: description,
        categoryIds: categoryIds,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
        address: address,
        mediaFiles: mediaFiles,
      );
    } catch (e) {
      debugPrint('AdminIssueRepository: createIssue error - $e');
      rethrow;
    }
  }

  /// Update an existing issue (admin only)
  ///
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
    _requireOnline();

    try {
      return await _remoteDataSource.updateIssue(
        issueId: issueId,
        title: title,
        description: description,
        priority: priority,
        categoryIds: categoryIds,
        latitude: latitude,
        longitude: longitude,
        address: address,
        mediaFiles: mediaFiles,
      );
    } catch (e) {
      debugPrint('AdminIssueRepository: updateIssue error - $e');
      rethrow;
    }
  }

  /// Assign issue to a service provider
  /// Supports both single-slot (timeSlotId) and multi-slot (timeSlotIds) assignments
  Future<IssueModel> assignIssue(
    int issueId, {
    int? categoryId,
    required int serviceProviderId,
    int? workTypeId,
    int? allocatedDurationMinutes,
    bool? isCustomDuration,
    required DateTime scheduledDate,
    int? timeSlotId, // Single slot (legacy/backward compatible)
    List<int>? timeSlotIds, // Multi-slot (new)
    DateTime? scheduledEndDate, // For multi-day assignments
    String? assignedStartTime,
    String? assignedEndTime,
    String? notes,
  }) async {
    _requireOnline();

    try {
      final dateString =
          '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';

      String? endDateString;
      if (scheduledEndDate != null) {
        endDateString =
            '${scheduledEndDate.year}-${scheduledEndDate.month.toString().padLeft(2, '0')}-${scheduledEndDate.day.toString().padLeft(2, '0')}';
      }

      return await _remoteDataSource.assignIssue(
        issueId,
        categoryId: categoryId,
        serviceProviderId: serviceProviderId,
        workTypeId: workTypeId,
        allocatedDurationMinutes: allocatedDurationMinutes,
        isCustomDuration: isCustomDuration,
        scheduledDate: dateString,
        timeSlotId: timeSlotId,
        timeSlotIds: timeSlotIds,
        scheduledEndDate: endDateString,
        assignedStartTime: assignedStartTime,
        assignedEndTime: assignedEndTime,
        notes: notes,
      );
    } catch (e) {
      debugPrint('AdminIssueRepository: assignIssue error - $e');
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
    required DateTime scheduledDate,
    int? timeSlotId,
    List<int>? timeSlotIds,
    DateTime? scheduledEndDate,
    String? assignedStartTime,
    String? assignedEndTime,
    String? notes,
  }) async {
    _requireOnline();

    try {
      // Format dates as YYYY-MM-DD
      final dateString =
          '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';

      String? endDateString;
      if (scheduledEndDate != null) {
        endDateString =
            '${scheduledEndDate.year}-${scheduledEndDate.month.toString().padLeft(2, '0')}-${scheduledEndDate.day.toString().padLeft(2, '0')}';
      }

      return await _remoteDataSource.updateAssignment(
        issueId,
        assignmentId,
        categoryId: categoryId,
        serviceProviderId: serviceProviderId,
        workTypeId: workTypeId,
        allocatedDurationMinutes: allocatedDurationMinutes,
        isCustomDuration: isCustomDuration,
        scheduledDate: dateString,
        timeSlotId: timeSlotId,
        timeSlotIds: timeSlotIds,
        scheduledEndDate: endDateString,
        assignedStartTime: assignedStartTime,
        assignedEndTime: assignedEndTime,
        notes: notes,
      );
    } catch (e) {
      debugPrint('AdminIssueRepository: updateAssignment error - $e');
      rethrow;
    }
  }

  /// Approve finished work
  Future<IssueModel> approveIssue(int issueId) async {
    _requireOnline();

    try {
      return await _remoteDataSource.approveIssue(issueId);
    } catch (e) {
      debugPrint('AdminIssueRepository: approveIssue error - $e');
      rethrow;
    }
  }

  /// Cancel an issue
  Future<IssueModel> cancelIssue(int issueId, {required String reason}) async {
    _requireOnline();

    try {
      return await _remoteDataSource.cancelIssue(issueId, reason: reason);
    } catch (e) {
      debugPrint('AdminIssueRepository: cancelIssue error - $e');
      rethrow;
    }
  }

  /// Get service providers for assignment
  Future<List<ServiceProviderModel>> getServiceProviders({
    int? categoryId,
  }) async {
    _requireOnline();

    try {
      return await _remoteDataSource.getServiceProviders(categoryId: categoryId);
    } catch (e) {
      debugPrint('AdminIssueRepository: getServiceProviders error - $e');
      rethrow;
    }
  }

  /// Get service provider availability for a date
  Future<List<TimeSlotModel>> getServiceProviderAvailability(
    int serviceProviderId, {
    required DateTime date,
    int? minDurationMinutes,
  }) async {
    _requireOnline();

    try {
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      return await _remoteDataSource.getServiceProviderAvailability(
        serviceProviderId,
        date: dateString,
        minDurationMinutes: minDurationMinutes,
      );
    } catch (e) {
      debugPrint(
          'AdminIssueRepository: getServiceProviderAvailability error - $e');
      rethrow;
    }
  }

  /// Auto-select time slots across multiple days for a given duration
  Future<Map<String, dynamic>> autoSelectSlots(
    int serviceProviderId, {
    required DateTime startDate,
    required int durationMinutes,
  }) async {
    _requireOnline();

    try {
      final dateString =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

      return await _remoteDataSource.autoSelectSlots(
        serviceProviderId,
        startDate: dateString,
        durationMinutes: durationMinutes,
      );
    } catch (e) {
      debugPrint('AdminIssueRepository: autoSelectSlots error - $e');
      rethrow;
    }
  }
}

/// Provider for AdminIssueRepository
final adminIssueRepositoryProvider = Provider<AdminIssueRepository>((ref) {
  final remoteDataSource = ref.watch(adminIssueRemoteDataSourceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);

  return AdminIssueRepository(
    remoteDataSource: remoteDataSource,
    connectivityService: connectivityService,
  );
});
