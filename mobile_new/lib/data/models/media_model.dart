import '../../domain/enums/proof_type.dart';

/// Media model matching Laravel backend IssueMedia entity
/// Used for tenant-uploaded photos/videos when creating issues
class MediaModel {
  final int id;
  final int? issueId;
  final MediaType type;
  final String filePath;
  final DateTime? uploadedAt;
  final String? localPath;

  const MediaModel({
    required this.id,
    this.issueId,
    required this.type,
    required this.filePath,
    this.uploadedAt,
    this.localPath,
  });

  /// Check if this is a photo
  bool get isPhoto => type == MediaType.photo;

  /// Check if this is a video
  bool get isVideo => type == MediaType.video;

  /// Get the URL to display (local or remote)
  String get displayUrl => localPath ?? filePath;

  /// Check if media is stored locally (not yet uploaded)
  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  /// Get file extension
  String get extension {
    final parts = filePath.split('.');
    return parts.isNotEmpty ? '.${parts.last}' : '';
  }

  /// Get thumbnail URL (for videos, use placeholder or first frame)
  String get thumbnailUrl {
    if (isPhoto) return displayUrl;
    return displayUrl;
  }

  MediaModel copyWith({
    int? id,
    int? issueId,
    MediaType? type,
    String? filePath,
    DateTime? uploadedAt,
    String? localPath,
  }) {
    return MediaModel(
      id: id ?? this.id,
      issueId: issueId ?? this.issueId,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      localPath: localPath ?? this.localPath,
    );
  }

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    // Handle different field names for file path
    final filePath = json['file_path'] as String? ??
        json['file_url'] as String? ??
        json['url'] as String? ??
        json['path'] as String? ??
        '';

    return MediaModel(
      id: _parseInt(json['id']) ?? 0,
      issueId: _parseInt(json['issue_id']),
      type: MediaType.values.firstWhere(
        (e) => e.name.toLowerCase() == json['type']?.toString().toLowerCase(),
        orElse: () {
          // Log unknown types for debugging
          if (json['type'] != null) {
            print('⚠️ Unknown media type: ${json['type']}, defaulting to photo');
          }
          return MediaType.photo;
        },
      ),
      filePath: filePath,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'type': type.name,
      'file_path': filePath,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'local_path': localPath,
    };
  }
}
