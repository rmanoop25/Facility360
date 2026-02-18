import 'package:easy_localization/easy_localization.dart';

import '../../domain/enums/issue_status.dart';
import '../../domain/enums/issue_priority.dart';
import '../../domain/enums/sync_status.dart';
import 'category_model.dart';
import 'tenant_model.dart';
import 'assignment_model.dart';
import 'media_model.dart';
import 'timeline_model.dart';

/// Issue model matching Laravel backend Issue entity
class IssueModel {
  final int id;
  final int? tenantId;
  final String title;
  final String? description;
  final IssueStatus status;
  final IssuePriority priority;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool proofRequired;
  final String? cancelledReason;
  final int? cancelledBy;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TenantModel? tenant;
  final List<CategoryModel> categories;
  final List<AssignmentModel> assignments;
  final List<MediaModel> media;
  final List<TimelineModel> timeline;
  final String? localId;
  final SyncStatus syncStatus;

  const IssueModel({
    required this.id,
    this.tenantId,
    required this.title,
    this.description,
    this.status = IssueStatus.pending,
    this.priority = IssuePriority.medium,
    this.latitude,
    this.longitude,
    this.address,
    this.proofRequired = false,
    this.cancelledReason,
    this.cancelledBy,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
    this.tenant,
    this.categories = const [],
    this.assignments = const [],
    this.media = const [],
    this.timeline = const [],
    this.localId,
    this.syncStatus = SyncStatus.synced,
  });

  /// Check if issue has location
  bool get hasLocation => latitude != null && longitude != null;

  /// Get primary category (first one)
  CategoryModel? get primaryCategory =>
      categories.isNotEmpty ? categories.first : null;

  /// Get category names as comma-separated string
  String getCategoryNames(String locale) =>
      categories.map((c) => c.localizedName(locale)).join(', ');

  /// Get current (latest active) assignment
  AssignmentModel? get currentAssignment {
    if (assignments.isEmpty) return null;
    try {
      return assignments.firstWhere((a) => a.status.isActive);
    } catch (_) {
      return assignments.first;
    }
  }

  /// Check if issue has active assignment
  bool get hasActiveAssignment => assignments.any((a) => a.status.isActive);

  /// Get media photos only
  List<MediaModel> get photos => media.where((m) => m.isPhoto).toList();

  /// Get media videos only
  List<MediaModel> get videos => media.where((m) => m.isVideo).toList();

  /// Check if issue has media
  bool get hasMedia => media.isNotEmpty;

  /// Get tenant unit number with fallback
  String get tenantUnit => tenant?.unitNumber ?? 'N/A';

  /// Get tenant building name with fallback
  String get tenantBuilding => tenant?.buildingName ?? 'N/A';

  /// Get tenant full address
  String get tenantAddress => tenant?.fullAddress ?? 'N/A';

  /// Get tenant name (from tenant's user if available)
  String get tenantName => tenant?.userName ?? 'Tenant';

  /// Get tenant phone (from tenant's user if available)
  String? get tenantPhone => tenant?.userPhone;

  /// Check if this is a locally created issue (not yet synced)
  bool get isLocalOnly => localId != null && id < 0;

  /// Check if sync is pending
  bool get needsSync => syncStatus.needsSync;

