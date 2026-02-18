import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category_model.dart';
import 'category_provider.dart';

/// State for multi-category selection (used in issue creation)
class MultiCategorySelectionState {
  final Set<int> selectedIds;
  final String searchQuery;
  final Set<int> expandedParentIds;

  const MultiCategorySelectionState({
    this.selectedIds = const {},
    this.searchQuery = '',
    this.expandedParentIds = const {},
  });

  MultiCategorySelectionState copyWith({
    Set<int>? selectedIds,
    String? searchQuery,
    Set<int>? expandedParentIds,
  }) {
    return MultiCategorySelectionState(
      selectedIds: selectedIds ?? this.selectedIds,
      searchQuery: searchQuery ?? this.searchQuery,
      expandedParentIds: expandedParentIds ?? this.expandedParentIds,
    );
  }

  /// Check if any categories are selected
  bool get hasSelection => selectedIds.isNotEmpty;

  /// Get number of selected categories
  int get selectionCount => selectedIds.length;

  /// Check if a specific category is selected
  bool isSelected(int id) => selectedIds.contains(id);

  /// Check if a parent category is expanded
  bool isExpanded(int id) => expandedParentIds.contains(id);

  /// Check if search is active
  bool get isSearching => searchQuery.isNotEmpty;
}

/// Notifier for multi-category selection
class MultiCategorySelectionNotifier
    extends StateNotifier<MultiCategorySelectionState> {
  final Ref _ref;

  MultiCategorySelectionNotifier(this._ref)
      : super(const MultiCategorySelectionState());

  /// Toggle a category selection
  void toggleCategory(int id) {
    final newSelection = Set<int>.from(state.selectedIds);
    if (newSelection.contains(id)) {
      newSelection.remove(id);
    } else {
      newSelection.add(id);
    }
    state = state.copyWith(selectedIds: newSelection);
  }

  /// Add a category to selection
  void selectCategory(int id) {
    if (!state.selectedIds.contains(id)) {
      state = state.copyWith(
        selectedIds: {...state.selectedIds, id},
      );
    }
  }

  /// Remove a category from selection
  void deselectCategory(int id) {
    if (state.selectedIds.contains(id)) {
      final newSelection = Set<int>.from(state.selectedIds)..remove(id);
      state = state.copyWith(selectedIds: newSelection);
    }
  }

  /// Clear all selections
  void clearAll() {
    state = state.copyWith(selectedIds: {});
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear search query
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Toggle parent category expansion
  void toggleExpanded(int parentId) {
    final newExpanded = Set<int>.from(state.expandedParentIds);
    if (newExpanded.contains(parentId)) {
      newExpanded.remove(parentId);
    } else {
      newExpanded.add(parentId);
    }
    state = state.copyWith(expandedParentIds: newExpanded);
  }

  /// Expand a parent category
  void expand(int parentId) {
    if (!state.expandedParentIds.contains(parentId)) {
      state = state.copyWith(
        expandedParentIds: {...state.expandedParentIds, parentId},
      );
    }
  }

  /// Collapse a parent category
  void collapse(int parentId) {
    if (state.expandedParentIds.contains(parentId)) {
      final newExpanded = Set<int>.from(state.expandedParentIds)
        ..remove(parentId);
      state = state.copyWith(expandedParentIds: newExpanded);
    }
  }

  /// Expand all parent categories
  void expandAll() {
    final categories = _ref.read(categoriesStateProvider).categories;
    final parentIds = categories
        .where((c) => c.isActive && (c.hasChildCategories))
        .map((c) => c.id)
        .toSet();
    state = state.copyWith(expandedParentIds: parentIds);
  }

  /// Collapse all parent categories
  void collapseAll() {
    state = state.copyWith(expandedParentIds: {});
  }

  /// Set selections directly (e.g., when editing an existing issue)
  void setSelections(List<int> ids) {
    state = state.copyWith(selectedIds: ids.toSet());
  }

  /// Initialize from existing selections (useful when opening the sheet)
  void initialize(Set<int> existingSelections) {
    state = MultiCategorySelectionState(
      selectedIds: existingSelections,
      searchQuery: '',
      expandedParentIds: _computeExpandedParents(existingSelections),
    );
  }

  /// Reset to initial state
  void reset() {
    state = const MultiCategorySelectionState();
  }

  /// Compute which parents should be expanded based on selections
  Set<int> _computeExpandedParents(Set<int> selectedIds) {
    if (selectedIds.isEmpty) return {};

    final categories = _ref.read(categoriesStateProvider).categories;
    final expandedIds = <int>{};

    for (final selectedId in selectedIds) {
      // Get ancestors of this selection and expand them
      final ancestors = categories.ancestorsOf(selectedId);
      for (final ancestor in ancestors) {
        expandedIds.add(ancestor.id);
      }
    }

    return expandedIds;
  }
}

/// Provider for multi-category selection
final multiCategorySelectionProvider = StateNotifierProvider.autoDispose<
    MultiCategorySelectionNotifier, MultiCategorySelectionState>((ref) {
  return MultiCategorySelectionNotifier(ref);
});

/// Provider for filtered categories based on search query
final filteredCategoriesProvider =
    Provider.autoDispose<List<CategoryModel>>((ref) {
  final state = ref.watch(multiCategorySelectionProvider);
  final categories = ref.watch(categoriesStateProvider).categories;

  if (state.searchQuery.isEmpty) {
    // Return active categories only when not searching
    return categories.where((c) => c.isActive).toList();
  }

  final query = state.searchQuery.toLowerCase();
  return categories.where((c) {
    if (!c.isActive) return false;
    return c.nameEn.toLowerCase().contains(query) ||
        c.nameAr.toLowerCase().contains(query);
  }).toList();
});

/// Provider to get selected categories as CategoryModel list
final selectedCategoriesProvider =
    Provider.autoDispose<List<CategoryModel>>((ref) {
  final state = ref.watch(multiCategorySelectionProvider);
  final categories = ref.watch(categoriesStateProvider).categories;

  return categories.where((c) => state.selectedIds.contains(c.id)).toList();
});

/// Provider to count selected children of a parent category (including nested)
final selectedChildrenCountProvider =
    Provider.autoDispose.family<int, int>((ref, parentId) {
  final state = ref.watch(multiCategorySelectionProvider);
  final allCategories = ref.watch(categoriesStateProvider).categories;

  // Get all descendant IDs iteratively to avoid recursion issues
  Set<int> getAllDescendantIds(int pId) {
    final descendants = <int>{};
    final toProcess = <int>[pId];

    while (toProcess.isNotEmpty) {
      final currentId = toProcess.removeLast();
      final children =
          allCategories.where((c) => c.parentId == currentId && c.isActive);
      for (final child in children) {
        descendants.add(child.id);
        toProcess.add(child.id);
      }
    }

    return descendants;
  }

  final descendantIds = getAllDescendantIds(parentId);
  return state.selectedIds.intersection(descendantIds).length;
});
