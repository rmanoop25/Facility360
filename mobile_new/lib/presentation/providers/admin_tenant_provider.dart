import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant_model.dart';
import '../../data/repositories/admin_tenant_repository.dart';

/// State for admin tenant list
class AdminTenantListState {
  final List<TenantModel> tenants;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final int total; // Total count from server
  final String? searchQuery;
  final bool? isActiveFilter;

  const AdminTenantListState({
    this.tenants = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.total = 0,
    this.searchQuery,
    this.isActiveFilter,
  });

  AdminTenantListState copyWith({
    List<TenantModel>? tenants,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    int? total,
    String? searchQuery,
    bool? isActiveFilter,
  }) {
    return AdminTenantListState(
      tenants: tenants ?? this.tenants,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      searchQuery: searchQuery ?? this.searchQuery,
      isActiveFilter: isActiveFilter ?? this.isActiveFilter,
    );
  }
}

/// Notifier for admin tenant list
class AdminTenantListNotifier extends StateNotifier<AdminTenantListState> {
  final AdminTenantRepository _repository;

  AdminTenantListNotifier(this._repository) : super(const AdminTenantListState());

  /// Load initial tenants
  Future<void> loadTenants() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getTenants(
        search: state.searchQuery,
        isActive: state.isActiveFilter,
        page: 1,
      );

      state = state.copyWith(
        tenants: response.data,
        isLoading: false,
        currentPage: 1,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminTenantListNotifier: loadTenants error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more tenants (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.getTenants(
        search: state.searchQuery,
        isActive: state.isActiveFilter,
        page: state.currentPage + 1,
      );

      state = state.copyWith(
        tenants: [...state.tenants, ...response.data],
        isLoadingMore: false,
        currentPage: state.currentPage + 1,
        hasMore: response.hasMore,
        total: response.total,
      );
    } catch (e) {
      debugPrint('AdminTenantListNotifier: loadMore error - $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the list
  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1, hasMore: true);
    await loadTenants();
  }

  /// Search tenants
  Future<void> search(String query) async {
    state = state.copyWith(
      searchQuery: query.isEmpty ? null : query,
      currentPage: 1,
      hasMore: true,
    );
    await loadTenants();
  }

  /// Filter by active status
  Future<void> filterByActive(bool? isActive) async {
    state = state.copyWith(
      isActiveFilter: isActive,
      currentPage: 1,
      hasMore: true,
    );
    await loadTenants();
  }

  /// Update a tenant in the list
  void updateTenant(TenantModel tenant) {
    final index = state.tenants.indexWhere((t) => t.id == tenant.id);
    if (index != -1) {
      final newTenants = [...state.tenants];
      newTenants[index] = tenant;
      state = state.copyWith(tenants: newTenants);
    }
  }

  /// Remove a tenant from the list
  void removeTenant(int id) {
    state = state.copyWith(
      tenants: state.tenants.where((t) => t.id != id).toList(),
    );
  }

  /// Add a tenant to the list
  void addTenant(TenantModel tenant) {
    state = state.copyWith(
      tenants: [tenant, ...state.tenants],
    );
  }
}

/// Provider for admin tenant list
final adminTenantListProvider =
    StateNotifierProvider<AdminTenantListNotifier, AdminTenantListState>((ref) {
  final repository = ref.watch(adminTenantRepositoryProvider);
  return AdminTenantListNotifier(repository);
});

/// Provider for single tenant detail
final adminTenantDetailProvider =
    FutureProvider.family<TenantModel?, int>((ref, id) async {
  final repository = ref.watch(adminTenantRepositoryProvider);
  try {
    return await repository.getTenant(id);
  } catch (e) {
    debugPrint('adminTenantDetailProvider: error - $e');
    return null;
  }
});

/// State for tenant actions (create, update, delete)
class AdminTenantActionState {
  final bool isLoading;
  final String? error;
  final TenantModel? result;

  const AdminTenantActionState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  AdminTenantActionState copyWith({
    bool? isLoading,
    String? error,
    TenantModel? result,
  }) {
    return AdminTenantActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result,
    );
  }
}

/// Notifier for tenant CRUD actions
class AdminTenantActionNotifier extends StateNotifier<AdminTenantActionState> {
  final AdminTenantRepository _repository;
  final Ref _ref;

  AdminTenantActionNotifier(this._repository, this._ref)
      : super(const AdminTenantActionState());

  /// Create a new tenant
  Future<bool> createTenant({
    required String name,
    required String email,
    required String password,
    required String unitNumber,
    required String buildingName,
    String? phone,
    File? profilePhoto,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final tenant = await _repository.createTenant(
        name: name,
        email: email,
        password: password,
        unitNumber: unitNumber,
        buildingName: buildingName,
        phone: phone,
        profilePhoto: profilePhoto,
      );

      state = state.copyWith(isLoading: false, result: tenant);

      // Update the list
      _ref.read(adminTenantListProvider.notifier).addTenant(tenant);

      return true;
    } catch (e) {
      debugPrint('AdminTenantActionNotifier: createTenant error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update an existing tenant
  Future<bool> updateTenant(
    int id, {
    String? name,
    String? email,
    String? password,
    String? unitNumber,
    String? buildingName,
    String? phone,
    bool? isActive,
    File? profilePhoto,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final tenant = await _repository.updateTenant(
        id,
        name: name,
        email: email,
        password: password,
        unitNumber: unitNumber,
        buildingName: buildingName,
        phone: phone,
        isActive: isActive,
        profilePhoto: profilePhoto,
      );

      state = state.copyWith(isLoading: false, result: tenant);

      // Update the list
      _ref.read(adminTenantListProvider.notifier).updateTenant(tenant);

      return true;
    } catch (e) {
      debugPrint('AdminTenantActionNotifier: updateTenant error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Delete a tenant
  Future<bool> deleteTenant(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteTenant(id);

      state = state.copyWith(isLoading: false);

      // Remove from the list
      _ref.read(adminTenantListProvider.notifier).removeTenant(id);

      return true;
    } catch (e) {
      debugPrint('AdminTenantActionNotifier: deleteTenant error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Toggle tenant active status
  Future<bool> toggleActive(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final tenant = await _repository.toggleActive(id);

      state = state.copyWith(isLoading: false, result: tenant);

      // Update the list
      _ref.read(adminTenantListProvider.notifier).updateTenant(tenant);

      return true;
    } catch (e) {
      debugPrint('AdminTenantActionNotifier: toggleActive error - $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const AdminTenantActionState();
  }
}

/// Provider for tenant actions
final adminTenantActionProvider =
    StateNotifierProvider<AdminTenantActionNotifier, AdminTenantActionState>((ref) {
  final repository = ref.watch(adminTenantRepositoryProvider);
  return AdminTenantActionNotifier(repository, ref);
});
