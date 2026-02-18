import '../../domain/enums/extension_status.dart';

class TimeExtensionRequestModel {
  final int id;
  final int assignmentId;
  final int requestedBy;
  final int requestedMinutes;
  final String reason;
  final ExtensionStatus status;
  final int? respondedBy;
  final String? adminNotes;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? requesterName;
  final String? responderName;

  const TimeExtensionRequestModel({
    required this.id,
    required this.assignmentId,
    required this.requestedBy,
    required this.requestedMinutes,
    required this.reason,
    required this.status,
    this.respondedBy,
    this.adminNotes,
    required this.requestedAt,
    this.respondedAt,
    this.requesterName,
    this.responderName,
  });

  bool get isPending => status == ExtensionStatus.pending;
  bool get isApproved => status == ExtensionStatus.approved;
  bool get isRejected => status == ExtensionStatus.rejected;

  factory TimeExtensionRequestModel.fromJson(Map<String, dynamic> json) {
    return TimeExtensionRequestModel(
      id: _parseInt(json['id']) ?? 0,
      assignmentId: _parseInt(json['assignment_id']) ?? 0,
      requestedBy: _parseInt(json['requested_by']) ?? 0,
      requestedMinutes: _parseInt(json['requested_minutes']) ?? 0,
      reason: json['reason']?.toString() ?? '',
      status: ExtensionStatus.fromString(json['status']?.toString() ?? 'pending'),
      respondedBy: _parseInt(json['responded_by']),
      adminNotes: json['admin_notes']?.toString(),
      requestedAt:
          DateTime.tryParse(json['requested_at'] ?? '') ?? DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'])
          : null,
      requesterName: json['requester_name']?.toString(),
      responderName: json['responder_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'requested_by': requestedBy,
      'requested_minutes': requestedMinutes,
      'reason': reason,
      'status': status.value,
      'responded_by': respondedBy,
      'admin_notes': adminNotes,
      'requested_at': requestedAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic v) =>
      v is int ? v : v is String ? int.tryParse(v) : null;

  TimeExtensionRequestModel copyWith({
    int? id,
    int? assignmentId,
    int? requestedBy,
    int? requestedMinutes,
    String? reason,
    ExtensionStatus? status,
    int? respondedBy,
    String? adminNotes,
    DateTime? requestedAt,
    DateTime? respondedAt,
    String? requesterName,
    String? responderName,
  }) {
    return TimeExtensionRequestModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedMinutes: requestedMinutes ?? this.requestedMinutes,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      respondedBy: respondedBy ?? this.respondedBy,
      adminNotes: adminNotes ?? this.adminNotes,
      requestedAt: requestedAt ?? this.requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      requesterName: requesterName ?? this.requesterName,
      responderName: responderName ?? this.responderName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TimeExtensionRequestModel &&
        other.id == id &&
        other.assignmentId == assignmentId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(id, assignmentId, status);
  }
}
