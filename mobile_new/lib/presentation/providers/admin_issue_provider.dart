import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/issue_model.dart';
import '../../data/models/service_provider_model.dart';
import '../../data/models/time_slot_model.dart';
import '../../data/repositories/admin_issue_repository.dart';
import '../../data/repositories/admin_tenant_repository.dart';
import 'admin_tenant_provider.dart';

// =============================================================================
// ADMIN ISSUE LIST PROVIDER
// =============================================================================

/// State for admin issue list
class AdminIssueListState {
  final List<IssueModel> issues;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final String? statusFilter;
  final String? priorityFilter;
  final int? categoryFilter;
  final String? searchQuery;

  const AdminIssueListState({
    this.issues = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.statusFilter,
    this.priorityFilter,
    this.categoryFilter,
    this.searchQuery,
  });

  bool get isInitialLoading => isLoading && issues.isEmpty;

  AdminIssueListState copyWith({
    List<IssueModel>? issues,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    String? statusFilter,
    String? priorityFilter,
    int? categoryFilter,
    String? searchQuery,
  }) {
    return AdminIssueListState(
      issues: issues ?? this.issues,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Notifier for admin issue list
/// Admin doesn't use local caching, but still maintains data state for smooth UX
class AdminIssueListNotifier extends StateNotifier<AdminIssueListState> {
  final AdminIssueRepository _repository;
  bool _isInitialized = false;

  AdminIssueListNotifier(this._repository)
    : super(const AdminIssueListState()) {
    loadIssues();
  }

  /// Load initial issues - only shows loading if we have no data
  Future<void> loadIssues() async {
    if (state.isLoading) return;

    // Only show loading if we have NO data yet
    final showLoading = !_isInitialized && state.issues.isEmpty;

    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _repository.getIssues(
        status: state.statusFilter,
        priority: state.priorityFilter,
        categoryId: state.categoryFilter,
        search: state.searchQuery,
        page: 1,
      );

      _isInitialized = true;
      state = state.copyWith(
        issues: response.data,
        isLoading: false,
        currentPage: 1,
        hasMore: response.hasMore,
        error: null,
      );
    } catch (e) {
      debugPrint('AdminIssueListNotifier: loadIssues error - $e');
      _isInitialized = true;
      // Only show error if we have no data to display
      if (state.issues.isEmpty) {
        state = state.copyWith(isLoading: false, error: e.toString());
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Load more issues (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getIssues(
        status: state.statusFilter,
        priority: state.priorityFilter,
        categoryId: state.categoryFilter,
        search: state.searchQuery,
        page: nextPage,
      );

      state = state.copyWith(
        issues: [...state.issues, ...response.data],
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: response.hasMore,
      );
    } catch (e) {
      debugPrint('AdminIssueListNotifier: loadMore error - $e');
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Refresh issues
  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1, hasMore: true);
    await loadIssues();
  }

  /// Set status filter (for explicit filtering if needed)
  /// Note: Tab filtering is handled locally in the UI, this is for explicit filters
  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status, currentPage: 1, hasMore: true);
    // Don't call loadIssues() - filtering is done locally in UI
  }

  /// Set priority filter (for explicit filtering if needed)
  void setPriorityFilter(String? priority) {
    state = state.copyWith(
      priorityFilter: priority,
      currentPage: 1,
      hasMore: true,
    );
    // Don't call loadIssues() - filtering is done locally in UI
  }

  /// Set category filter (triggers reload as server-side filter)
  void setCategoryFilter(int? categoryId) {
    state = state.copyWith(
      categoryFilter: categoryId,
      currentPage: 1,
      hasMore: true,
    );
    loadIssues(); // Category filter needs server-side filtering
  }

  /// Set search query (triggers reload as server-side search)
  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query, currentPage: 1, hasMore: true);
    loadIssues(); // Search needs server-side filtering
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      statusFilter: null,
      priorityFilter: null,
      categoryFilter: null,
      searchQuery: null,
    );
    // Don't call loadIssues() - just clear the filters, UI handles display
  }

  /// Update issue in list after modification
  void updateIssue(IssueModel updatedIssue) {
    final index = state.issues.indexWhere((i) => i.id == updatedIssue.id);
    if (index != -1) {
      final newIssues = [...state.issues];
      newIssues[index] = updatedIssue;
      state = state.copyWith(issues: newIssues);
    }
  }

  /// Add a new issue to the beginning of the list
  void addIssue(IssueModel issue) {
    state = state.copyWith(issues: [issue, ...state.issues]);
  }

  /// Remove issue from list (after cancellation)
  void removeIssue(int issueId) {
    state = state.copyWith(
      issues: state.issues.where((i) => i.id != issueId).toList(),
    );
  }
}

