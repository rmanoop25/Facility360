import 'category_model.dart';

/// Consumable model matching Laravel backend Consumable entity
class ConsumableModel {
  final int id;
  final int? categoryId;
  final String nameEn;
  final String nameAr;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CategoryModel? category;

  const ConsumableModel({
    required this.id,
    this.categoryId,
    required this.nameEn,
    required this.nameAr,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.category,
  });

  /// Get localized name based on locale
  String localizedName(String locale) => locale == 'ar' ? nameAr : nameEn;

  /// Get category name with fallback
  String getCategoryName(String locale) =>
      category?.localizedName(locale) ?? '';

  ConsumableModel copyWith({
    int? id,
    int? categoryId,
    String? nameEn,
    String? nameAr,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryModel? category,
  }) {
    return ConsumableModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  factory ConsumableModel.fromJson(Map<String, dynamic> json) {
    // Handle both 'name_en'/'name_ar' and simplified 'name' format
    final name = json['name'] as String?;
    final nameEn = json['name_en'] as String? ?? name ?? '';
    final nameAr = json['name_ar'] as String? ?? name ?? '';

    // Parse nested category first (if exists)
    final CategoryModel? category = json['category'] != null
        ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
        : null;

    // Handle category_id: try top-level first, then extract from nested category
    int? categoryId = _parseInt(json['category_id']);
    if (categoryId == null && category != null) {
      categoryId = category.id;
    }

    return ConsumableModel(
      id: _parseInt(json['id']) ?? 0,
      categoryId: categoryId,
      nameEn: nameEn,
      nameAr: nameAr,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      category: category,
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
      'category_id': categoryId,
      'name_en': nameEn,
      'name_ar': nameAr,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'category': category?.toJson(),
    };
  }

  /// Convert to JSON for API create/update requests (excludes read-only fields)
  Map<String, dynamic> toCreateJson() {
    return {
      'name_en': nameEn,
      'name_ar': nameAr,
      if (categoryId != null) 'category_id': categoryId,
      'is_active': isActive,
    };
  }
}

/// Consumable usage model for tracking consumables used in assignments
class ConsumableUsageModel {
  final int id;
  final int? issueAssignmentId;
  final int? consumableId;
  final String? customName;
  final int quantity;
  final DateTime? createdAt;
  final ConsumableModel? consumable;

  const ConsumableUsageModel({
    required this.id,
    this.issueAssignmentId,
    this.consumableId,
    this.customName,
    this.quantity = 1,
    this.createdAt,
    this.consumable,
  });

  /// Check if this is a custom consumable (not from master data)
  bool get isCustom => consumableId == null && customName != null;

  /// Get name based on whether it's custom or from master data
  String getName(String locale) {
    if (isCustom) return customName ?? '';
    return consumable?.localizedName(locale) ?? '';
  }

  /// Get display string (e.g., "PVC Pipe x2")
  String getDisplayName(String locale) {
    final name = getName(locale);
    if (quantity > 1) {
      return '$name x$quantity';
    }
    return name;
  }

  ConsumableUsageModel copyWith({
    int? id,
    int? issueAssignmentId,
    int? consumableId,
    String? customName,
    int? quantity,
    DateTime? createdAt,
    ConsumableModel? consumable,
  }) {
    return ConsumableUsageModel(
      id: id ?? this.id,
      issueAssignmentId: issueAssignmentId ?? this.issueAssignmentId,
      consumableId: consumableId ?? this.consumableId,
      customName: customName ?? this.customName,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      consumable: consumable ?? this.consumable,
    );
  }

  factory ConsumableUsageModel.fromJson(Map<String, dynamic> json) {
    return ConsumableUsageModel(
      id: _parseInt(json['id']) ?? 0,
      issueAssignmentId: _parseInt(json['issue_assignment_id']) ?? 0,
      consumableId: _parseInt(json['consumable_id']),
      customName: json['custom_name'] as String?,
      quantity: _parseInt(json['quantity']) ?? 1,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      consumable: json['consumable'] != null
          ? ConsumableModel.fromJson(json['consumable'] as Map<String, dynamic>)
          : null,
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
      'issue_assignment_id': issueAssignmentId,
      'consumable_id': consumableId,
      'custom_name': customName,
      'quantity': quantity,
      'created_at': createdAt?.toIso8601String(),
      'consumable': consumable?.toJson(),
    };
  }
}
