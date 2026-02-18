import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../domain/enums/assignment_status.dart';
import '../../../domain/enums/sync_status.dart';
import '../../models/assignment_model.dart';
import '../../models/time_extension_request_model.dart';
import '../../models/time_slot_model.dart';

/// Hive model for storing assignments locally
/// Used for offline-first functionality
@HiveType(typeId: 2)
class AssignmentHiveModel extends HiveObject {
  /// Server ID
  @HiveField(0)
  int? serverId;

  /// Local UUID for tracking
  @HiveField(1)
  String localId;

  /// Issue ID this assignment belongs to
  @HiveField(2)
  int issueId;

  /// Service provider ID
  @HiveField(3)
  int serviceProviderId;

  /// Category ID
  @HiveField(4)
  int categoryId;

  /// Assignment status value string
  @HiveField(5)
  String status;

  /// Scheduled date
  @HiveField(6)
  DateTime? scheduledDate;

  /// Time slot ID
  @HiveField(7)
  int? timeSlotId;

  /// Work started timestamp
  @HiveField(8)
  DateTime? startedAt;

  /// Work held timestamp
  @HiveField(9)
  DateTime? heldAt;

  /// Work resumed timestamp
  @HiveField(10)
  DateTime? resumedAt;

  /// Work finished timestamp
  @HiveField(11)
  DateTime? finishedAt;

  /// Notes
  @HiveField(12)
  String? notes;

  /// Local proof file paths (before upload)
  @HiveField(13)
  List<String> localProofPaths;

  /// Consumables JSON (list of consumable usage)
  @HiveField(14)
  String? consumablesJson;

  /// Sync status value string
  @HiveField(15)
  String syncStatus;

  /// Created timestamp
  @HiveField(16)
  DateTime createdAt;

  /// Last synced timestamp
  @HiveField(17)
  DateTime? syncedAt;

  /// Full JSON data for complete model restoration
  @HiveField(18)
  String? fullDataJson;

  /// Issue title for display
  @HiveField(19)
  String? issueTitle;

  /// Tenant address for display
  @HiveField(20)
  String? tenantAddress;

  /// Assigned start time (HH:mm:ss format)
  @HiveField(21)
  String? assignedStartTime;

  /// Assigned end time (HH:mm:ss format)
  @HiveField(22)
  String? assignedEndTime;

  /// Time slot IDs array as JSON string (NEW: Multi-slot support)
  @HiveField(23)
  String? timeSlotIdsJson;

  /// Scheduled end date for multi-day assignments
  @HiveField(24)
  String? scheduledEndDate;

  /// Multi-day flag
  @HiveField(25)
  bool isMultiDay;

  /// Number of days spanned
  @HiveField(26)
  int spanDays;

  /// Time slots collection as JSON string
  @HiveField(27)
  String? timeSlotsJson;

  /// Work type ID (NEW: WorkType support)
  @HiveField(28)
  int? workTypeId;

  /// Allocated duration in minutes (NEW: WorkType support)
  @HiveField(29)
  int? allocatedDurationMinutes;

  /// Custom duration flag (NEW: WorkType support)
  @HiveField(30, defaultValue: false)
  bool isCustomDuration;

  /// Extension requests JSON (NEW: Time Extension support)
  @HiveField(31)
  String? extensionRequestsJson;

  /// Approved extension minutes (NEW: Time Extension support)
  @HiveField(32, defaultValue: 0)
  int approvedExtensionMinutes;

  /// Pending extension flag (NEW: Time Extension support)
  @HiveField(33, defaultValue: false)
  bool hasPendingExtension;

  AssignmentHiveModel({
    this.serverId,
    required this.localId,
    required this.issueId,
    required this.serviceProviderId,
    required this.categoryId,
    required this.status,
    this.scheduledDate,
    this.timeSlotId,
    this.startedAt,
    this.heldAt,
    this.resumedAt,
    this.finishedAt,
    this.notes,
    this.localProofPaths = const [],
    this.consumablesJson,
    required this.syncStatus,
    required this.createdAt,
    this.syncedAt,
    this.fullDataJson,
    this.issueTitle,
    this.tenantAddress,
    this.assignedStartTime,
    this.assignedEndTime,
    this.timeSlotIdsJson,
    this.scheduledEndDate,
    this.isMultiDay = false,
    this.spanDays = 1,
    this.timeSlotsJson,
    this.workTypeId,
    this.allocatedDurationMinutes,
    this.isCustomDuration = false,
    this.extensionRequestsJson,
    this.approvedExtensionMinutes = 0,
    this.hasPendingExtension = false,
  });

