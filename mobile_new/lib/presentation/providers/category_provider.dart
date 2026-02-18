import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

/// State for category list
class CategoriesState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;

  const CategoriesState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.lastFetched,
  });

  CategoriesState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
    bool clearError = false,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }

  /// Check if categories are available
  bool get hasCategories => categories.isNotEmpty;

  /// Get active categories only
  List<CategoryModel> get activeCategories =>
      categories.where((c) => c.isActive).toList();
}

/// Provider for categories using FutureProvider (simpler for read-only data)
final categoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategories();
});

/// Provider for a single category by ID
final categoryByIdProvider =
    FutureProvider.autoDispose.family<CategoryModel?, int>((ref, id) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategory(id);
});

/// State notifier for categories with manual refresh control
final categoriesStateProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoriesNotifier(repository);
});

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  final CategoryRepository _repository;

  CategoriesNotifier(this._repository) : super(const CategoriesState()) {
    // Fetch categories on initialization
    fetchCategories();
  }

  /// Fetch categories from repository
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final categories = await _repository.getCategories(
        forceRefresh: forceRefresh,
      );
      state = CategoriesState(
        categories: categories,
        lastFetched: DateTime.now(),
      );
    } on ApiException catch (e) {
      debugPrint('CategoriesNotifier: Error - ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e, stackTrace) {
      debugPrint('CategoriesNotifier: Unexpected error - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load categories. Please try again.',
      );
    }
  }

  /// Force refresh categories from server
  Future<void> refresh() async {
    await fetchCategories(forceRefresh: true);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for active categories only (convenience)
final activeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final state = ref.watch(categoriesStateProvider);
  return state.activeCategories;
});

/// Provider to check if categories are loaded
final categoriesLoadedProvider = Provider<bool>((ref) {
  final state = ref.watch(categoriesStateProvider);
  return state.hasCategories && !state.isLoading;
});

/// Provider for categories loading state
final categoriesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(categoriesStateProvider).isLoading;
});

/// Provider for categories error state
final categoriesErrorProvider = Provider<String?>((ref) {
  return ref.watch(categoriesStateProvider).error;
});

// =========================================================================
// Hierarchy Providers
// =========================================================================

/// Provider for root categories only (no parent)
final rootCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final state = ref.watch(categoriesStateProvider);
  return state.categories
      .where((c) => c.isActive && (c.isRoot || c.parentId == null))
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// Provider for children of a specific category
final childCategoriesProvider = Provider.family<List<CategoryModel>, int>((ref, parentId) {
  final state = ref.watch(categoriesStateProvider);
  return state.categories
      .where((c) => c.isActive && c.parentId == parentId)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// Provider to check if a category has children
final categoryHasChildrenProvider = Provider.family<bool, int>((ref, categoryId) {
  final state = ref.watch(categoriesStateProvider);
  return state.categories.any((c) => c.parentId == categoryId && c.isActive);
});

/// Provider to get leaf categories only (no children)
final leafCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final state = ref.watch(categoriesStateProvider);
  final parentIds = state.categories
      .map((c) => c.parentId)
      .whereType<int>()
      .toSet();
  return state.categories
      .where((c) => c.isActive && !parentIds.contains(c.id))
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// Provider to get ancestors of a category (ordered root to parent)
final categoryAncestorsProvider = Provider.family<List<CategoryModel>, int>((ref, categoryId) {
  final state = ref.watch(categoriesStateProvider);
  return state.categories.ancestorsOf(categoryId);
});

/// Provider to get full path of a category (ancestors + self)
final categoryPathProvider = Provider.family<List<CategoryModel>, int>((ref, categoryId) {
  final state = ref.watch(categoriesStateProvider);
  return state.categories.pathOf(categoryId);
});

/// Provider to build category tree map (parentId -> children)
final categoryTreeMapProvider = Provider<Map<int?, List<CategoryModel>>>((ref) {
  final state = ref.watch(categoriesStateProvider);
  final activeCategories = state.categories.where((c) => c.isActive).toList();
  return activeCategories.categoryTree;
});

/// State for cascading category selection (used in tenant issue creation)
class CascadingCategoryState {
  final List<int> selectedPath; // List of selected category IDs from root to current
  final bool isComplete; // True if a leaf category is selected

  const CascadingCategoryState({
    this.selectedPath = const [],
    this.isComplete = false,
  });

  CascadingCategoryState copyWith({
    List<int>? selectedPath,
    bool? isComplete,
  }) {
    return CascadingCategoryState(
      selectedPath: selectedPath ?? this.selectedPath,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  /// Get the currently selected category ID (last in path)
  int? get selectedCategoryId => selectedPath.isNotEmpty ? selectedPath.last : null;

  /// Get depth of current selection
  int get depth => selectedPath.length;
}

/// Notifier for cascading category selection
class CascadingCategoryNotifier extends StateNotifier<CascadingCategoryState> {
  final Ref _ref;

  CascadingCategoryNotifier(this._ref) : super(const CascadingCategoryState());

  /// Select a category at a specific depth
  ///
  /// If selecting at a depth less than current, truncates the path
  void selectCategory(int categoryId) {
    final categories = _ref.read(categoriesStateProvider).categories;
    final category = categories.where((c) => c.id == categoryId).firstOrNull;
    if (category == null) return;

    // Build the new path
    List<int> newPath;
    if (category.parentId == null) {
      // Root category - start new path
      newPath = [categoryId];
    } else {
      // Find where this category fits in current path
      final parentIndex = state.selectedPath.indexOf(category.parentId!);
      if (parentIndex >= 0) {
        // Parent is in current path - extend from there
        newPath = [...state.selectedPath.sublist(0, parentIndex + 1), categoryId];
      } else {
        // Need to build path from scratch
        newPath = categories.pathOf(categoryId).map((c) => c.id).toList();
      }
    }

    // Check if this is a leaf category
    final hasChildren = _ref.read(categoryHasChildrenProvider(categoryId));

    state = state.copyWith(
      selectedPath: newPath,
      isComplete: !hasChildren,
    );
  }

  /// Go back one level in the selection
  void goBack() {
    if (state.selectedPath.length <= 1) {
      // Reset to root selection
      state = const CascadingCategoryState();
    } else {
      state = state.copyWith(
        selectedPath: state.selectedPath.sublist(0, state.selectedPath.length - 1),
        isComplete: false,
      );
    }
  }

  /// Reset selection
  void reset() {
    state = const CascadingCategoryState();
  }

  /// Set selection directly (e.g., when editing an existing issue)
  void setSelection(int categoryId) {
    final categories = _ref.read(categoriesStateProvider).categories;
    final path = categories.pathOf(categoryId).map((c) => c.id).toList();
    final hasChildren = _ref.read(categoryHasChildrenProvider(categoryId));

    state = CascadingCategoryState(
      selectedPath: path,
      isComplete: !hasChildren,
    );
  }
}

/// Provider for cascading category selection
final cascadingCategoryProvider =
    StateNotifierProvider.autoDispose<CascadingCategoryNotifier, CascadingCategoryState>((ref) {
  return CascadingCategoryNotifier(ref);
});

/// Provider for categories at current selection level
final currentLevelCategoriesProvider = Provider.autoDispose<List<CategoryModel>>((ref) {
  final cascadingState = ref.watch(cascadingCategoryProvider);

  if (cascadingState.selectedPath.isEmpty) {
    // No selection yet - show root categories
    return ref.watch(rootCategoriesProvider);
  }

  // Show children of last selected category
  final lastSelectedId = cascadingState.selectedPath.last;
  return ref.watch(childCategoriesProvider(lastSelectedId));
});
