import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

/// Proof type enum matching Laravel backend
/// STRICT: Only supports jpg, jpeg, png, mp4, mp3, pdf
@JsonEnum(valueField: 'value')
enum ProofType {
  @JsonValue('photo')
  photo('photo'),

  @JsonValue('video')
  video('video'),

  @JsonValue('audio')
  audio('audio'),

  @JsonValue('pdf')
  pdf('pdf');

  const ProofType(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get human-readable label
  String get label => switch (this) {
    photo => 'Photo',
    video => 'Video',
    audio => 'Audio',
    pdf => 'PDF Document',
  };

  /// Get Arabic label
  String get labelAr => switch (this) {
    photo => 'صورة',
    video => 'فيديو',
    audio => 'صوت',
    pdf => 'مستند PDF',
  };

  /// Get localized label
  String localizedLabel(String locale) =>
      locale == 'ar' ? labelAr : label;

  /// Get icon for this type
  IconData get icon => switch (this) {
    photo => Icons.photo_camera_rounded,
    video => Icons.videocam_rounded,
    audio => Icons.mic_rounded,
    pdf => Icons.picture_as_pdf_rounded,
  };

  /// Get accepted MIME types (STRICT - only these types allowed)
  List<String> get mimeTypes => switch (this) {
    photo => ['image/jpeg', 'image/png'],
    video => ['video/mp4'],
    audio => ['audio/mpeg'],
    pdf => ['application/pdf'],
  };

  /// Get file extensions (STRICT - only these extensions allowed)
  List<String> get extensions => switch (this) {
    photo => ['.jpg', '.jpeg', '.png'],
    video => ['.mp4'],
    audio => ['.mp3'],
    pdf => ['.pdf'],
  };

  /// Get max file size in bytes
  int get maxSizeBytes => switch (this) {
    photo => 10 * 1024 * 1024,   // 10MB
    video => 100 * 1024 * 1024,  // 100MB
    audio => 20 * 1024 * 1024,   // 20MB
    pdf => 20 * 1024 * 1024,     // 20MB
  };

  /// Parse from string value
  static ProofType? fromValue(String? value) {
    if (value == null) return null;
    return ProofType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => ProofType.photo,
    );
  }

  /// Detect type from file extension (STRICT validation)
  static ProofType? fromExtension(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return ProofType.photo;
    }
    if (ext.endsWith('.mp4')) {
      return ProofType.video;
    }
    if (ext.endsWith('.mp3')) {
      return ProofType.audio;
    }
    if (ext.endsWith('.pdf')) {
      return ProofType.pdf;
    }
    return null; // Unsupported format
  }
}

/// Proof stage enum matching Laravel backend
@JsonEnum(valueField: 'value')
enum ProofStage {
  @JsonValue('during_work')
  duringWork('during_work'),

  @JsonValue('completion')
  completion('completion');

  const ProofStage(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get human-readable label
  String get label => switch (this) {
    duringWork => 'During Work',
    completion => 'Completion',
  };

  /// Get Arabic label
  String get labelAr => switch (this) {
    duringWork => 'أثناء العمل',
    completion => 'عند الانتهاء',
  };

  /// Get localized label
  String localizedLabel(String locale) =>
      locale == 'ar' ? labelAr : label;

  /// Parse from string value
  static ProofStage? fromValue(String? value) {
    if (value == null) return null;
    return ProofStage.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ProofStage.duringWork,
    );
  }
}

/// Media type enum for issue media (tenant uploads)
/// STRICT: Only supports jpg, jpeg, png, mp4, mp3, pdf
@JsonEnum(valueField: 'value')
enum MediaType {
  @JsonValue('photo')
  photo('photo'),

  @JsonValue('video')
  video('video'),

  @JsonValue('audio')
  audio('audio'),

  @JsonValue('pdf')
  pdf('pdf');

  const MediaType(this.value);

  /// JSON value for API serialization
  final String value;

  /// Get human-readable label
  String get label => switch (this) {
    photo => 'Photo',
    video => 'Video',
    audio => 'Audio',
    pdf => 'PDF Document',
  };

  /// Get Arabic label
  String get labelAr => switch (this) {
    photo => 'صورة',
    video => 'فيديو',
    audio => 'صوت',
    pdf => 'مستند PDF',
  };

  /// Get localized label
  String localizedLabel(String locale) =>
      locale == 'ar' ? labelAr : label;

  /// Get icon for this type
  IconData get icon => switch (this) {
    photo => Icons.photo_camera_rounded,
    video => Icons.videocam_rounded,
    audio => Icons.mic_rounded,
    pdf => Icons.picture_as_pdf_rounded,
  };

  /// Get accepted MIME types (STRICT - only these types allowed)
  List<String> get mimeTypes => switch (this) {
    photo => ['image/jpeg', 'image/png'],
    video => ['video/mp4'],
    audio => ['audio/mpeg'],
    pdf => ['application/pdf'],
  };

  /// Get file extensions (STRICT - only these extensions allowed)
  List<String> get extensions => switch (this) {
    photo => ['.jpg', '.jpeg', '.png'],
    video => ['.mp4'],
    audio => ['.mp3'],
    pdf => ['.pdf'],
  };

  /// Get max file size in bytes
  int get maxSizeBytes => switch (this) {
    photo => 10 * 1024 * 1024,   // 10MB
    video => 100 * 1024 * 1024,  // 100MB
    audio => 20 * 1024 * 1024,   // 20MB
    pdf => 20 * 1024 * 1024,     // 20MB
  };

  /// Parse from string value
  static MediaType? fromValue(String? value) {
    if (value == null) return null;
    return MediaType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => MediaType.photo,
    );
  }

  /// Detect type from file extension (STRICT validation)
  static MediaType? fromExtension(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return MediaType.photo;
    }
    if (ext.endsWith('.mp4')) {
      return MediaType.video;
    }
    if (ext.endsWith('.mp3')) {
      return MediaType.audio;
    }
    if (ext.endsWith('.pdf')) {
      return MediaType.pdf;
    }
    return null; // Unsupported format
  }
}
