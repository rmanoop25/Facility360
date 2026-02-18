import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/service_provider_model.dart';
import '../../data/repositories/admin_service_provider_repository.dart';

/// State for admin service provider list
class AdminServiceProviderListState {
  final List<ServiceProviderModel> serviceProviders;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final int total; // Total count from server
  final String? searchQuery;
  final int? categoryIdFilter;
  final bool? isAvailableFilter;
  final bool? isActiveFilter;

  const AdminServiceProviderListState({
    this.serviceProviders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.total = 0,
    this.searchQuery,
    this.categoryIdFilter,
    this.isAvailableFilter,
    this.isActiveFilter,
  });

  AdminServiceProviderListState copyWith({
    List<ServiceProviderModel>? serviceProviders,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    int? total,
    String? searchQuery,
    int? categoryIdFilter,
    bool? isAvailableFilter,
    bool? isActiveFilter,
    bool clearCategoryFilter = false,
    bool clearAvailableFilter = false,
    bool clearActiveFilter = false,
  }) {
    return AdminServiceProviderListState(
      serviceProviders: serviceProviders ?? this.serviceProviders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryIdFilter: clearCategoryFilter ? null : (categoryIdFilter ?? this.categoryIdFilter),
      isAvailableFilter: clearAvailableFilter ? null : (isAvailableFilter ?? this.isAvailableFilter),
      isActiveFilter: clearActiveFilter ? null : (isActiveFilter ?? this.isActiveFilter),
    );
  }
}

/// Notifier for admin service provider list
class AdminServiceProviderListNotifier extends StateNotifier<AdminServiceProviderListState> {
  final AdminServiceProviderRepository _repository;

  AdminServiceProviderListNotifier(this._repository) : super(const AdminServiceProviderListState());

  /// Load initial service providers
  Future<void> loadServiceProviders() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getServiceProviders(
        search: state.searchQuery,
        categoryId: state.categoryIdFilter,
        isAvailable: state.isAvailableFilter,
        isActive: state.isActiveFilter,
        page: 1,
      );

      state = state.copyWith(
        serviceProviders: response.data,
        isLoading: false,
        currentPage: 1,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminServiceProviderListNotifier: loadServiceProviders error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more service providers (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.getServiceProviders(
        search: state.searchQuery,
        categoryId: state.categoryIdFilter,
        isAvailable: state.isAvailableFilter,
        isActive: state.isActiveFilter,
        page: state.currentPage + 1,
      );

      state = state.copyWith(
        serviceProviders: [...state.serviceProviders, ...response.data],
        isLoadingMore: false,
        currentPage: state.currentPage + 1,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminServiceProviderListNotifier: loadMore error - $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the list
  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1, hasMore: true);
    await loadServiceProviders();
  }

  /// Search service providers
  Future<void> search(String query) async {
    state = state.copyWith(
      searchQuery: query.isEmpty ? null : query,
      currentPage: 1,
      hasMore: true,
    );
    await loadServiceProviders();
  }

  /// Filter by category
  Future<void> filterByCategory(int? categoryId) async {
    state = state.copyWith(
      categoryIdFilter: categoryId,
      clearCategoryFilter: categoryId == null,
      currentPage: 1,
      hasMore: true,
    );
    await loadServiceProviders();
  }

  /// Filter by availability
  Future<void> filterByAvailability(bool? isAvailable) async {
    state = state.copyWith(
      isAvailableFilter: isAvailable,
      clearAvailableFilter: isAvailable == null,
      currentPage: 1,
      hasMore: true,
    );
    await loadServiceProviders();
  }

  /// Filter by active status
  Future<void> filterByActive(bool? isActive) async {
    state = state.copyWith(
      isActiveFilter: isActive,
      clearActiveFilter: isActive == null,
      currentPage: 1,
      hasMore: true,
    );
    await loadServiceProviders();
  }

  /// Update a service provider in the list
  void updateServiceProvider(ServiceProviderModel provider) {
    final index = state.serviceProviders.indexWhere((p) => p.id == provider.id);
    if (index != -1) {
      final newProviders = [...state.serviceProviders];
      newProviders[index] = provider;
      state = state.copyWith(serviceProviders: newProviders);
    }
  }

  /// Remove a service provider from the list
  void removeServiceProvider(int id) {
    state = state.copyWith(
      serviceProviders: state.serviceProviders.where((p) => p.id != id).toList(),
    );
  }

  /// Add a service provider to the list
  void addServiceProvider(ServiceProviderModel provider) {
    state = state.copyWith(
      serviceProviders: [provider, ...state.serviceProviders],
    );
  }
}

/// Provider for admin service provider list
final adminServiceProviderListProvider =
    StateNotifierProvider<AdminServiceProviderListNotifier, AdminServiceProviderListState>((ref) {
  final repository = ref.watch(adminServiceProviderRepositoryProvider);
  return AdminServiceProviderListNotifier(repository);
});

/// Provider for single service provider detail
final adminServiceProviderDetailProvider =
    FutureProvider.family<ServiceProviderModel?, int>((ref, id) async {
  final repository = ref.watch(adminServiceProviderRepositoryProvider);
  try {
    return await repository.getServiceProvider(id);
  } catch (e) {
    debugPrint('adminServiceProviderDetailProvider: error - $e');
    return null;
  }
});

/// State for service provider actions (create, update, delete)
class AdminServiceProviderActionState {
  final bool isLoading;
  final String? error;
  final ServiceProviderModel? result;

