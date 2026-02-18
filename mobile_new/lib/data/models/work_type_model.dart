class WorkTypeModel {
  final int id;
  final String nameEn;
  final String nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final int durationMinutes;
  final bool isActive;
  final List<int> categoryIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkTypeModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    required this.durationMinutes,
    this.isActive = true,
    this.categoryIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  String get name {
    // TODO: Use easy_localization context for locale detection
    return nameEn;
  }

  /// Get localized name based on locale code
  String getName(String locale) {
    return locale == 'ar' ? nameAr : nameEn;
  }

  String? get description {
    // TODO: Use easy_localization context for locale detection
    return descriptionEn;
  }

  /// Get localized description based on locale code
  String? getDescription(String locale) {
    return locale == 'ar' ? descriptionAr : descriptionEn;
  }

  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    }
    return hours > 0 ? '${hours}h' : '${mins}m';
  }

  factory WorkTypeModel.fromJson(Map<String, dynamic> json) {
    return WorkTypeModel(
      id: _parseInt(json['id']) ?? 0,
      nameEn: json['name_en']?.toString() ?? '',
      nameAr: json['name_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      durationMinutes: _parseInt(json['duration_minutes']) ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      categoryIds: (json['categories'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((c) => _parseInt(c['id']) ?? 0)
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ar': nameAr,
      'description_en': descriptionEn,
      'description_ar': descriptionAr,
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'category_ids': categoryIds,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic v) =>
      v is int ? v : v is String ? int.tryParse(v) : null;

  WorkTypeModel copyWith({
    int? id,
    String? nameEn,
    String? nameAr,
    String? descriptionEn,
    String? descriptionAr,
    int? durationMinutes,
    bool? isActive,
    List<int>? categoryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkTypeModel(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WorkTypeModel &&
        other.id == id &&
        other.nameEn == nameEn &&
        other.nameAr == nameAr &&
        other.durationMinutes == durationMinutes;
  }

  @override
  int get hashCode {
    return Object.hash(id, nameEn, nameAr, durationMinutes);
  }
}
