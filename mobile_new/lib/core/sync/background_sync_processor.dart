import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_constants.dart';
import 'sync_operation.dart';

/// Background sync processor that works in isolates without Riverpod
///
/// This class handles sync operations when the app is in background
/// using WorkManager. It creates its own API client and accesses
/// Hive storage directly without depending on Riverpod providers.
class BackgroundSyncProcessor {
  late final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _authToken;

  BackgroundSyncProcessor()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  /// Initialize the processor
  Future<bool> init() async {
    try {
      // Get auth token from secure storage
      _authToken = await _storage.read(key: ApiConstants.accessTokenKey);
      if (_authToken == null) {
        debugPrint('BackgroundSyncProcessor: No auth token found');
        return false;
      }

      // Check token expiry
      final expiryString =
          await _storage.read(key: ApiConstants.tokenExpiryKey);
      if (expiryString != null) {
        final expiry = DateTime.tryParse(expiryString);
        if (expiry != null &&
            DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)))) {
          debugPrint('BackgroundSyncProcessor: Token expired');
          return false;
        }
      }

      // Create Dio client with auth token
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          },
        ),
      );

      debugPrint('BackgroundSyncProcessor: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('BackgroundSyncProcessor: Init failed - $e');
      return false;
    }
  }

  /// Process all pending sync operations
  Future<int> processQueue(Box<SyncOperation> box) async {
    final operations = box.values.where((op) => op.shouldRetry).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (operations.isEmpty) {
      debugPrint('BackgroundSyncProcessor: No pending operations');
      return 0;
    }

    debugPrint('BackgroundSyncProcessor: Processing ${operations.length} operations');

    int successCount = 0;

    for (final operation in operations) {
      try {
        // Wait for backoff delay if needed
        if (operation.retryCount > 0) {
          final delay = operation.backoffDelay;
          debugPrint('BackgroundSyncProcessor: Waiting ${delay.inSeconds}s before retry');
          await Future.delayed(delay);
        }

        await _processOperation(operation);
        await box.delete(operation.id);
        successCount++;
        debugPrint('BackgroundSyncProcessor: Synced ${operation.entityType}:${operation.localId}');
      } catch (e) {
        debugPrint('BackgroundSyncProcessor: Failed ${operation.entityType}:${operation.localId} - $e');
        operation.markAttempted(error: e.toString());
        await operation.save();

        if (!operation.shouldRetry) {
          debugPrint('BackgroundSyncProcessor: Max retries reached, removing');
          await box.delete(operation.id);
        }
      }
    }

    return successCount;
  }

  /// Process a single operation
  Future<void> _processOperation(SyncOperation operation) async {
    final data = jsonDecode(operation.dataJson) as Map<String, dynamic>;

    switch (operation.entity) {
      case SyncEntityType.issue:
        await _syncIssue(operation.type, data);
        break;
      case SyncEntityType.assignment:
        await _syncAssignment(operation.type, data);
        break;
      case SyncEntityType.category:
        await _syncCategory(operation.type, data);
        break;
      case SyncEntityType.consumable:
        await _syncConsumable(operation.type, data);
        break;
      case SyncEntityType.tenant:
        await _syncTenant(operation.type, data);
        break;
      case SyncEntityType.serviceProvider:
        await _syncServiceProvider(operation.type, data);
        break;
      case SyncEntityType.timeExtension:
        await _syncTimeExtension(data);
        break;
      case SyncEntityType.proof:
        // Proofs are handled as part of finishWork
        debugPrint('BackgroundSyncProcessor: Proof sync handled with assignment');
        break;
      case SyncEntityType.locationGeocode:
        // Geocoding requires location service - skip in background
        debugPrint('BackgroundSyncProcessor: Location geocode skipped in background');
        break;
    }
  }

  /// Sync issue operations
  Future<void> _syncIssue(SyncOperationType type, Map<String, dynamic> data) async {
    switch (type) {
      case SyncOperationType.create:
        await _dio.post(
          ApiConstants.issues,
          data: {
            'title': data['title'],
            'description': data['description'],
            'category_ids': data['category_ids'],
            'priority': data['priority'] ?? 'medium',
            if (data['latitude'] != null) 'latitude': data['latitude'],
            if (data['longitude'] != null) 'longitude': data['longitude'],
            if (data['address'] != null) 'address': data['address'],
          },
        );
        break;

      case SyncOperationType.update:
        // Issue updates not commonly used
        break;

      case SyncOperationType.delete:
        final serverId = data['server_id'] as int?;
        if (serverId != null) {
          await _dio.post(
            ApiConstants.cancelIssue(serverId),
            data: {
              if (data['reason'] != null) 'reason': data['reason'],
            },
          );
        }
        break;
    }
  }

  /// Sync assignment operations
  Future<void> _syncAssignment(SyncOperationType type, Map<String, dynamic> data) async {
    if (type != SyncOperationType.update) return;

    final issueId = data['issue_id'] as int;
    final action = data['action'] as String;

    switch (action) {
      case 'start':
        await _dio.post(ApiConstants.startWork(issueId));
        break;
      case 'hold':
        await _dio.post(ApiConstants.holdWork(issueId));
        break;
      case 'resume':
        await _dio.post(ApiConstants.resumeWork(issueId));
        break;
      case 'finish':
        final requestData = <String, dynamic>{};
        if (data['notes'] != null) {
          requestData['notes'] = data['notes'];
        }
        if (data['consumables'] != null) {
          requestData['consumables'] = data['consumables'];
        }
        await _dio.post(
          ApiConstants.finishWork(issueId),
          data: requestData,
        );
        break;
    }
  }

  /// Sync category operations (admin)
  Future<void> _syncCategory(SyncOperationType type, Map<String, dynamic> data) async {
    switch (type) {
      case SyncOperationType.create:
        await _dio.post(
          ApiConstants.adminCategories,
          data: {
            'name_en': data['name_en'],
            'name_ar': data['name_ar'],
            if (data['description_en'] != null) 'description_en': data['description_en'],
            if (data['description_ar'] != null) 'description_ar': data['description_ar'],
            if (data['icon'] != null) 'icon': data['icon'],
            if (data['color'] != null) 'color': data['color'],
            'sort_order': data['sort_order'] ?? 0,
            'is_active': data['is_active'] ?? true,
          },
        );
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        await _dio.put(
          ApiConstants.adminCategoryDetail(serverId),
          data: {
            if (data['name_en'] != null) 'name_en': data['name_en'],
            if (data['name_ar'] != null) 'name_ar': data['name_ar'],
            if (data['description_en'] != null) 'description_en': data['description_en'],
            if (data['description_ar'] != null) 'description_ar': data['description_ar'],
            if (data['icon'] != null) 'icon': data['icon'],
            if (data['color'] != null) 'color': data['color'],
            if (data['sort_order'] != null) 'sort_order': data['sort_order'],
            if (data['is_active'] != null) 'is_active': data['is_active'],
          },
        );
        break;

      case SyncOperationType.delete:
        final serverId = data['server_id'] as int;
        await _dio.delete(ApiConstants.adminCategoryDetail(serverId));
        break;
    }
  }

  /// Sync consumable operations (admin)
  Future<void> _syncConsumable(SyncOperationType type, Map<String, dynamic> data) async {
    switch (type) {
      case SyncOperationType.create:
        await _dio.post(
          ApiConstants.adminConsumables,
          data: {
            'name_en': data['name_en'],
            'name_ar': data['name_ar'],
            if (data['category_id'] != null) 'category_id': data['category_id'],
            'is_active': data['is_active'] ?? true,
          },
        );
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        await _dio.put(
          ApiConstants.adminConsumableDetail(serverId),
          data: {
            if (data['name_en'] != null) 'name_en': data['name_en'],
            if (data['name_ar'] != null) 'name_ar': data['name_ar'],
            if (data['category_id'] != null) 'category_id': data['category_id'],
            if (data['is_active'] != null) 'is_active': data['is_active'],
          },
        );
        break;

      case SyncOperationType.delete:
        final serverId = data['server_id'] as int;
        await _dio.delete(ApiConstants.adminConsumableDetail(serverId));
        break;
    }
  }

  /// Sync tenant operations (admin)
  Future<void> _syncTenant(SyncOperationType type, Map<String, dynamic> data) async {
    switch (type) {
      case SyncOperationType.create:
        // Tenant creation requires password - should not be queued
        debugPrint('BackgroundSyncProcessor: Tenant create requires online');
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        await _dio.put(
          ApiConstants.adminTenantDetail(serverId),
          data: {
            if (data['name'] != null) 'name': data['name'],
            if (data['email'] != null) 'email': data['email'],
            if (data['phone'] != null) 'phone': data['phone'],
            if (data['unit_number'] != null) 'unit_number': data['unit_number'],
            if (data['building_name'] != null) 'building_name': data['building_name'],
            if (data['floor'] != null) 'floor': data['floor'],
            if (data['is_active'] != null) 'is_active': data['is_active'],
          },
        );
        break;

      case SyncOperationType.delete:
        final serverId = data['server_id'] as int;
        // Soft delete via toggle
        await _dio.post(ApiConstants.adminTenantToggle(serverId));
        break;
    }
  }

  /// Sync service provider operations (admin)
  Future<void> _syncServiceProvider(SyncOperationType type, Map<String, dynamic> data) async {
    switch (type) {
      case SyncOperationType.create:
        // SP creation requires password - should not be queued
        debugPrint('BackgroundSyncProcessor: SP create requires online');
        break;

      case SyncOperationType.update:
        final serverId = data['server_id'] as int;
        // Check if this is an availability toggle
        if (data['toggle_availability'] == true) {
          // There's no specific toggle endpoint, use update
          await _dio.put(
            ApiConstants.adminServiceProviderDetail(serverId),
            data: {
              'is_available': data['is_available'],
            },
          );
        } else {
          await _dio.put(
            ApiConstants.adminServiceProviderDetail(serverId),
            data: {
              if (data['name'] != null) 'name': data['name'],
              if (data['email'] != null) 'email': data['email'],
              if (data['phone'] != null) 'phone': data['phone'],
              if (data['category_ids'] != null) 'category_ids': data['category_ids'],
              if (data['is_available'] != null) 'is_available': data['is_available'],
            },
          );
        }
        break;

      case SyncOperationType.delete:
        final serverId = data['server_id'] as int;
        // Soft delete via toggle
        await _dio.post(ApiConstants.adminServiceProviderToggle(serverId));
        break;
    }
  }

  /// Sync time extension operations (SP)
  Future<void> _syncTimeExtension(Map<String, dynamic> data) async {
    await _dio.post(
      ApiConstants.requestExtension,
      data: {
        'assignment_id': data['assignment_id'],
        'requested_minutes': data['requested_minutes'],
        'reason': data['reason'],
      },
    );
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
