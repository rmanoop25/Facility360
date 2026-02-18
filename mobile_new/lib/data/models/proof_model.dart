import '../../domain/enums/proof_type.dart';
import 'media_model.dart';

/// Proof model matching Laravel backend Proof entity
class ProofModel {
  final int id;
  final int? issueAssignmentId;
  final ProofType type;
  final String filePath;
  final ProofStage stage;
  final DateTime? uploadedAt;
  final String? localPath;

  const ProofModel({
    required this.id,
    this.issueAssignmentId,
    required this.type,
    required this.filePath,
    required this.stage,
    this.uploadedAt,
    this.localPath,
  });

  /// Check if this is a photo
  bool get isPhoto => type == ProofType.photo;

  /// Check if this is a video
  bool get isVideo => type == ProofType.video;

  /// Check if this is audio
  bool get isAudio => type == ProofType.audio;

  /// Check if this is a during-work proof
  bool get isDuringWorkProof => stage == ProofStage.duringWork;

  /// Check if this is a completion proof
  bool get isCompletionProof => stage == ProofStage.completion;

  /// Get the URL to display (local or remote)
  String get displayUrl => localPath ?? filePath;

  /// Check if proof is stored locally (not yet uploaded)
  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  /// Get file extension
  String get extension {
    final parts = filePath.split('.');
    return parts.isNotEmpty ? '.${parts.last}' : '';
  }

  ProofModel copyWith({
    int? id,
    int? issueAssignmentId,
    ProofType? type,
    String? filePath,
    ProofStage? stage,
    DateTime? uploadedAt,
    String? localPath,
  }) {
    return ProofModel(
      id: id ?? this.id,
      issueAssignmentId: issueAssignmentId ?? this.issueAssignmentId,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      stage: stage ?? this.stage,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      localPath: localPath ?? this.localPath,
    );
  }

  factory ProofModel.fromJson(Map<String, dynamic> json) {
    // Handle different field names for file path
    final filePath = json['file_path'] as String? ??
        json['file_url'] as String? ??
        json['url'] as String? ??
        json['path'] as String? ??
        '';

    return ProofModel(
      id: _parseInt(json['id']) ?? 0,
      issueAssignmentId: _parseInt(json['issue_assignment_id']),
      type: ProofType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ProofType.photo,
      ),
      filePath: filePath,
      stage: ProofStage.values.firstWhere(
        (e) => e.name == json['stage'],
        orElse: () => ProofStage.completion,
      ),
      uploadedAt: json['uploaded_at'] != null && json['uploaded_at'] is String
          ? DateTime.parse(json['uploaded_at'] as String)
          : null,
      localPath: json['local_path'] as String?,
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

  /// Convert to MediaModel for use with MediaGalleryViewer
  MediaModel toMediaModel() {
    return MediaModel(
      id: id,
      type: MediaType.values.firstWhere(
        (e) => e.name == type.name,
        orElse: () => MediaType.photo,
      ),
      filePath: filePath,
      uploadedAt: uploadedAt,
      localPath: localPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_assignment_id': issueAssignmentId,
      'type': type.name,
      'file_path': filePath,
      'stage': stage.name,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'local_path': localPath,
    };
  }
}