/// Provider for admin issue list
final adminIssueListProvider =
    StateNotifierProvider<AdminIssueListNotifier, AdminIssueListState>((ref) {
      final repository = ref.watch(adminIssueRepositoryProvider);
      return AdminIssueListNotifier(repository);
    });

// =============================================================================
// ADMIN ISSUE DETAIL PROVIDER
// =============================================================================

/// Provider for single admin issue detail
final adminIssueDetailProvider = FutureProvider.family<IssueModel, int>((
  ref,
  issueId,
) async {
  final repository = ref.watch(adminIssueRepositoryProvider);
  return repository.getIssue(issueId);
});

// =============================================================================
// SERVICE PROVIDERS PROVIDER
// =============================================================================

/// Provider for service providers list (for assignment)
final serviceProvidersProvider =
    FutureProvider.family<List<ServiceProviderModel>, int?>((
      ref,
      categoryId,
    ) async {
      final repository = ref.watch(adminIssueRepositoryProvider);
      return repository.getServiceProviders(categoryId: categoryId);
    });

// =============================================================================
// SERVICE PROVIDER AVAILABILITY PROVIDER
// =============================================================================

/// Params for availability query
class AvailabilityParams {
  final int serviceProviderId;
  final DateTime date;
  final int? minDurationMinutes;

