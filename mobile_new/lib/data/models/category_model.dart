/// Category model matching Laravel backend Category entity with hierarchy support
class CategoryModel {
  final int id;
  final int? parentId;
  final String nameEn;
  final String nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final int depth;
  final String? path;
  final bool isRoot;
  final bool? isLeaf;
  final bool? hasChildren;
  final int? childrenCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? consumablesCount;
  final int? serviceProvidersCount;
  final int? issuesCount;

  /// Nested children (only populated when API returns nested=true)
  final List<CategoryModel>? children;

  const CategoryModel({
    required this.id,
    this.parentId,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    this.depth = 0,
    this.path,
    this.isRoot = true,
    this.isLeaf,
    this.hasChildren,
    this.childrenCount,
    this.createdAt,
    this.updatedAt,
    this.consumablesCount,
    this.serviceProvidersCount,
    this.issuesCount,
    this.children,
  });

  /// Get localized name based on locale
  String localizedName(String locale) => locale == 'ar' ? nameAr : nameEn;

  /// Get icon name with fallback
  String get iconName => icon ?? 'general';

  /// Get category icon (mapped from Laravel icon field)
  String get categoryIcon {
    return switch (iconName.toLowerCase()) {
      'plumbing' => 'plumbing',
      'electrical' => 'electrical',
      'hvac' => 'hvac',
      'carpentry' => 'carpentry',
      'painting' => 'painting',
      'cleaning' => 'cleaning',
      _ => 'general',
    };
  }

  /// Check if this is a leaf category (no children)
  bool get isLeafCategory => isLeaf ?? (hasChildren == false) ?? (childrenCount == 0);

  /// Check if this category has children
  bool get hasChildCategories => hasChildren ?? (childrenCount != null && childrenCount! > 0);

  CategoryModel copyWith({
    int? id,
    int? parentId,
    String? nameEn,
    String? nameAr,
    String? descriptionEn,
    String? descriptionAr,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isActive,
    int? depth,
    String? path,
    bool? isRoot,
    bool? isLeaf,
    bool? hasChildren,
    int? childrenCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? consumablesCount,
    int? serviceProvidersCount,
    int? issuesCount,
    List<CategoryModel>? children,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      depth: depth ?? this.depth,
      path: path ?? this.path,
      isRoot: isRoot ?? this.isRoot,
      isLeaf: isLeaf ?? this.isLeaf,
      hasChildren: hasChildren ?? this.hasChildren,
      childrenCount: childrenCount ?? this.childrenCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      consumablesCount: consumablesCount ?? this.consumablesCount,
      serviceProvidersCount: serviceProvidersCount ?? this.serviceProvidersCount,
      issuesCount: issuesCount ?? this.issuesCount,
      children: children ?? this.children,
    );
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    // Handle both 'name_en'/'name_ar' and simplified 'name' format
    final name = json['name'] as String?;
    final nameEn = json['name_en'] as String? ?? name ?? '';
    final nameAr = json['name_ar'] as String? ?? name ?? '';

    // Parse nested children if present
    List<CategoryModel>? children;
    if (json['children'] != null && json['children'] is List) {
      children = (json['children'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => CategoryModel.fromJson(e))
          .toList();
    }

    return CategoryModel(
      id: _parseInt(json['id']) ?? 0,
      parentId: _parseInt(json['parent_id']),
      nameEn: nameEn,
      nameAr: nameAr,
      descriptionEn: json['description_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: _parseInt(json['sort_order']) ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      depth: _parseInt(json['depth']) ?? 0,
      path: json['path'] as String?,
      isRoot: json['is_root'] as bool? ?? (json['parent_id'] == null),
      isLeaf: json['is_leaf'] as bool?,
      hasChildren: json['has_children'] as bool?,
      childrenCount: _parseInt(json['children_count']),
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      consumablesCount: _parseInt(json['consumables_count']),
      serviceProvidersCount: _parseInt(json['service_providers_count']),
      issuesCount: _parseInt(json['issues_count']),
      children: children,
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
      'parent_id': parentId,
      'name_en': nameEn,
      'name_ar': nameAr,
      'description_en': descriptionEn,
      'description_ar': descriptionAr,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive,
      'depth': depth,
      'path': path,
      'is_root': isRoot,
      'is_leaf': isLeaf,
      'has_children': hasChildren,
      'children_count': childrenCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'consumables_count': consumablesCount,
      'service_providers_count': serviceProvidersCount,
      'issues_count': issuesCount,
      if (children != null) 'children': children!.map((c) => c.toJson()).toList(),
    };
  }

  /// Convert to JSON for API create/update requests (excludes read-only fields)
  Map<String, dynamic> toCreateJson() {
    return {
      if (parentId != null) 'parent_id': parentId,
      'name_en': nameEn,
      'name_ar': nameAr,
      if (descriptionEn != null) 'description_en': descriptionEn,
      if (descriptionAr != null) 'description_ar': descriptionAr,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CategoryModel(id: $id, nameEn: $nameEn, parentId: $parentId, depth: $depth)';
}

/// Extension methods for working with category hierarchies
extension CategoryModelListExtensions on List<CategoryModel> {
  /// Get root categories (no parent)
  List<CategoryModel> get rootCategories =>
      where((c) => c.isRoot || c.parentId == null).toList();

  /// Get children of a specific category
  List<CategoryModel> childrenOf(int parentId) =>
      where((c) => c.parentId == parentId).toList();

  /// Build a map of parent ID to children for efficient tree building
  Map<int?, List<CategoryModel>> get categoryTree {
    final tree = <int?, List<CategoryModel>>{};
    for (final category in this) {
      tree.putIfAbsent(category.parentId, () => []).add(category);
    }
    return tree;
  }

  /// Get all leaf categories (no children)
  List<CategoryModel> get leafCategories {
    final childParentIds = map((c) => c.parentId).whereType<int>().toSet();
    return where((c) => !childParentIds.contains(c.id)).toList();
  }

  /// Find ancestors of a category (ordered from root to immediate parent)
  List<CategoryModel> ancestorsOf(int categoryId) {
    final ancestors = <CategoryModel>[];
    var current = firstWhere(
      (c) => c.id == categoryId,
      orElse: () => first, // Fallback, won't be used if category exists
    );

    while (current.parentId != null) {
      final parent = where((c) => c.id == current.parentId).firstOrNull;
      if (parent == null) break;
      ancestors.insert(0, parent);
      current = parent;
    }

    return ancestors;
  }

  /// Get full path of a category as a list
  List<CategoryModel> pathOf(int categoryId) {
    final category = where((c) => c.id == categoryId).firstOrNull;
    if (category == null) return [];
    return [...ancestorsOf(categoryId), category];
  }
}
