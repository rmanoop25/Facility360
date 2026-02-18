import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/consumable_model.dart';
import '../../data/repositories/consumable_repository.dart';

/// State for consumables list
class ConsumablesState {
  final List<ConsumableModel> consumables;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;

  const ConsumablesState({
    this.consumables = const [],
    this.isLoading = false,
    this.error,
    this.lastFetched,
  });

  ConsumablesState copyWith({
    List<ConsumableModel>? consumables,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
    bool clearError = false,
  }) {
    return ConsumablesState(
      consumables: consumables ?? this.consumables,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }

  /// Check if consumables are available
  bool get hasConsumables => consumables.isNotEmpty;

  /// Get active consumables only
  List<ConsumableModel> get activeConsumables =>
      consumables.where((c) => c.isActive).toList();

  /// Get consumables filtered by category
  List<ConsumableModel> byCategory(int categoryId) =>
      consumables.where((c) => c.categoryId == categoryId).toList();
}

/// Provider for all consumables using FutureProvider
final consumablesProvider =
    FutureProvider.autoDispose<List<ConsumableModel>>((ref) async {
  final repository = ref.watch(consumableRepositoryProvider);
  return repository.getConsumables();
});

/// Provider for consumables filtered by category
final consumablesByCategoryProvider = FutureProvider.autoDispose
    .family<List<ConsumableModel>, int>((ref, categoryId) async {
  final repository = ref.watch(consumableRepositoryProvider);
  return repository.getConsumablesByCategory(categoryId);
});

/// Provider for a single consumable by ID
final consumableByIdProvider =
    FutureProvider.autoDispose.family<ConsumableModel?, int>((ref, id) async {
  final repository = ref.watch(consumableRepositoryProvider);
  return repository.getConsumable(id);
});

/// State notifier for consumables with manual refresh control
final consumablesStateProvider =
    StateNotifierProvider<ConsumablesNotifier, ConsumablesState>((ref) {
  final repository = ref.watch(consumableRepositoryProvider);
  return ConsumablesNotifier(repository);
});

class ConsumablesNotifier extends StateNotifier<ConsumablesState> {
  final ConsumableRepository _repository;

  ConsumablesNotifier(this._repository) : super(const ConsumablesState()) {
    // Fetch consumables on initialization
    fetchConsumables();
  }

  /// Fetch consumables from repository
  Future<void> fetchConsumables({bool forceRefresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final consumables = await _repository.getConsumables(
        forceRefresh: forceRefresh,
      );
      state = ConsumablesState(
        consumables: consumables,
        lastFetched: DateTime.now(),
      );
    } on ApiException catch (e) {
      debugPrint('ConsumablesNotifier: Error - ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e, stackTrace) {
      debugPrint('ConsumablesNotifier: Unexpected error - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load consumables. Please try again.',
      );
    }
  }

  /// Force refresh consumables from server
  Future<void> refresh() async {
    await fetchConsumables(forceRefresh: true);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Get consumables for a specific category
  List<ConsumableModel> getByCategory(int categoryId) {
    return state.consumables
        .where((c) => c.categoryId == categoryId && c.isActive)
        .toList();
  }
}

/// Provider for active consumables only (convenience)
final activeConsumablesProvider = Provider<List<ConsumableModel>>((ref) {
  final state = ref.watch(consumablesStateProvider);
  return state.activeConsumables;
});

/// Provider to check if consumables are loaded
final consumablesLoadedProvider = Provider<bool>((ref) {
  final state = ref.watch(consumablesStateProvider);
  return state.hasConsumables && !state.isLoading;
});

/// Provider for consumables loading state
final consumablesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(consumablesStateProvider).isLoading;
});

/// Provider for consumables error state
final consumablesErrorProvider = Provider<String?>((ref) {
  return ref.watch(consumablesStateProvider).error;
});
