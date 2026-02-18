import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/consumable_model.dart';
import '../../data/repositories/admin_consumable_repository.dart';

/// State for admin consumable list
class AdminConsumableListState {
  final List<ConsumableModel> consumables;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final int total; // Total count from server
  final String? searchQuery;
  final int? categoryIdFilter;
  final bool? isActiveFilter;

  const AdminConsumableListState({
    this.consumables = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.total = 0,
    this.searchQuery,
    this.categoryIdFilter,
    this.isActiveFilter,
  });

  AdminConsumableListState copyWith({
    List<ConsumableModel>? consumables,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    int? total,
    String? searchQuery,
    int? categoryIdFilter,
    bool? isActiveFilter,
    bool clearCategoryFilter = false,
  }) {
    return AdminConsumableListState(
      consumables: consumables ?? this.consumables,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryIdFilter: clearCategoryFilter ? null : (categoryIdFilter ?? this.categoryIdFilter),
      isActiveFilter: isActiveFilter ?? this.isActiveFilter,
    );
  }

  /// Get consumables grouped by category
  Map<int, List<ConsumableModel>> get consumablesByCategory {
    final result = <int, List<ConsumableModel>>{};
    for (final consumable in consumables) {
      final categoryId = consumable.categoryId ?? 0;
      result.putIfAbsent(categoryId, () => []).add(consumable);
    }
    return result;
  }
}

/// Notifier for admin consumable list
class AdminConsumableListNotifier extends StateNotifier<AdminConsumableListState> {
  final AdminConsumableRepository _repository;

  AdminConsumableListNotifier(this._repository) : super(const AdminConsumableListState());

  /// Load initial consumables
  Future<void> loadConsumables() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getConsumables(
        search: state.searchQuery,
        categoryId: state.categoryIdFilter,
        isActive: state.isActiveFilter,
        page: 1,
      );

      debugPrint('AdminConsumableListNotifier: Loaded page 1 - items: ${response.data.length}, hasMore: ${response.hasMore}, currentPage: ${response.currentPage}, lastPage: ${response.lastPage}, total: ${response.total}');

      state = state.copyWith(
        consumables: response.data,
        isLoading: false,
        currentPage: 1,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminConsumableListNotifier: loadConsumables error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more consumables (pagination)
  Future<void> loadMore() async {
    debugPrint('AdminConsumableListNotifier: loadMore called - isLoadingMore: ${state.isLoadingMore}, hasMore: ${state.hasMore}, currentPage: ${state.currentPage}');

    if (state.isLoadingMore || !state.hasMore) {
      debugPrint('AdminConsumableListNotifier: loadMore skipped - isLoadingMore: ${state.isLoadingMore}, hasMore: ${state.hasMore}');
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      debugPrint('AdminConsumableListNotifier: Loading page $nextPage');

      final response = await _repository.getConsumables(
        search: state.searchQuery,
        categoryId: state.categoryIdFilter,
        isActive: state.isActiveFilter,
        page: nextPage,
      );

      debugPrint('AdminConsumableListNotifier: Loaded page $nextPage - items: ${response.data.length}, hasMore: ${response.hasMore}, total: ${response.total}');

      state = state.copyWith(
        consumables: [...state.consumables, ...response.data],
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminConsumableListNotifier: loadMore error - $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the list
  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1, hasMore: true);
    await loadConsumables();
  }

  /// Search consumables
  Future<void> search(String query) async {
    state = state.copyWith(
      searchQuery: query.isEmpty ? null : query,
      currentPage: 1,
      hasMore: true,
    );
    await loadConsumables();
  }

  /// Filter by category
  Future<void> filterByCategory(int? categoryId) async {
    state = state.copyWith(
      categoryIdFilter: categoryId,
      clearCategoryFilter: categoryId == null,
      currentPage: 1,
      hasMore: true,
    );
    await loadConsumables();
  }

  /// Filter by active status
  Future<void> filterByActive(bool? isActive) async {
    state = state.copyWith(
      isActiveFilter: isActive,
      currentPage: 1,
      hasMore: true,
    );
    await loadConsumables();
  }

  /// Update a consumable in the list
  void updateConsumable(ConsumableModel consumable) {
    final index = state.consumables.indexWhere((c) => c.id == consumable.id);
    if (index != -1) {
      final newConsumables = [...state.consumables];
      newConsumables[index] = consumable;
      state = state.copyWith(consumables: newConsumables);
    }
  }

  /// Remove a consumable from the list
  void removeConsumable(int id) {
    state = state.copyWith(
      consumables: state.consumables.where((c) => c.id != id).toList(),
    );
  }

  /// Add a consumable to the list
  void addConsumable(ConsumableModel consumable) {
    state = state.copyWith(
      consumables: [consumable, ...state.consumables],
    );
  }
}

/// Provider for admin consumable list
final adminConsumableListProvider =
    StateNotifierProvider<AdminConsumableListNotifier, AdminConsumableListState>((ref) {
  final repository = ref.watch(adminConsumableRepositoryProvider);
  return AdminConsumableListNotifier(repository);
});

/// Provider for single consumable detail
final adminConsumableDetailProvider =
    FutureProvider.family<ConsumableModel?, int>((ref, id) async {
  final repository = ref.watch(adminConsumableRepositoryProvider);
  try {
    return await repository.getConsumable(id);
  } catch (e) {
    debugPrint('adminConsumableDetailProvider: error - $e');
    return null;
  }
});

/// State for consumable actions (create, update, delete)
class AdminConsumableActionState {
  final bool isLoading;
  final String? error;
  final ConsumableModel? result;

  const AdminConsumableActionState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  AdminConsumableActionState copyWith({
    bool? isLoading,
    String? error,
    ConsumableModel? result,
  }) {
    return AdminConsumableActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result,
    );
  }
}

/// Notifier for consumable CRUD actions
class AdminConsumableActionNotifier extends StateNotifier<AdminConsumableActionState> {
  final AdminConsumableRepository _repository;
  final Ref _ref;

