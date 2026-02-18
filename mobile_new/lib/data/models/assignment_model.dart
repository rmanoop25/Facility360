import 'package:intl/intl.dart';

import '../../domain/enums/assignment_status.dart';
import '../../domain/enums/issue_status.dart';
import '../../domain/enums/sync_status.dart';
import 'category_model.dart';
import 'service_provider_model.dart';
import 'time_slot_model.dart';
import 'proof_model.dart';
import 'consumable_model.dart';
import 'media_model.dart';
import 'work_type_model.dart';
import 'time_extension_request_model.dart';

/// Assignment model matching Laravel backend IssueAssignment entity
class AssignmentModel {
  final int id;
  final int issueId;
  final int serviceProviderId;
  final int categoryId;
  final int? timeSlotId;
  final List<int> timeSlotIds; // NEW: Multi-slot support
  final DateTime? scheduledDate;
  final DateTime? scheduledEndDate; // NEW: End date for multi-day assignments
  final bool isMultiDay; // NEW: Multi-day flag
  final int spanDays; // NEW: Number of days spanned
  final AssignmentStatus status;
  final bool proofRequired;
  final DateTime? startedAt;
  final DateTime? heldAt;
  final DateTime? resumedAt;
  final DateTime? finishedAt;
  final DateTime? completedAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ServiceProviderModel? serviceProvider;
  final CategoryModel? category;
  final TimeSlotModel? timeSlot;
  final List<TimeSlotModel> timeSlots; // NEW: Multi-slot collection
  final List<ConsumableUsageModel> consumables;
  final List<ProofModel> proofs;
  final String? localId;
  final SyncStatus syncStatus;
  final String? issueTitle;
  final String? issueDescription;
  final String? tenantUnit;
  final String? tenantBuilding;
  final double? latitude;
  final double? longitude;
  final List<MediaModel> issueMedia;
  final IssueStatus? issueStatus;
  final int siblingAssignmentsCount;
  final List<SiblingAssignmentInfo> siblingAssignments;
  // Work Type fields
  final int? workTypeId;
  final WorkTypeModel? workType;
  final int? allocatedDurationMinutes;
  final bool isCustomDuration;
  // Time Extension fields
  final List<TimeExtensionRequestModel> extensionRequests;
  final int approvedExtensionMinutes;
  final bool hasPendingExtension;
  // Time Range fields
  final String? assignedStartTime; // "HH:mm:ss" format from API
  final String? assignedEndTime;   // "HH:mm:ss" format from API

  const AssignmentModel({
    required this.id,
    required this.issueId,
    required this.serviceProviderId,
    required this.categoryId,
    this.timeSlotId,
    this.timeSlotIds = const [],
    this.scheduledDate,
    this.scheduledEndDate,
    this.isMultiDay = false,
    this.spanDays = 1,
    this.status = AssignmentStatus.assigned,
    this.proofRequired = false,
    this.startedAt,
    this.heldAt,
    this.resumedAt,
    this.finishedAt,
    this.completedAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.serviceProvider,
    this.category,
    this.timeSlot,
    this.timeSlots = const [],
    this.consumables = const [],
    this.proofs = const [],
    this.localId,
    this.syncStatus = SyncStatus.synced,
    this.issueTitle,
    this.issueDescription,
    this.tenantUnit,
    this.tenantBuilding,
    this.latitude,
    this.longitude,
    this.issueMedia = const [],
    this.issueStatus,
    this.siblingAssignmentsCount = 0,
    this.siblingAssignments = const [],
    this.workTypeId,
    this.workType,
    this.allocatedDurationMinutes,
    this.isCustomDuration = false,
    this.extensionRequests = const [],
    this.approvedExtensionMinutes = 0,
    this.hasPendingExtension = false,
    this.assignedStartTime,
    this.assignedEndTime,
  });

  /// Check if work can be started
  bool get canStart => status.canStart;

  /// Check if work can be put on hold
  bool get canHold => status.canHold;

  /// Check if work can be resumed
  bool get canResume => status.canResume;

  /// Check if work can be finished
  bool get canFinish => status.canFinish;

  /// Check if assignment is active
  bool get isActive => status.isActive;

