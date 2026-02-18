import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../models/assignment_model.dart';
import '../models/paginated_response.dart';

/// Remote data source for assignment operations
class AssignmentRemoteDataSource {
  final ApiClient _apiClient;

  AssignmentRemoteDataSource(this._apiClient);

  /// Get paginated list of assignments for service provider
  Future<PaginatedResponse<AssignmentModel>> getAssignments({
    String? status,
    String? date,
    bool? activeOnly,
    bool? inProgressOnly,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (status != null) queryParams['status'] = status;
      if (date != null) queryParams['date'] = date;
      if (activeOnly == true) queryParams['active_only'] = '1';
      if (inProgressOnly == true) queryParams['in_progress_only'] = '1';

      final response = await _apiClient.get(
        ApiConstants.assignments,
        queryParameters: queryParams,
      );

      final data = response['data'] as List<dynamic>;
      final assignments = data
          .map((json) => AssignmentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return PaginatedResponse(
        data: assignments,
        currentPage: response['meta']?['current_page'] as int? ?? page,
        lastPage: response['meta']?['last_page'] as int? ?? 1,
        perPage: response['meta']?['per_page'] as int? ?? perPage,
        total: response['meta']?['total'] as int? ?? assignments.length,
      );
    } catch (e) {
      debugPrint('AssignmentRemoteDataSource: getAssignments error - $e');
      rethrow;
    }
  }

  /// Get single assignment by issue ID
  Future<AssignmentModel> getAssignment(int issueId) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.assignmentDetail(issueId),
      );

      final data = response['data'] as Map<String, dynamic>;
      return AssignmentModel.fromJson(data);
    } catch (e) {
      debugPrint('AssignmentRemoteDataSource: getAssignment error - $e');
      rethrow;
    }
  }

  /// Start work on assignment
  Future<AssignmentModel> startWork(int issueId) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.startWork(issueId),
      );

      final data = response['data'] as Map<String, dynamic>;
      return AssignmentModel.fromJson(data);
    } catch (e) {
      debugPrint('AssignmentRemoteDataSource: startWork error - $e');
      rethrow;
    }
  }

  /// Hold work on assignment
  Future<AssignmentModel> holdWork(int issueId, {String? reason}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.holdWork(issueId),
        data: reason != null ? {'reason': reason} : null,
      );

      final data = response['data'] as Map<String, dynamic>;
      return AssignmentModel.fromJson(data);
    } catch (e) {
      debugPrint('AssignmentRemoteDataSource: holdWork error - $e');
      rethrow;
    }
  }

  /// Resume work on assignment
  Future<AssignmentModel> resumeWork(int issueId) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.resumeWork(issueId),
      );

      final data = response['data'] as Map<String, dynamic>;
      return AssignmentModel.fromJson(data);
    } catch (e) {
      debugPrint('AssignmentRemoteDataSource: resumeWork error - $e');
      rethrow;
    }
  }

  /// Finish work on assignment with proofs and consumables
  Future<AssignmentModel> finishWork(
    int issueId, {
    String? notes,
    List<File>? proofs,
    List<ConsumableUsage>? consumables,
  }) async {
    try {
      final formData = <String, dynamic>{};

      if (notes != null && notes.isNotEmpty) {
        formData['notes'] = notes;
      }

      // Add proofs as multipart files
      if (proofs != null && proofs.isNotEmpty) {
        for (var i = 0; i < proofs.length; i++) {
          formData['proofs[$i]'] = await MultipartFile.fromFile(
            proofs[i].path,
            filename: proofs[i].path.split('/').last,
          );
        }
      }

      // Add consumables
      if (consumables != null && consumables.isNotEmpty) {
        for (var i = 0; i < consumables.length; i++) {
          formData['consumables[$i][consumable_id]'] =
              consumables[i].consumableId;
          formData['consumables[$i][quantity]'] = consumables[i].quantity;
          if (consumables[i].notes != null) {
            formData['consumables[$i][notes]'] = consumables[i].notes;
          }
        }
      }

      final response = await _apiClient.postMultipart(
        ApiConstants.finishWork(issueId),
        data: formData,
      );

      final data = response['data'] as Map<String, dynamic>;
      return AssignmentModel.fromJson(data);
    } catch (e) {
      debugPrint('AssignmentRemoteDataSource: finishWork error - $e');
      rethrow;
    }
  }
}

/// Consumable usage for finishing work
class ConsumableUsage {
  final int? consumableId;
  final String? customName;
  final int quantity;
  final String? notes;

  const ConsumableUsage({
    this.consumableId,
    this.customName,
    required this.quantity,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (consumableId != null) 'consumable_id': consumableId,
      if (customName != null) 'custom_name': customName,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
    };
  }
}

/// Provider for AssignmentRemoteDataSource
final assignmentRemoteDataSourceProvider =
    Provider<AssignmentRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AssignmentRemoteDataSource(apiClient);
});