  AdminConsumableActionNotifier(this._repository, this._ref)
      : super(const AdminConsumableActionState());

  /// Create a new consumable
  Future<bool> createConsumable({
    required String nameEn,
    required String nameAr,
    required int categoryId,
    bool isActive = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final consumable = await _repository.createConsumable(
        nameEn: nameEn,
        nameAr: nameAr,
        categoryId: categoryId,
        isActive: isActive,
      );

      state = state.copyWith(isLoading: false, result: consumable);

      // Update the list
      _ref.read(adminConsumableListProvider.notifier).addConsumable(consumable);

      return true;
    } catch (e) {
      debugPrint('AdminConsumableActionNotifier: createConsumable error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update an existing consumable
  Future<bool> updateConsumable(
    int id, {
    String? nameEn,
    String? nameAr,
    int? categoryId,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final consumable = await _repository.updateConsumable(
        id,
        nameEn: nameEn,
        nameAr: nameAr,
        categoryId: categoryId,
        isActive: isActive,
      );

      state = state.copyWith(isLoading: false, result: consumable);

      // Update the list
      _ref.read(adminConsumableListProvider.notifier).updateConsumable(consumable);

      return true;
    } catch (e) {
      debugPrint('AdminConsumableActionNotifier: updateConsumable error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Delete a consumable
  Future<bool> deleteConsumable(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteConsumable(id);

      state = state.copyWith(isLoading: false);

      // Remove from the list
      _ref.read(adminConsumableListProvider.notifier).removeConsumable(id);

      return true;
    } catch (e) {
      debugPrint('AdminConsumableActionNotifier: deleteConsumable error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Toggle consumable active status
  Future<bool> toggleActive(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final consumable = await _repository.toggleActive(id);

      state = state.copyWith(isLoading: false, result: consumable);

      // Update the list
      _ref.read(adminConsumableListProvider.notifier).updateConsumable(consumable);

      return true;
    } catch (e) {
      debugPrint('AdminConsumableActionNotifier: toggleActive error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const AdminConsumableActionState();
  }
}

/// Provider for consumable actions
final adminConsumableActionProvider =
    StateNotifierProvider<AdminConsumableActionNotifier, AdminConsumableActionState>((ref) {
  final repository = ref.watch(adminConsumableRepositoryProvider);
  return AdminConsumableActionNotifier(repository, ref);
});