  /// Get relative time since creation (localized)
  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inDays > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${diff.inDays} ${'time.day'.tr()}'});
    } else if (diff.inHours > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${diff.inHours} ${'time.hour'.tr()}'});
    } else if (diff.inMinutes > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${diff.inMinutes} ${'time.minute'.tr()}'});
    }
    return 'common.just_now'.tr();
  }

  IssueModel copyWith({
    int? id,
    int? tenantId,
    String? title,
    String? description,
    IssueStatus? status,
    IssuePriority? priority,
    double? latitude,
    double? longitude,
    String? address,
    bool? proofRequired,
    String? cancelledReason,
    int? cancelledBy,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    TenantModel? tenant,
    List<CategoryModel>? categories,
    List<AssignmentModel>? assignments,
    List<MediaModel>? media,
    List<TimelineModel>? timeline,
    String? localId,
    SyncStatus? syncStatus,
  }) {
    return IssueModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      proofRequired: proofRequired ?? this.proofRequired,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tenant: tenant ?? this.tenant,
      categories: categories ?? this.categories,
      assignments: assignments ?? this.assignments,
      media: media ?? this.media,
      timeline: timeline ?? this.timeline,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    // Handle status - can be string or object with 'value' field
    String? statusValue;
    if (json['status'] is String) {
      statusValue = json['status'] as String?;
    } else if (json['status'] is Map) {
      statusValue = (json['status'] as Map)['value'] as String?;
    }

    // Handle priority - can be string or object with 'value' field
    String? priorityValue;
    if (json['priority'] is String) {
      priorityValue = json['priority'] as String?;
    } else if (json['priority'] is Map) {
      priorityValue = (json['priority'] as Map)['value'] as String?;
    }

    // Handle location - can be nested in 'location' object or at root level
    double? latitude;
    double? longitude;
    String? address;
    if (json['location'] is Map) {
      final location = json['location'] as Map;
      latitude = _parseDouble(location['latitude']);
      longitude = _parseDouble(location['longitude']);
      address = _parseString(location['address']);
    } else {
      latitude = _parseDouble(json['latitude']);
      longitude = _parseDouble(json['longitude']);
      address = _parseString(json['address']);
    }

    // Handle assignments - parse full assignments list if available
    // Skip current_assignment from list API as it may be incomplete
    List<AssignmentModel> assignments = [];
    if (json['assignments'] != null && json['assignments'] is List) {
      assignments = (json['assignments'] as List<dynamic>)
          .map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['current_assignment'] != null && json['current_assignment'] is Map) {
      // Parse current_assignment if it has at least an id
      // AssignmentModel.fromJson handles missing parent IDs with defaults
      final assignment = json['current_assignment'] as Map<String, dynamic>;
      if (assignment['id'] != null) {
        assignments = [AssignmentModel.fromJson(assignment)];
      }
    }

    return IssueModel(
      id: _parseInt(json['id']) ?? 0,
      tenantId: _parseInt(json['tenant_id']),
      title: _parseString(json['title']) ?? 'Untitled',
      description: _parseString(json['description']),
      status: IssueStatus.fromValue(statusValue) ?? IssueStatus.pending,
      priority: IssuePriority.fromValue(priorityValue) ?? IssuePriority.medium,
      latitude: latitude,
      longitude: longitude,
      address: address,
      proofRequired: json['proof_required'] as bool? ?? false,
      cancelledReason: _parseString(json['cancelled_reason']),
      cancelledBy: _parseInt(json['cancelled_by']),
      cancelledAt: json['cancelled_at'] != null && json['cancelled_at'] is String
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      tenant: json['tenant'] != null && json['tenant'] is Map<String, dynamic>
          ? TenantModel.fromJson(json['tenant'] as Map<String, dynamic>)
          : null,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      assignments: assignments,
      media: (json['media'] as List<dynamic>?)
              ?.map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) => TimelineModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      localId: _parseString(json['local_id']),
      syncStatus: SyncStatus.fromValue(_parseString(json['sync_status'])) ??
          SyncStatus.synced,
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

  /// Helper to safely parse string from dynamic value
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'proof_required': proofRequired,
      'cancelled_reason': cancelledReason,
      'cancelled_by': cancelledBy,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'tenant': tenant?.toJson(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'assignments': assignments.map((e) => e.toJson()).toList(),
      'media': media.map((e) => e.toJson()).toList(),
      'timeline': timeline.map((e) => e.toJson()).toList(),
      'local_id': localId,
      'sync_status': syncStatus.value,
    };
  }
}