  /// Get the effective ID
  int get effectiveId => serverId ?? -localId.hashCode.abs();

  /// Get status as enum
  AssignmentStatus get statusEnum =>
      AssignmentStatus.fromValue(status) ?? AssignmentStatus.assigned;

  /// Get sync status as enum
  SyncStatus get syncStatusEnum =>
      SyncStatus.fromValue(syncStatus) ?? SyncStatus.pending;

  /// Check if needs sync
  bool get needsSync => syncStatusEnum.needsSync;

  /// Check if synced
  bool get isSynced => syncStatusEnum == SyncStatus.synced;

  /// Check if work can be started
  bool get canStart => statusEnum.canStart;

  /// Check if work can be finished
  bool get canFinish => statusEnum.canFinish;

  /// Get work duration
  Duration? get workDuration {
    if (startedAt == null) return null;
    final endTime = finishedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  /// Create from AssignmentModel
  factory AssignmentHiveModel.fromModel(AssignmentModel model,
      {String? localId}) {
    return AssignmentHiveModel(
      serverId: model.id > 0 ? model.id : null,
      localId: localId ?? model.localId ?? '',
      issueId: model.issueId,
      serviceProviderId: model.serviceProviderId,
      categoryId: model.categoryId,
      status: model.status.value,
      scheduledDate: model.scheduledDate,
      timeSlotId: model.timeSlotId,
      startedAt: model.startedAt,
      heldAt: model.heldAt,
      resumedAt: model.resumedAt,
      finishedAt: model.finishedAt,
      notes: model.notes,
      localProofPaths: [],
      consumablesJson: model.consumables.isNotEmpty
          ? jsonEncode(model.consumables.map((c) => c.toJson()).toList())
          : null,
      syncStatus: model.syncStatus.value,
      createdAt: model.createdAt ?? DateTime.now(),
      syncedAt: model.syncStatus == SyncStatus.synced ? DateTime.now() : null,
      fullDataJson: jsonEncode(model.toJson()),
      issueTitle: model.issueTitle,
      tenantAddress: model.tenantAddress,
      assignedStartTime: model.assignedStartTime,
      assignedEndTime: model.assignedEndTime,
      timeSlotIdsJson: jsonEncode(model.timeSlotIds),
      scheduledEndDate: model.scheduledEndDate?.toIso8601String(),
      isMultiDay: model.isMultiDay,
      spanDays: model.spanDays,
      timeSlotsJson: jsonEncode(model.timeSlots.map((s) => s.toJson()).toList()),
      workTypeId: model.workTypeId,
      allocatedDurationMinutes: model.allocatedDurationMinutes,
      isCustomDuration: model.isCustomDuration ?? false,
      extensionRequestsJson: model.extensionRequests.isNotEmpty
          ? jsonEncode(model.extensionRequests.map((e) => e.toJson()).toList())
          : null,
      approvedExtensionMinutes: model.approvedExtensionMinutes,
      hasPendingExtension: model.hasPendingExtension,
    );
  }

  /// Convert to AssignmentModel
  /// IMPORTANT: When fullDataJson exists, we still use local fields for
  /// any data that can be modified offline (status, timestamps, notes)
  AssignmentModel toModel() {
    // If we have full data, restore from it but overlay local changes
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return AssignmentModel.fromJson(json).copyWith(
          syncStatus: syncStatusEnum,
          localId: localId,
          // CRITICAL: Use local fields for offline-modifiable data
          status: statusEnum,
          notes: notes,
          startedAt: startedAt,
          heldAt: heldAt,
          resumedAt: resumedAt,
          finishedAt: finishedAt,
          // Preserve time range fields
          assignedStartTime: assignedStartTime,
          assignedEndTime: assignedEndTime,
          // Preserve multi-slot/multi-day fields
          timeSlotIds: _parseTimeSlotIds(),
          scheduledEndDate: scheduledEndDate != null ? DateTime.tryParse(scheduledEndDate!) : null,
          isMultiDay: isMultiDay,
          spanDays: spanDays,
          timeSlots: _parseTimeSlots(),
          // CRITICAL: Preserve local work type changes
          workTypeId: workTypeId,
          allocatedDurationMinutes: allocatedDurationMinutes,
          isCustomDuration: isCustomDuration,
          extensionRequests: _parseExtensionRequests(),
          approvedExtensionMinutes: approvedExtensionMinutes,
          hasPendingExtension: hasPendingExtension,
        );
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return AssignmentModel(
      id: effectiveId,
      issueId: issueId,
      serviceProviderId: serviceProviderId,
      categoryId: categoryId,
      status: statusEnum,
      scheduledDate: scheduledDate,
      timeSlotId: timeSlotId,
      timeSlotIds: _parseTimeSlotIds(),
      scheduledEndDate: scheduledEndDate != null ? DateTime.tryParse(scheduledEndDate!) : null,
      isMultiDay: isMultiDay,
      spanDays: spanDays,
      timeSlots: _parseTimeSlots(),
      startedAt: startedAt,
      heldAt: heldAt,
      resumedAt: resumedAt,
      finishedAt: finishedAt,
      notes: notes,
      createdAt: createdAt,
      localId: localId,
      syncStatus: syncStatusEnum,
      issueTitle: issueTitle,
      assignedStartTime: assignedStartTime,
      assignedEndTime: assignedEndTime,
      workTypeId: workTypeId,
      allocatedDurationMinutes: allocatedDurationMinutes,
      isCustomDuration: isCustomDuration,
      extensionRequests: _parseExtensionRequests(),
      approvedExtensionMinutes: approvedExtensionMinutes,
      hasPendingExtension: hasPendingExtension,
    );
  }

  /// Parse time slot IDs from JSON string
  List<int> _parseTimeSlotIds() {
    if (timeSlotIdsJson == null) return [];
    try {
      final decoded = jsonDecode(timeSlotIdsJson!) as List;
      return decoded.whereType<int>().toList();
    } catch (e) {
      return [];
    }
  }

  /// Parse time slots from JSON string
  List<TimeSlotModel> _parseTimeSlots() {
    if (timeSlotsJson == null) return [];
    try {
      final decoded = jsonDecode(timeSlotsJson!) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => TimeSlotModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Parse extension requests from JSON string
  List<TimeExtensionRequestModel> _parseExtensionRequests() {
    if (extensionRequestsJson == null) return [];
    try {
      final decoded = jsonDecode(extensionRequestsJson!) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => TimeExtensionRequestModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Mark as synced with server ID
  void markAsSynced(int serverId) {
    this.serverId = serverId;
    syncStatus = SyncStatus.synced.value;
    syncedAt = DateTime.now();
  }

  /// Mark as failed
  void markAsFailed() {
    syncStatus = SyncStatus.failed.value;
  }

  /// Mark as syncing
  void markAsSyncing() {
    syncStatus = SyncStatus.syncing.value;
  }

  /// Update status locally (for offline actions)
  void updateStatus(AssignmentStatus newStatus) {
    status = newStatus.value;
    syncStatus = SyncStatus.pending.value;

    switch (newStatus) {
      case AssignmentStatus.inProgress:
        if (startedAt == null) startedAt = DateTime.now();
        break;
      case AssignmentStatus.onHold:
        heldAt = DateTime.now();
        break;
      case AssignmentStatus.finished:
        finishedAt = DateTime.now();
        break;
      default:
        break;
    }
  }

  /// Update from server response
  void updateFromServer(AssignmentModel model) {
    serverId = model.id;
    status = model.status.value;
    scheduledDate = model.scheduledDate;
    timeSlotId = model.timeSlotId;
    startedAt = model.startedAt;
    heldAt = model.heldAt;
    resumedAt = model.resumedAt;
    finishedAt = model.finishedAt;
    notes = model.notes;
    syncStatus = SyncStatus.synced.value;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
    issueTitle = model.issueTitle;
    tenantAddress = model.tenantAddress;
    // Update work type fields
    workTypeId = model.workTypeId;
    allocatedDurationMinutes = model.allocatedDurationMinutes;
    isCustomDuration = model.isCustomDuration ?? false;
    extensionRequestsJson = model.extensionRequests.isNotEmpty
        ? jsonEncode(model.extensionRequests.map((e) => e.toJson()).toList())
        : null;
    approvedExtensionMinutes = model.approvedExtensionMinutes;
    hasPendingExtension = model.hasPendingExtension;
  }
}