  /// Get work duration if started and finished
  Duration? get workDuration {
    if (startedAt == null) return null;
    final endTime = finishedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  /// Get work duration as formatted string
  String get workDurationFormatted {
    final duration = workDuration;
    if (duration == null) return '--:--:--';

    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Get service provider name
  String? get serviceProviderName => serviceProvider?.displayName;

  /// Get category name
  String getCategoryName(String locale) =>
      category?.localizedName(locale) ?? 'General';

  /// Get time slot display
  String? get timeSlotDisplay => timeSlot?.formattedRange;

  /// Get assigned time range (e.g., "1:00 PM - 2:00 PM")
  /// Falls back to time slot range if specific times not assigned
  String? get assignedTimeRange {
    if (assignedStartTime != null && assignedEndTime != null) {
      final startTime = _formatTime(assignedStartTime!);
      final endTime = _formatTime(assignedEndTime!);
      return '$startTime - $endTime';
    }
    // Fallback to slot range for backward compatibility
    return timeSlotDisplay;
  }

  /// Format time from "HH:mm:ss" or "HH:mm" to "h:mm AM/PM"
  String _formatTime(String time24) {
    final parts = time24.split(':');
    if (parts.isEmpty) return time24;

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Get scheduled date formatted (e.g., "Jan 13, 2026")
  String? get scheduledDateFormatted {
    if (scheduledDate == null) return null;
    return DateFormat('MMM d, y').format(scheduledDate!);
  }

  /// Returns formatted date range for multi-day assignments
  String? get scheduledDateRange {
    if (scheduledDate == null) return null;

    if (isMultiDay && scheduledEndDate != null) {
      final start = DateFormat('MMM d').format(scheduledDate!);
      final end = DateFormat('MMM d, y').format(scheduledEndDate!);
      return '$start - $end';
    }

    return DateFormat('MMM d, y').format(scheduledDate!);
  }

  /// Returns count of time slots
  int get timeSlotCount => timeSlots.length;

  /// Returns true if has multiple slots
  bool get hasMultipleSlots => timeSlotIds.length > 1;

  /// Check if scheduled for today
  bool get isScheduledToday {
    if (scheduledDate == null) return false;
    final today = DateTime.now();
    return scheduledDate!.year == today.year &&
        scheduledDate!.month == today.month &&
        scheduledDate!.day == today.day;
  }

  /// Get completion proofs
  List<ProofModel> get completionProofs =>
      proofs.where((p) => p.isCompletionProof).toList();

  /// Get during work proofs
  List<ProofModel> get duringWorkProofs =>
      proofs.where((p) => p.isDuringWorkProof).toList();

  /// Get photo proofs only
  List<ProofModel> get photoProofs => proofs.where((p) => p.isPhoto).toList();

  /// Check if has required completion proofs
  bool get hasRequiredProofs =>
      !proofRequired || completionProofs.isNotEmpty;

  /// Get total consumables count
  int get totalConsumablesCount =>
      consumables.fold(0, (sum, c) => sum + c.quantity);

  /// Check if has location
  bool get hasLocation => latitude != null && longitude != null;

  /// Get tenant address
  String get tenantAddress {
    final parts = <String>[];
    if (tenantUnit != null && tenantUnit!.isNotEmpty) {
      parts.add('Unit $tenantUnit');
    }
    if (tenantBuilding != null && tenantBuilding!.isNotEmpty) {
      parts.add(tenantBuilding!);
    }
    return parts.isNotEmpty ? parts.join(', ') : 'N/A';
  }

  /// Check if needs sync
  bool get needsSync => syncStatus.needsSync;

  // Time tracking calculations
  /// Get total allowed duration including approved extensions
  int? get totalAllowedMinutes {
    if (allocatedDurationMinutes == null) return null;
    return allocatedDurationMinutes! + approvedExtensionMinutes;
  }

  /// Get actual duration in minutes
  int? get actualDurationMinutes {
    final duration = workDuration;
    if (duration == null) return null;
    return duration.inMinutes;
  }

  /// Get overtime minutes (negative = finished early, positive = overtime)
  int? get overtimeMinutes {
    final actual = actualDurationMinutes;
    final allowed = totalAllowedMinutes;
    if (actual == null || allowed == null) return null;
    return actual - allowed;
  }

  /// Check if can request time extension
  bool get canRequestExtension {
    return status == AssignmentStatus.inProgress && !hasPendingExtension;
  }

  AssignmentModel copyWith({
    int? id,
    int? issueId,
    int? serviceProviderId,
    int? categoryId,
    int? timeSlotId,
    List<int>? timeSlotIds,
    DateTime? scheduledDate,
    DateTime? scheduledEndDate,
    bool? isMultiDay,
    int? spanDays,
    AssignmentStatus? status,
    bool? proofRequired,
    DateTime? startedAt,
    DateTime? heldAt,
    DateTime? resumedAt,
    DateTime? finishedAt,
    DateTime? completedAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    ServiceProviderModel? serviceProvider,
    CategoryModel? category,
    TimeSlotModel? timeSlot,
    List<TimeSlotModel>? timeSlots,
    List<ConsumableUsageModel>? consumables,
    List<ProofModel>? proofs,
    String? localId,
    SyncStatus? syncStatus,
    String? issueTitle,
    String? issueDescription,
    String? tenantUnit,
    String? tenantBuilding,
    double? latitude,
    double? longitude,
    List<MediaModel>? issueMedia,
    IssueStatus? issueStatus,
    int? siblingAssignmentsCount,
    List<SiblingAssignmentInfo>? siblingAssignments,
    int? workTypeId,
    WorkTypeModel? workType,
    int? allocatedDurationMinutes,
    bool? isCustomDuration,
    List<TimeExtensionRequestModel>? extensionRequests,
    int? approvedExtensionMinutes,
    bool? hasPendingExtension,
    String? assignedStartTime,
    String? assignedEndTime,
  }) {
    return AssignmentModel(
      id: id ?? this.id,
      issueId: issueId ?? this.issueId,
      serviceProviderId: serviceProviderId ?? this.serviceProviderId,
      categoryId: categoryId ?? this.categoryId,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      timeSlotIds: timeSlotIds ?? this.timeSlotIds,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledEndDate: scheduledEndDate ?? this.scheduledEndDate,
      isMultiDay: isMultiDay ?? this.isMultiDay,
      spanDays: spanDays ?? this.spanDays,
      status: status ?? this.status,
      proofRequired: proofRequired ?? this.proofRequired,
      startedAt: startedAt ?? this.startedAt,
      heldAt: heldAt ?? this.heldAt,
      resumedAt: resumedAt ?? this.resumedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      category: category ?? this.category,
      timeSlot: timeSlot ?? this.timeSlot,
      timeSlots: timeSlots ?? this.timeSlots,
      consumables: consumables ?? this.consumables,
      proofs: proofs ?? this.proofs,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      issueTitle: issueTitle ?? this.issueTitle,
      issueDescription: issueDescription ?? this.issueDescription,
      tenantUnit: tenantUnit ?? this.tenantUnit,
      tenantBuilding: tenantBuilding ?? this.tenantBuilding,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      issueMedia: issueMedia ?? this.issueMedia,
      issueStatus: issueStatus ?? this.issueStatus,
      siblingAssignmentsCount: siblingAssignmentsCount ?? this.siblingAssignmentsCount,
      siblingAssignments: siblingAssignments ?? this.siblingAssignments,
      workTypeId: workTypeId ?? this.workTypeId,
      workType: workType ?? this.workType,
      allocatedDurationMinutes: allocatedDurationMinutes ?? this.allocatedDurationMinutes,
      isCustomDuration: isCustomDuration ?? this.isCustomDuration,
      extensionRequests: extensionRequests ?? this.extensionRequests,
      approvedExtensionMinutes: approvedExtensionMinutes ?? this.approvedExtensionMinutes,
      hasPendingExtension: hasPendingExtension ?? this.hasPendingExtension,
      assignedStartTime: assignedStartTime ?? this.assignedStartTime,
      assignedEndTime: assignedEndTime ?? this.assignedEndTime,
    );
  }

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    // Handle status - can be string or object with 'value' field
    String? statusValue;
    if (json['status'] is String) {
      statusValue = json['status'] as String?;
    } else if (json['status'] is Map) {
      statusValue = (json['status'] as Map)['value'] as String?;
    }

    // Extract nested issue data from API response
    final issue = json['issue'] as Map<String, dynamic>?;
    final location = issue?['location'] as Map<String, dynamic>?;
    final tenant = issue?['tenant'] as Map<String, dynamic>?;

    // Parse issue media from nested issue object
    final issueMediaList = (issue?['media'] as List<dynamic>?)
            ?.map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Parse issue status from nested issue object
    String? issueStatusValue;
    final issueStatusData = issue?['status'];
    if (issueStatusData is String) {
      issueStatusValue = issueStatusData;
    } else if (issueStatusData is Map) {
      issueStatusValue = issueStatusData['value'] as String?;
    }

    // Parse time_slot_ids array (NEW: Multi-slot support)
    final timeSlotIdsList = <int>[];
    if (json['time_slot_ids'] is List) {
      for (final item in json['time_slot_ids'] as List) {
        final parsed = _parseInt(item);
        if (parsed != null) timeSlotIdsList.add(parsed);
      }
    }

    // Parse time_slots array (NEW: Multi-slot collection)
    final timeSlotsList = <TimeSlotModel>[];
    if (json['time_slots'] is List) {
      for (final item in json['time_slots'] as List) {
        if (item is Map<String, dynamic>) {
          timeSlotsList.add(TimeSlotModel.fromJson(item));
        }
      }
    }

    // Parse scheduled_end_date (NEW: Multi-day support)
    DateTime? scheduledEndDate;
    if (json['scheduled_end_date'] != null && json['scheduled_end_date'] is String) {
      scheduledEndDate = DateTime.tryParse(json['scheduled_end_date'] as String);
    }

    // Parse multi-day flags (NEW)
    final isMultiDay = json['is_multi_day'] == true;
    final spanDays = _parseInt(json['span_days']) ?? 1;

    return AssignmentModel(
      id: _parseInt(json['id']) ?? 0,
      // Use defaults for nested contexts where parent IDs may be null
      issueId: _parseInt(json['issue_id']) ?? 0,
      serviceProviderId: _parseInt(json['service_provider_id']) ?? 0,
      categoryId: _parseInt(json['category_id']) ?? 0,
      timeSlotId: _parseInt(json['time_slot_id']),
      timeSlotIds: timeSlotIdsList,
      scheduledDate: json['scheduled_date'] != null && json['scheduled_date'] is String
          ? DateTime.parse(json['scheduled_date'] as String)
          : null,
      scheduledEndDate: scheduledEndDate,
      isMultiDay: isMultiDay,
      spanDays: spanDays,
      status: AssignmentStatus.fromValue(statusValue) ??
          AssignmentStatus.assigned,
      proofRequired: json['proof_required'] as bool? ?? false,
      startedAt: json['started_at'] != null && json['started_at'] is String
          ? DateTime.parse(json['started_at'] as String)
          : null,
      heldAt: json['held_at'] != null && json['held_at'] is String
          ? DateTime.parse(json['held_at'] as String)
          : null,
      resumedAt: json['resumed_at'] != null && json['resumed_at'] is String
          ? DateTime.parse(json['resumed_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null && json['finished_at'] is String
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      completedAt: json['completed_at'] != null && json['completed_at'] is String
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      serviceProvider: json['service_provider'] != null
          ? ServiceProviderModel.fromJson(
              json['service_provider'] as Map<String, dynamic>)
          : null,
      category: json['category'] != null
          ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      timeSlot: json['time_slot'] != null
          ? TimeSlotModel.fromJson(json['time_slot'] as Map<String, dynamic>)
          : null,
      timeSlots: timeSlotsList,
      consumables: (json['consumables'] as List<dynamic>?)
              ?.map((e) =>
                  ConsumableUsageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      proofs: (json['proofs'] as List<dynamic>?)
              ?.map((e) => ProofModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      localId: json['local_id'] as String?,
      syncStatus: SyncStatus.fromValue(json['sync_status'] as String?) ??
          SyncStatus.synced,
      // Extract issue data from nested 'issue' object, fallback to flat fields for backwards compatibility
      issueTitle: issue?['title'] as String? ?? json['issue_title'] as String?,
      issueDescription: issue?['description'] as String? ?? json['issue_description'] as String?,
      tenantUnit: tenant?['unit_number'] as String? ?? json['tenant_unit'] as String?,
      tenantBuilding: tenant?['building_name'] as String? ?? json['tenant_building'] as String?,
      latitude: _parseDouble(location?['latitude']) ?? _parseDouble(json['latitude']),
      longitude: _parseDouble(location?['longitude']) ?? _parseDouble(json['longitude']),
      issueMedia: issueMediaList,
      issueStatus: IssueStatus.fromValue(issueStatusValue),
      siblingAssignmentsCount: json['sibling_assignments_count'] as int? ?? 0,
      siblingAssignments: (json['sibling_assignments'] as List<dynamic>?)
              ?.map((e) => SiblingAssignmentInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      // Work Type fields
      workTypeId: _parseInt(json['work_type_id']),
      workType: json['work_type'] != null
          ? WorkTypeModel.fromJson(json['work_type'] as Map<String, dynamic>)
          : null,
      allocatedDurationMinutes: _parseInt(json['allocated_duration_minutes']),
      isCustomDuration: json['is_custom_duration'] as bool? ?? false,
      // Time Extension fields
      extensionRequests: (json['extension_requests'] as List<dynamic>?)
              ?.map((e) => TimeExtensionRequestModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      approvedExtensionMinutes: _parseInt(json['approved_extension_minutes']) ?? 0,
      hasPendingExtension: json['has_pending_extension'] as bool? ?? false,
      // Time Range fields
      assignedStartTime: json['assigned_start_time']?.toString(),
      assignedEndTime: json['assigned_end_time']?.toString(),
    );
  }

  /// Helper to safely parse int from dynamic value (handles both int and String)
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  /// Helper to safely parse double from dynamic value (handles both num and String)
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is num) return value.toDouble();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'service_provider_id': serviceProviderId,
      'category_id': categoryId,
      'time_slot_id': timeSlotId,
      'time_slot_ids': timeSlotIds,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'scheduled_end_date': scheduledEndDate?.toIso8601String(),
      'is_multi_day': isMultiDay,
      'span_days': spanDays,
      'status': status.value,
      'proof_required': proofRequired,
      'started_at': startedAt?.toIso8601String(),
      'held_at': heldAt?.toIso8601String(),
      'resumed_at': resumedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'service_provider': serviceProvider?.toJson(),
      'category': category?.toJson(),
      'time_slot': timeSlot?.toJson(),
      'time_slots': timeSlots.map((s) => s.toJson()).toList(),
      'consumables': consumables.map((e) => e.toJson()).toList(),
      'proofs': proofs.map((e) => e.toJson()).toList(),
      'local_id': localId,
      'sync_status': syncStatus.value,
      'issue_title': issueTitle,
      'issue_description': issueDescription,
      'tenant_unit': tenantUnit,
      'tenant_building': tenantBuilding,
      'latitude': latitude,
      'longitude': longitude,
      'issue_media': issueMedia.map((e) => e.toJson()).toList(),
      'issue_status': issueStatus?.value,
      'sibling_assignments_count': siblingAssignmentsCount,
      'sibling_assignments': siblingAssignments.map((e) => e.toJson()).toList(),
      'work_type_id': workTypeId,
      'work_type': workType?.toJson(),
      'allocated_duration_minutes': allocatedDurationMinutes,
      'is_custom_duration': isCustomDuration,
      'extension_requests': extensionRequests.map((e) => e.toJson()).toList(),
      'approved_extension_minutes': approvedExtensionMinutes,
      'has_pending_extension': hasPendingExtension,
      'assigned_start_time': assignedStartTime,
      'assigned_end_time': assignedEndTime,
    };
  }
}

/// Brief info about a sibling assignment (other assignment on the same issue)
class SiblingAssignmentInfo {
  final int id;
  final String? serviceProviderName;
  final String? categoryName;
  final int? categoryId;
  final String statusValue;
  final String statusLabel;
  final String? scheduledDate;

  const SiblingAssignmentInfo({
    required this.id,
    this.serviceProviderName,
    this.categoryName,
    this.categoryId,
    required this.statusValue,
    required this.statusLabel,
    this.scheduledDate,
  });

  factory SiblingAssignmentInfo.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final status = json['status'] as Map<String, dynamic>?;

    return SiblingAssignmentInfo(
      id: json['id'] as int? ?? 0,
      serviceProviderName: json['service_provider_name'] as String?,
      categoryName: category?['name'] as String?,
      categoryId: category?['id'] as int?,
      statusValue: status?['value'] as String? ?? 'assigned',
      statusLabel: status?['label'] as String? ?? 'Assigned',
      scheduledDate: json['scheduled_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_provider_name': serviceProviderName,
      'category': categoryId != null
          ? {'id': categoryId, 'name': categoryName}
          : null,
      'status': {'value': statusValue, 'label': statusLabel},
      'scheduled_date': scheduledDate,
    };
  }
}