  const AvailabilityParams({
    required this.serviceProviderId,
    required this.date,
    this.minDurationMinutes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailabilityParams &&
          runtimeType == other.runtimeType &&
          serviceProviderId == other.serviceProviderId &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          minDurationMinutes == other.minDurationMinutes;

  @override
  int get hashCode =>
      serviceProviderId.hashCode ^
      date.year.hashCode ^
      date.month.hashCode ^
      date.day.hashCode ^
      (minDurationMinutes?.hashCode ?? 0);
}

/// Provider for service provider availability
final serviceProviderAvailabilityProvider =
    FutureProvider.family<List<TimeSlotModel>, AvailabilityParams>((
      ref,
      params,
    ) async {
      final repository = ref.watch(adminIssueRepositoryProvider);
      return repository.getServiceProviderAvailability(
        params.serviceProviderId,
        date: params.date,
        minDurationMinutes: params.minDurationMinutes,
      );
    });

// =============================================================================
// ADMIN ISSUE ACTIONS PROVIDER
// =============================================================================

/// State for admin issue actions
class AdminIssueActionState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const AdminIssueActionState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  AdminIssueActionState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return AdminIssueActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Notifier for admin issue actions (assign, approve, cancel)
class AdminIssueActionNotifier extends StateNotifier<AdminIssueActionState> {
  final AdminIssueRepository _repository;
  final Ref _ref;

  AdminIssueActionNotifier(this._repository, this._ref)
    : super(const AdminIssueActionState());

  /// Assign issue to service provider
  /// Supports both single-slot (timeSlotId) and multi-slot (timeSlotIds) assignments
  Future<bool> assignIssue(
    int issueId, {
    int? categoryId,
    required int serviceProviderId,
    int? workTypeId,
    int? allocatedDurationMinutes,
    bool? isCustomDuration,
    required DateTime scheduledDate,
    int? timeSlotId, // Single slot (legacy/backward compatible)
    List<int>? timeSlotIds, // Multi-slot (new)
    DateTime? scheduledEndDate, // For multi-day assignments
    String? assignedStartTime,
    String? assignedEndTime,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final updatedIssue = await _repository.assignIssue(
        issueId,
        categoryId: categoryId,
        serviceProviderId: serviceProviderId,
        workTypeId: workTypeId,
        allocatedDurationMinutes: allocatedDurationMinutes,
        isCustomDuration: isCustomDuration,
        scheduledDate: scheduledDate,
        timeSlotId: timeSlotId,
        timeSlotIds: timeSlotIds,
        scheduledEndDate: scheduledEndDate,
        assignedStartTime: assignedStartTime,
        assignedEndTime: assignedEndTime,
        notes: notes,
      );

      // Update the issue in the list (optimistic update with server response)
      _ref.read(adminIssueListProvider.notifier).updateIssue(updatedIssue);

      // Invalidate detail providers to pick up updated issue
      _ref.invalidate(adminIssueDetailProvider(issueId));

      // No full list refresh needed - we already have the updated data
      // This prevents UI flicker and unnecessary network requests

      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      debugPrint('AdminIssueActionNotifier: assignIssue error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
      return false;
    }
  }

  /// Update an existing assignment
  Future<bool> updateAssignment(
    int issueId,
    int assignmentId, {
    int? categoryId,
    required int serviceProviderId,
    int? workTypeId,
    int? allocatedDurationMinutes,
    bool? isCustomDuration,
    required DateTime scheduledDate,
    int? timeSlotId,
    List<int>? timeSlotIds,
    DateTime? scheduledEndDate,
    String? assignedStartTime,
    String? assignedEndTime,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final updatedIssue = await _repository.updateAssignment(
        issueId,
        assignmentId,
        categoryId: categoryId,
        serviceProviderId: serviceProviderId,
        workTypeId: workTypeId,
        allocatedDurationMinutes: allocatedDurationMinutes,
        isCustomDuration: isCustomDuration,
        scheduledDate: scheduledDate,
        timeSlotId: timeSlotId,
        timeSlotIds: timeSlotIds,
        scheduledEndDate: scheduledEndDate,
        assignedStartTime: assignedStartTime,
        assignedEndTime: assignedEndTime,
        notes: notes,
      );

      // Update issue in list (optimistic update with server response)
      _ref.read(adminIssueListProvider.notifier).updateIssue(updatedIssue);

      // Invalidate detail providers to pick up updated issue
      _ref.invalidate(adminIssueDetailProvider(issueId));

      // No full list refresh needed - we already have the updated data

      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      debugPrint('AdminIssueActionNotifier: updateAssignment error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
      return false;
    }
  }

  /// Approve finished work
  Future<bool> approveIssue(int issueId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final updatedIssue = await _repository.approveIssue(issueId);

      // Update the issue in the list (optimistic update with server response)
      _ref.read(adminIssueListProvider.notifier).updateIssue(updatedIssue);

      // Invalidate detail providers to pick up updated issue
      _ref.invalidate(adminIssueDetailProvider(issueId));

      // No full list refresh needed - we already have the updated data

      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      debugPrint('AdminIssueActionNotifier: approveIssue error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
      return false;
    }
  }

  /// Cancel issue
  Future<bool> cancelIssue(int issueId, {required String reason}) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final cancelledIssue = await _repository.cancelIssue(
        issueId,
        reason: reason,
      );

      // Update the issue in the list with cancelled status
      _ref.read(adminIssueListProvider.notifier).updateIssue(cancelledIssue);

      // Invalidate detail providers to pick up cancelled status
      _ref.invalidate(adminIssueDetailProvider(issueId));

      // No full list refresh needed - we already have the updated data

      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      debugPrint('AdminIssueActionNotifier: cancelIssue error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
      rethrow; // Let the UI handle the error
    }
  }

  /// Update an existing issue (admin only)
  Future<bool> updateIssue({
    required int issueId,
    required String title,
    String? description,
    String? priority,
    List<int>? categoryIds,
    double? latitude,
    double? longitude,
    String? address,
    List<File>? mediaFiles,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final updatedIssue = await _repository.updateIssue(
        issueId: issueId,
        title: title,
        description: description,
        priority: priority,
        categoryIds: categoryIds,
        latitude: latitude,
        longitude: longitude,
        address: address,
        mediaFiles: mediaFiles,
      );

      // Update the issue in the list (optimistic update with server response)
      _ref.read(adminIssueListProvider.notifier).updateIssue(updatedIssue);

      // Invalidate detail provider to pick up updated issue
      _ref.invalidate(adminIssueDetailProvider(issueId));

      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      debugPrint('AdminIssueActionNotifier: updateIssue error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
      return false;
    }
  }

  /// Create issue on behalf of a tenant
  Future<bool> createIssue({
    required int tenantId,
    required String title,
    String? description,
    required List<int> categoryIds,
    String priority = 'medium',
    double? latitude,
    double? longitude,
    String? address,
    List<File>? mediaFiles,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final createdIssue = await _repository.createIssue(
        tenantId: tenantId,
        title: title,
        description: description,
        categoryIds: categoryIds,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
        address: address,
        mediaFiles: mediaFiles,
      );

      // Add the new issue to the list (no full refresh needed)
      _ref.read(adminIssueListProvider.notifier).addIssue(createdIssue);

      debugPrint(
        'AdminIssueActionNotifier: Issue created successfully - ID: ${createdIssue.id}',
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      debugPrint('AdminIssueActionNotifier: createIssue error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const AdminIssueActionState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for admin issue actions
final adminIssueActionProvider =
    StateNotifierProvider<AdminIssueActionNotifier, AdminIssueActionState>((
      ref,
    ) {
      final repository = ref.watch(adminIssueRepositoryProvider);
      return AdminIssueActionNotifier(repository, ref);
    });

// =============================================================================
// ACTIVE TENANTS PROVIDER (for dropdown selection)
// =============================================================================

/// Searchable, paginated tenant picker provider (autoDispose - resets on each open)
/// Replaces activeTenantListProvider for the create-issue tenant dropdown
final tenantPickerProvider = StateNotifierProvider.autoDispose<
    AdminTenantListNotifier, AdminTenantListState>((ref) {
  final repository = ref.watch(adminTenantRepositoryProvider);
  return AdminTenantListNotifier(repository);
});
