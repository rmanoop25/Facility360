import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category_model.dart';
import '../../data/repositories/admin_category_repository.dart';

/// State for admin category list (supports tree view)
class AdminCategoryListState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final int total; // Total count from server
  final String? searchQuery;
  final bool? isActiveFilter;
  final bool? rootsOnlyFilter;
  final int? parentIdFilter;
  final Set<int> expandedCategories; // For tree view expansion

  const AdminCategoryListState({
    this.categories = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.total = 0,
    this.searchQuery,
    this.isActiveFilter,
    this.rootsOnlyFilter,
    this.parentIdFilter,
    this.expandedCategories = const {},
  });

  AdminCategoryListState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    int? total,
    String? searchQuery,
    bool? isActiveFilter,
    bool? rootsOnlyFilter,
    int? parentIdFilter,
    Set<int>? expandedCategories,
  }) {
    return AdminCategoryListState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      searchQuery: searchQuery ?? this.searchQuery,
      isActiveFilter: isActiveFilter ?? this.isActiveFilter,
      rootsOnlyFilter: rootsOnlyFilter ?? this.rootsOnlyFilter,
      parentIdFilter: parentIdFilter ?? this.parentIdFilter,
      expandedCategories: expandedCategories ?? this.expandedCategories,
    );
  }

  /// Get root categories
  List<CategoryModel> get rootCategories =>
      categories.where((c) => c.isRoot || c.parentId == null).toList();

  /// Get children of a category
  List<CategoryModel> childrenOf(int parentId) =>
      categories.where((c) => c.parentId == parentId).toList();

  /// Check if category is expanded
  bool isExpanded(int categoryId) => expandedCategories.contains(categoryId);
}

/// Notifier for admin category list
class AdminCategoryListNotifier extends StateNotifier<AdminCategoryListState> {
  final AdminCategoryRepository _repository;

  AdminCategoryListNotifier(this._repository) : super(const AdminCategoryListState());

  /// Load initial categories
  Future<void> loadCategories() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getCategories(
        search: state.searchQuery,
        isActive: state.isActiveFilter,
        page: 1,
      );

      state = state.copyWith(
        categories: response.data,
        isLoading: false,
        currentPage: 1,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminCategoryListNotifier: loadCategories error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more categories (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.getCategories(
        search: state.searchQuery,
        isActive: state.isActiveFilter,
        page: state.currentPage + 1,
      );

      state = state.copyWith(
        categories: [...state.categories, ...response.data],
        isLoadingMore: false,
        currentPage: state.currentPage + 1,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminCategoryListNotifier: loadMore error - $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the list
  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1, hasMore: true);
    await loadCategories();
  }

  /// Search categories
  Future<void> search(String query) async {
    state = state.copyWith(
      searchQuery: query.isEmpty ? null : query,
      currentPage: 1,
      hasMore: true,
    );
    await loadCategories();
  }

  /// Filter by active status
  Future<void> filterByActive(bool? isActive) async {
    state = state.copyWith(
      isActiveFilter: isActive,
      currentPage: 1,
      hasMore: true,
    );
    await loadCategories();
  }

  /// Filter by roots only
  Future<void> filterByRootsOnly(bool? rootsOnly) async {
    state = state.copyWith(
      rootsOnlyFilter: rootsOnly,
      currentPage: 1,
      hasMore: true,
    );
    await loadCategories();
  }

  // =========================================================================
  // Tree View Methods
  // =========================================================================

  /// Toggle expansion state of a category
  void toggleExpanded(int categoryId) {
    final newExpanded = Set<int>.from(state.expandedCategories);
    if (newExpanded.contains(categoryId)) {
      newExpanded.remove(categoryId);
    } else {
      newExpanded.add(categoryId);
    }
    state = state.copyWith(expandedCategories: newExpanded);
  }

  /// Expand a category
  void expand(int categoryId) {
    if (!state.expandedCategories.contains(categoryId)) {
      state = state.copyWith(
        expandedCategories: {...state.expandedCategories, categoryId},
      );
    }
  }

  /// Collapse a category
  void collapse(int categoryId) {
    if (state.expandedCategories.contains(categoryId)) {
      final newExpanded = Set<int>.from(state.expandedCategories);
      newExpanded.remove(categoryId);
      state = state.copyWith(expandedCategories: newExpanded);
    }
  }

  /// Expand all categories
  void expandAll() {
    final allIds = state.categories
        .where((c) => c.hasChildCategories)
        .map((c) => c.id)
        .toSet();
    state = state.copyWith(expandedCategories: allIds);
  }

  /// Collapse all categories
  void collapseAll() {
    state = state.copyWith(expandedCategories: {});
  }

  /// Update a category in the list
  void updateCategory(CategoryModel category) {
    final index = state.categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      final newCategories = [...state.categories];
      newCategories[index] = category;
      state = state.copyWith(categories: newCategories);
    }
  }