  const AdminServiceProviderActionState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  AdminServiceProviderActionState copyWith({
    bool? isLoading,
    String? error,
    ServiceProviderModel? result,
  }) {
    return AdminServiceProviderActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result,
    );
  }
}

/// Notifier for service provider CRUD actions
class AdminServiceProviderActionNotifier extends StateNotifier<AdminServiceProviderActionState> {
  final AdminServiceProviderRepository _repository;
  final Ref _ref;

  AdminServiceProviderActionNotifier(this._repository, this._ref)
      : super(const AdminServiceProviderActionState());

  /// Create a new service provider
  Future<bool> createServiceProvider({
    required String name,
    required String email,
    required String password,
    required List<int> categoryIds,
    String? phone,
    bool isAvailable = true,
    File? profilePhoto,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final provider = await _repository.createServiceProvider(
        name: name,
        email: email,
        password: password,
        categoryIds: categoryIds,
        phone: phone,
        isAvailable: isAvailable,
        profilePhoto: profilePhoto,
      );

      state = state.copyWith(isLoading: false, result: provider);

      // Update the list
      _ref.read(adminServiceProviderListProvider.notifier).addServiceProvider(provider);

      return true;
    } catch (e) {
      debugPrint('AdminServiceProviderActionNotifier: createServiceProvider error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update an existing service provider
  Future<bool> updateServiceProvider(
    int id, {
    String? name,
    String? email,
    String? password,
    List<int>? categoryIds,
    String? phone,
    bool? isAvailable,
    bool? isActive,
    File? profilePhoto,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final provider = await _repository.updateServiceProvider(
        id,
        name: name,
        email: email,
        password: password,
        categoryIds: categoryIds,
        phone: phone,
        isAvailable: isAvailable,
        isActive: isActive,
        profilePhoto: profilePhoto,
      );

      state = state.copyWith(isLoading: false, result: provider);

      // Update the list
      _ref.read(adminServiceProviderListProvider.notifier).updateServiceProvider(provider);

      return true;
    } catch (e) {
      debugPrint('AdminServiceProviderActionNotifier: updateServiceProvider error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Delete a service provider
  Future<bool> deleteServiceProvider(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteServiceProvider(id);

      state = state.copyWith(isLoading: false);

      // Remove from the list
      _ref.read(adminServiceProviderListProvider.notifier).removeServiceProvider(id);

      return true;
    } catch (e) {
      debugPrint('AdminServiceProviderActionNotifier: deleteServiceProvider error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Toggle service provider active status
  Future<bool> toggleActive(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final provider = await _repository.toggleActive(id);

      state = state.copyWith(isLoading: false, result: provider);

      // Update the list
      _ref.read(adminServiceProviderListProvider.notifier).updateServiceProvider(provider);

      return true;
    } catch (e) {
      debugPrint('AdminServiceProviderActionNotifier: toggleActive error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Toggle service provider availability
  Future<bool> toggleAvailability(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final provider = await _repository.toggleAvailability(id);

      state = state.copyWith(isLoading: false, result: provider);

      // Update the list
      _ref.read(adminServiceProviderListProvider.notifier).updateServiceProvider(provider);

      return true;
    } catch (e) {
      debugPrint('AdminServiceProviderActionNotifier: toggleAvailability error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const AdminServiceProviderActionState();
  }
}

/// Provider for service provider actions
final adminServiceProviderActionProvider =
    StateNotifierProvider<AdminServiceProviderActionNotifier, AdminServiceProviderActionState>((ref) {
  final repository = ref.watch(adminServiceProviderRepositoryProvider);
  return AdminServiceProviderActionNotifier(repository, ref);
});
