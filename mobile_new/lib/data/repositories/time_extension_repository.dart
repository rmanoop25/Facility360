import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_queue_service.dart';
import '../../core/sync/sync_operation.dart';
import '../../domain/enums/extension_status.dart';
import '../models/time_extension_request_model.dart';

/// Repository for time extension requests with offline support
///
/// Handles extension requests from SPs and approval/rejection from admins.
/// Supports offline request creation with sync queue.
class TimeExtensionRepository {
  final ApiClient _apiClient;
  final ConnectivityService _connectivityService;
  final SyncQueueService _syncQueueService;

  TimeExtensionRepository({
    required ApiClient apiClient,
    required ConnectivityService connectivityService,
    required SyncQueueService syncQueueService,
  })  : _apiClient = apiClient,
        _connectivityService = connectivityService,
        _syncQueueService = syncQueueService;

  /// SP: Request time extension (offline-capable)
  ///
  /// Creates extension request online or queues for sync if offline.
  Future<TimeExtensionRequestModel> requestExtension({
    required int assignmentId,
    required int requestedMinutes,
    required String reason,
  }) async {
    if (_connectivityService.isOnline) {
      // Online: direct API call
      try {
        final response = await _apiClient.post(
          ApiConstants.requestExtension,
          data: {
            'assignment_id': assignmentId,
            'requested_minutes': requestedMinutes,
            'reason': reason,
          },
        );

        if (response['success'] != true) {
          throw Exception(
            response['message'] as String? ?? 'Failed to request extension',
          );
        }

        return TimeExtensionRequestModel.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('TimeExtensionRepository: Request failed - $e');
        rethrow;
      }
    } else {
      // Offline: create local model and queue for sync
      final localRequest = TimeExtensionRequestModel(
        id: -DateTime.now().millisecondsSinceEpoch, // Negative = local
        assignmentId: assignmentId,
        requestedBy: 0, // Will be set by server
        requestedMinutes: requestedMinutes,
        reason: reason,
        status: ExtensionStatus.pending,
        requestedAt: DateTime.now(),
      );

      // Queue for sync when online
      await _syncQueueService.enqueue(
        type: SyncOperationType.create,
        entity: SyncEntityType.timeExtension,
        localId: 'extension_${localRequest.id}',
        data: {
          'assignment_id': assignmentId,
          'requested_minutes': requestedMinutes,
          'reason': reason,
        },
      );

      debugPrint(
        'TimeExtensionRepository: Extension request queued for sync (offline)',
      );

      return localRequest;
    }
  }

  /// SP: Get my extension requests
  Future<List<TimeExtensionRequestModel>> getMyRequests() async {
    try {
      final response = await _apiClient.get(ApiConstants.myExtensionRequests);

      if (response['success'] != true) {
        throw Exception(
          response['message'] as String? ?? 'Failed to fetch extension requests',
        );
      }

      final data = response['data'] as List<dynamic>;
      return data
          .map((json) =>
              TimeExtensionRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('TimeExtensionRepository: getMyRequests error - $e');
      rethrow;
    }
  }

  /// Admin: Get all extension requests with filters
  Future<List<TimeExtensionRequestModel>> getAllRequests({
    String? status,
    int? assignmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (assignmentId != null) queryParams['assignment_id'] = assignmentId;

      final response = await _apiClient.get(
        ApiConstants.adminExtensions,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response['success'] != true) {
        throw Exception(
          response['message'] as String? ?? 'Failed to fetch extension requests',
        );
      }

      final data = response['data'] as List<dynamic>;
      return data
          .map((json) =>
              TimeExtensionRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('TimeExtensionRepository: getAllRequests error - $e');
      rethrow;
    }
  }

  /// Admin: Approve extension request
  Future<TimeExtensionRequestModel> approveExtension(
    int extensionId, {
    String? adminNotes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (adminNotes != null && adminNotes.isNotEmpty) {
        data['admin_notes'] = adminNotes;
      }

      final response = await _apiClient.post(
        ApiConstants.approveExtension(extensionId),
        data: data.isNotEmpty ? data : null,
      );

      if (response['success'] != true) {
        throw Exception(
          response['message'] as String? ?? 'Failed to approve extension',
        );
      }

      return TimeExtensionRequestModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('TimeExtensionRepository: approveExtension error - $e');
      rethrow;
    }
  }

  /// Admin: Reject extension request
  Future<TimeExtensionRequestModel> rejectExtension(
    int extensionId, {
    required String adminNotes,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.rejectExtension(extensionId),
        data: {'admin_notes': adminNotes},
      );

      if (response['success'] != true) {
        throw Exception(
          response['message'] as String? ?? 'Failed to reject extension',
        );
      }

      return TimeExtensionRequestModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('TimeExtensionRepository: rejectExtension error - $e');
      rethrow;
    }
  }

  /// Sync handler for queue service (called when syncing offline requests)
  Future<int> syncExtensionRequest(
    String localId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.post(
      ApiConstants.requestExtension,
      data: data,
    );

    if (response['success'] != true) {
      throw Exception(
        response['message'] as String? ?? 'Failed to sync extension request',
      );
    }

    // Return server ID for updating local references
    return response['data']['id'] as int;
  }
}

/// Provider for TimeExtensionRepository
final timeExtensionRepositoryProvider = Provider<TimeExtensionRepository>((ref) {
  return TimeExtensionRepository(
    apiClient: ref.watch(apiClientProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
    syncQueueService: ref.watch(syncQueueServiceProvider),
  );
});