  /// Remove a category from the list
  void removeCategory(int id) {
    state = state.copyWith(
      categories: state.categories.where((c) => c.id != id).toList(),
    );
  }

  /// Add a category to the list
  void addCategory(CategoryModel category) {
    state = state.copyWith(
      categories: [category, ...state.categories],
    );
  }
}

/// Provider for admin category list
final adminCategoryListProvider =
    StateNotifierProvider<AdminCategoryListNotifier, AdminCategoryListState>((ref) {
  final repository = ref.watch(adminCategoryRepositoryProvider);
  return AdminCategoryListNotifier(repository);
});

/// Provider for single category detail
final adminCategoryDetailProvider =
    FutureProvider.family<CategoryModel?, int>((ref, id) async {
  final repository = ref.watch(adminCategoryRepositoryProvider);
  try {
    return await repository.getCategory(id);
  } catch (e) {
    debugPrint('adminCategoryDetailProvider: error - $e');
    return null;
  }
});

/// State for category actions (create, update, delete)
class AdminCategoryActionState {
  final bool isLoading;
  final String? error;
  final CategoryModel? result;

  const AdminCategoryActionState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  AdminCategoryActionState copyWith({
    bool? isLoading,
    String? error,
    CategoryModel? result,
  }) {
    return AdminCategoryActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result,
    );
  }
}

/// Notifier for category CRUD actions
class AdminCategoryActionNotifier extends StateNotifier<AdminCategoryActionState> {
  final AdminCategoryRepository _repository;
  final Ref _ref;

  AdminCategoryActionNotifier(this._repository, this._ref)
      : super(const AdminCategoryActionState());

  /// Create a new category
  ///
  /// [parentId] - Optional parent category ID for creating subcategories
  Future<bool> createCategory({
    required String nameEn,
    required String nameAr,
    int? parentId,
    String? descriptionEn,
    String? descriptionAr,
    String? icon,
    String? color,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final category = await _repository.createCategory(
        nameEn: nameEn,
        nameAr: nameAr,
        parentId: parentId,
        descriptionEn: descriptionEn,
        descriptionAr: descriptionAr,
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        isActive: isActive,
      );

      state = state.copyWith(isLoading: false, result: category);

      // Update the list
      _ref.read(adminCategoryListProvider.notifier).addCategory(category);

      // If parent exists, expand it to show the new child
      if (parentId != null) {
        _ref.read(adminCategoryListProvider.notifier).expand(parentId);
      }

      return true;
    } catch (e) {
      debugPrint('AdminCategoryActionNotifier: createCategory error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update an existing category
  ///
  /// [parentId] - Optional parent ID (-1 to set to null/root, other values set parent)
  Future<bool> updateCategory(
    int id, {
    String? nameEn,
    String? nameAr,
    int? parentId,
    String? descriptionEn,
    String? descriptionAr,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final category = await _repository.updateCategory(
        id,
        nameEn: nameEn,
        nameAr: nameAr,
        parentId: parentId,
        descriptionEn: descriptionEn,
        descriptionAr: descriptionAr,
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        isActive: isActive,
      );

      state = state.copyWith(isLoading: false, result: category);

      // Update the list
      _ref.read(adminCategoryListProvider.notifier).updateCategory(category);

      return true;
    } catch (e) {
      debugPrint('AdminCategoryActionNotifier: updateCategory error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Delete a category
  Future<bool> deleteCategory(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteCategory(id);

      state = state.copyWith(isLoading: false);

      // Remove from the list
      _ref.read(adminCategoryListProvider.notifier).removeCategory(id);

      return true;
    } catch (e) {
      debugPrint('AdminCategoryActionNotifier: deleteCategory error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Toggle category active status
  Future<bool> toggleActive(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final category = await _repository.toggleActive(id);

      state = state.copyWith(isLoading: false, result: category);

      // Update the list
      _ref.read(adminCategoryListProvider.notifier).updateCategory(category);

      return true;
    } catch (e) {
      debugPrint('AdminCategoryActionNotifier: toggleActive error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const AdminCategoryActionState();
  }
}

/// Provider for category actions
final adminCategoryActionProvider =
    StateNotifierProvider<AdminCategoryActionNotifier, AdminCategoryActionState>((ref) {
  final repository = ref.watch(adminCategoryRepositoryProvider);
  return AdminCategoryActionNotifier(repository, ref);
});
