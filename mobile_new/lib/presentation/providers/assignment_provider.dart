import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../data/datasources/assignment_remote_datasource.dart';
import '../../data/models/assignment_model.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../domain/enums/assignment_status.dart';
import '../../domain/enums/sync_status.dart';

// ============================================================================
// ASSIGNMENT LIST STATE & PROVIDER
// ============================================================================

/// State for assignment list with pagination and filtering
class AssignmentListState {
  final List<AssignmentModel> assignments;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final String? statusFilter;
  final String? dateFilter;
  final bool isRefreshing;

  const AssignmentListState({
    this.assignments = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.statusFilter,
    this.dateFilter,
    this.isRefreshing = false,
  });

  AssignmentListState copyWith({
    List<AssignmentModel>? assignments,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    String? statusFilter,
    String? dateFilter,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return AssignmentListState(
      assignments: assignments ?? this.assignments,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      statusFilter: statusFilter ?? this.statusFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Check if list is empty
  bool get isEmpty => assignments.isEmpty && !isLoading;

  /// Check if initial load is in progress
  bool get isInitialLoading => isLoading && assignments.isEmpty;

  /// Get active assignments
  List<AssignmentModel> get activeAssignments =>
      assignments.where((a) => a.isActive).toList();

  /// Get in-progress assignments
  List<AssignmentModel> get inProgressAssignments =>
      assignments.where((a) => a.status == AssignmentStatus.inProgress).toList();

  /// Get today's assignments
  List<AssignmentModel> get todayAssignments =>
      assignments.where((a) => a.isScheduledToday).toList();

  /// Get assignments by status
  Map<AssignmentStatus, List<AssignmentModel>> get assignmentsByStatus {
    final map = <AssignmentStatus, List<AssignmentModel>>{};
    for (final assignment in assignments) {
      map.putIfAbsent(assignment.status, () => []).add(assignment);
    }
    return map;
  }
}

/// Assignment list notifier with pagination and filtering
/// Implements WhatsApp-like seamless loading:
/// - Data is ALWAYS visible from cache
/// - No loading spinners (except very first app launch with empty cache)
/// - New data is merged incrementally
class AssignmentListNotifier extends StateNotifier<AssignmentListState> {
  final AssignmentRepository _repository;
  bool _isInitialized = false;

  AssignmentListNotifier(this._repository) : super(const AssignmentListState()) {
    // Initialize with cached data immediately
    _initializeWithCache();
  }

  /// Load cached data first, then sync in background (WhatsApp-like)
  Future<void> _initializeWithCache() async {
    try {
      // 1. Load from cache FIRST (fast, instant display)
      final cachedAssignments = await _repository.getCachedAssignments();
      if (cachedAssignments.isNotEmpty) {
        state = state.copyWith(
          assignments: cachedAssignments,
          isLoading: false, // Never show loading if we have cache
        );
      }
      _isInitialized = true;

      // 2. Then silently sync from server in background
      _syncFromServer();
    } catch (e) {
      debugPrint('AssignmentListNotifier: Cache init failed - $e');
      _isInitialized = true;
      // Fallback to regular load
      loadAssignments();
    }
  }

  /// Silent background sync - never shows loading
  Future<void> _syncFromServer() async {
    try {
      final response = await _repository.getAssignments(page: 1, forceRefresh: true);
      // Merge new data instead of replacing
      _mergeAssignments(response.data);
    } catch (e) {
      // Silently fail - user still sees cached data
      debugPrint('AssignmentListNotifier: Background sync failed - $e');
    }
  }

  /// Merge server data with existing state (WhatsApp-like incremental update)
  /// IMPORTANT: Preserves local assignments with pending sync over server data
  void _mergeAssignments(List<AssignmentModel> serverAssignments) {
    // Build a map of local assignments that have pending sync
    final pendingSyncAssignments = <int, AssignmentModel>{};
    for (final existing in state.assignments) {
      if (existing.syncStatus != SyncStatus.synced) {
        pendingSyncAssignments[existing.id] = existing;
      }
    }

    debugPrint('AssignmentListNotifier: Merging ${serverAssignments.length} server assignments, ${pendingSyncAssignments.length} have pending sync');

    // Build merged list
    final mergedAssignments = <AssignmentModel>[];
    final addedIds = <int>{};

    // Process server assignments, but prefer local version if it has pending sync
    for (final serverAssignment in serverAssignments) {
      final pendingLocal = pendingSyncAssignments[serverAssignment.id];
      if (pendingLocal != null) {
        // Local version has pending changes - preserve it over server data
        debugPrint('AssignmentListNotifier: Preserving local pending sync for assignment ${pendingLocal.id} (status: ${pendingLocal.status.value})');
        mergedAssignments.add(pendingLocal);
      } else {
        // No local pending changes - use server version
        mergedAssignments.add(serverAssignment);
      }
      addedIds.add(serverAssignment.id);
    }

    // Add any local-only assignments not in server response (newly created offline)
    for (final existing in state.assignments) {
      if (!addedIds.contains(existing.id)) {
        if (existing.syncStatus != SyncStatus.synced || existing.localId != null) {
          mergedAssignments.add(existing);
          debugPrint('AssignmentListNotifier: Keeping local-only assignment ${existing.id}');
        }
      }
    }

    // Sort by scheduled date (most recent first)
    mergedAssignments.sort((a, b) =>
        (b.scheduledDate ?? DateTime.now()).compareTo(a.scheduledDate ?? DateTime.now()));

    state = state.copyWith(assignments: mergedAssignments);
  }

  /// Load assignments - NEVER shows loading if cache exists
  Future<void> loadAssignments({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    // Only show loading on VERY FIRST load with empty cache
    final showLoading = !_isInitialized && state.assignments.isEmpty;

    if (showLoading) {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );
    }

    if (refresh) {
      state = state.copyWith(isRefreshing: true);
    }

    try {
      final response = await _repository.getAssignments(
        page: 1,
        forceRefresh: refresh,
      );

      // Merge assignments instead of replacing
      _mergeAssignments(response.data);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        hasMore: response.hasMore,
        currentPage: 1,
        clearError: true,
      );
    } on ApiException catch (e) {
      // Only show error if we have NO data at all
      if (state.assignments.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: e.message,
        );
      } else {
        // Silently fail - user still sees cached data
        state = state.copyWith(isLoading: false, isRefreshing: false);
      }
    } catch (e, stackTrace) {
      debugPrint('AssignmentListNotifier: Unexpected error - $e');
      debugPrint('Stack trace: $stackTrace');
      if (state.assignments.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: 'Failed to load assignments. Please try again.',
        );
      } else {
        state = state.copyWith(isLoading: false, isRefreshing: false);
      }
    }
  }

  /// Load more assignments (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.getAssignments(
        status: state.statusFilter,
        date: state.dateFilter,
        page: state.currentPage + 1,
      );

      state = state.copyWith(
        assignments: [...state.assignments, ...response.data],
        currentPage: response.currentPage,
        hasMore: response.hasMore,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.message,
      );
    } catch (e) {
      debugPrint('AssignmentListNotifier: Load more failed - $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load more assignments.',
      );
    }
  }

  /// Refresh assignments - shows only refresh indicator, not loading spinner
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true);
    await _syncFromServer();
    state = state.copyWith(isRefreshing: false);
  }

  /// Set status filter (for explicit filtering if needed)
  /// Note: Tab filtering is handled locally in the UI, this is for explicit filters
  void setStatusFilter(String? status) {
    if (state.statusFilter == status) return;
    state = state.copyWith(statusFilter: status);
    // Don't call loadAssignments() - filtering is done locally in UI
  }

  /// Set date filter (for explicit filtering if needed)
  void setDateFilter(String? date) {
    if (state.dateFilter == date) return;
    state = state.copyWith(dateFilter: date);
    // Don't call loadAssignments() - filtering is done locally in UI
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(statusFilter: null, dateFilter: null);
    // Don't call loadAssignments() - just clear the filters, UI handles display
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Update a single assignment in the list
  void updateAssignment(AssignmentModel updatedAssignment) {
    final index = state.assignments.indexWhere((a) =>
        a.id == updatedAssignment.id ||
        (a.localId != null && a.localId == updatedAssignment.localId));

    if (index != -1) {
      final updatedList = List<AssignmentModel>.from(state.assignments);
      updatedList[index] = updatedAssignment;
      state = state.copyWith(assignments: updatedList);
    }
  }

  /// Remove an assignment from the list
  void removeAssignment(int id) {
    state = state.copyWith(
      assignments: state.assignments.where((a) => a.id != id).toList(),
    );
  }

  /// Called after sync to update provider state with synced assignment
  /// This prevents duplicates when Hive migrates from UUID key to server_* key
  Future<void> refreshAfterSync({
    required String oldLocalId,
    required int serverId,
  }) async {
    debugPrint('AssignmentListNotifier: refreshAfterSync - oldLocalId: $oldLocalId, serverId: $serverId');

    // Remove old local version from state (by localId match)
    final updatedAssignments = state.assignments.where((a) {
      if (a.localId == oldLocalId) {
        debugPrint('AssignmentListNotifier: Removing old local assignment $oldLocalId');
        return false;
      }
      return true;
    }).toList();

    // Fetch fresh synced assignment from repository
    try {
      final syncedAssignment = await _repository.getAssignment(serverId);
      // Update existing or add new
      final existingIndex = updatedAssignments.indexWhere((a) => a.id == serverId);
      if (existingIndex >= 0) {
        updatedAssignments[existingIndex] = syncedAssignment;
        debugPrint('AssignmentListNotifier: Updated existing assignment $serverId');
      } else {
        updatedAssignments.add(syncedAssignment);
        debugPrint('AssignmentListNotifier: Added synced assignment $serverId');
      }
      // Sort by scheduled date (most recent first)
      updatedAssignments.sort((a, b) =>
          (b.scheduledDate ?? DateTime.now()).compareTo(a.scheduledDate ?? DateTime.now()));
    } catch (e) {
      debugPrint('AssignmentListNotifier: Could not fetch synced assignment $serverId: $e');
    }

    state = state.copyWith(assignments: updatedAssignments);
    debugPrint('AssignmentListNotifier: State updated after sync - total assignments: ${updatedAssignments.length}');
  }
}

/// Provider for assignment list
final assignmentListProvider =
    StateNotifierProvider<AssignmentListNotifier, AssignmentListState>((ref) {
  final repository = ref.watch(assignmentRepositoryProvider);
  return AssignmentListNotifier(repository);
});

// ============================================================================
// ASSIGNMENT DETAIL PROVIDER
// ============================================================================

/// Provider for single assignment detail
final assignmentDetailProvider =
    FutureProvider.autoDispose.family<AssignmentModel, int>((ref, issueId) async {
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.getAssignment(issueId);
});

// ============================================================================
// WORK EXECUTION STATE & PROVIDER
// ============================================================================

/// State for work execution (start, hold, resume, finish)
class WorkExecutionState {
  final AssignmentModel? assignment;
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final Duration elapsedTime;
  final List<File> proofFiles;
  final List<ConsumableUsageEntry> consumables;
  final String notes;
  final SyncStatus syncStatus;

  const WorkExecutionState({
    this.assignment,
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.elapsedTime = Duration.zero,
    this.proofFiles = const [],
    this.consumables = const [],
    this.notes = '',
    this.syncStatus = SyncStatus.synced,
  });

  WorkExecutionState copyWith({
    AssignmentModel? assignment,
    bool? isLoading,
    String? error,
    bool? isSuccess,
    Duration? elapsedTime,
    List<File>? proofFiles,
    List<ConsumableUsageEntry>? consumables,
    String? notes,
    SyncStatus? syncStatus,
    bool clearError = false,
  }) {
    return WorkExecutionState(
      assignment: assignment ?? this.assignment,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      proofFiles: proofFiles ?? this.proofFiles,
      consumables: consumables ?? this.consumables,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Check if can start work
  bool get canStart => assignment?.canStart ?? false;

  /// Check if can hold work
  bool get canHold => assignment?.canHold ?? false;

  /// Check if can resume work
  bool get canResume => assignment?.canResume ?? false;

  /// Check if can finish work
  bool get canFinish => assignment?.canFinish ?? false;

  /// Check if has required proofs
  bool get hasRequiredProofs {
    if (assignment?.proofRequired != true) return true;
    return proofFiles.isNotEmpty;
  }
}

/// Consumable usage entry for work execution
class ConsumableUsageEntry {
  final int? consumableId;
  final String? customName;
  final String consumableName;
  final int quantity;
  final String? notes;

  const ConsumableUsageEntry({
    this.consumableId,
    this.customName,
    required this.consumableName,
    required this.quantity,
    this.notes,
  });

  bool get isCustom => consumableId == null && customName != null;

  ConsumableUsageEntry copyWith({
    int? consumableId,
    String? customName,
    String? consumableName,
    int? quantity,
    String? notes,
  }) {
    return ConsumableUsageEntry(
      consumableId: consumableId ?? this.consumableId,
      customName: customName ?? this.customName,
      consumableName: consumableName ?? this.consumableName,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  ConsumableUsage toConsumableUsage() {
    return ConsumableUsage(
      consumableId: consumableId,
      customName: customName,
      quantity: quantity,
      notes: notes,
    );
  }
}

/// Work execution notifier
class WorkExecutionNotifier extends StateNotifier<WorkExecutionState> {
  final AssignmentRepository _repository;
  final Ref _ref;

  WorkExecutionNotifier(this._repository, this._ref)
      : super(const WorkExecutionState());

  /// Initialize with assignment
  void initialize(AssignmentModel assignment) {
    final elapsed = assignment.workDuration ?? Duration.zero;
    state = WorkExecutionState(
      assignment: assignment,
      elapsedTime: elapsed,
      syncStatus: assignment.syncStatus,
    );
  }

  /// Update elapsed time
  void updateElapsedTime(Duration elapsed) {
    state = state.copyWith(elapsedTime: elapsed);
  }

  /// Start work
  Future<bool> startWork() async {
    if (state.assignment == null || state.isLoading) return false;

    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);

    try {
      final updatedAssignment =
          await _repository.startWork(state.assignment!.issueId);

      state = state.copyWith(
        assignment: updatedAssignment,
        isLoading: false,
        isSuccess: true,
        syncStatus: updatedAssignment.syncStatus,
      );

      // Update in list
      _ref.read(assignmentListProvider.notifier).updateAssignment(updatedAssignment);

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('WorkExecutionNotifier: Start work failed - $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start work. Please try again.',
      );
      return false;
    }
  }

  /// Hold work
  Future<bool> holdWork({String? reason}) async {
    if (state.assignment == null || state.isLoading) return false;

    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);

    try {
      final updatedAssignment =
          await _repository.holdWork(state.assignment!.issueId, reason: reason);

      state = state.copyWith(
        assignment: updatedAssignment,
        isLoading: false,
        isSuccess: true,
        syncStatus: updatedAssignment.syncStatus,
      );

      _ref.read(assignmentListProvider.notifier).updateAssignment(updatedAssignment);

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('WorkExecutionNotifier: Hold work failed - $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to hold work. Please try again.',
      );
      return false;
    }
  }

  /// Resume work
  Future<bool> resumeWork() async {
    if (state.assignment == null || state.isLoading) return false;

    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);

    try {
      final updatedAssignment =
          await _repository.resumeWork(state.assignment!.issueId);

      state = state.copyWith(
        assignment: updatedAssignment,
        isLoading: false,
        isSuccess: true,
        syncStatus: updatedAssignment.syncStatus,
      );

      _ref.read(assignmentListProvider.notifier).updateAssignment(updatedAssignment);

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('WorkExecutionNotifier: Resume work failed - $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to resume work. Please try again.',
      );
      return false;
    }
  }

  /// Finish work
  Future<bool> finishWork() async {
    if (state.assignment == null || state.isLoading) return false;

    // Validate required proofs
    if (!state.hasRequiredProofs) {
      state = state.copyWith(error: 'Please add at least one proof photo.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);

    try {
      final consumables =
          state.consumables.map((c) => c.toConsumableUsage()).toList();

      final updatedAssignment = await _repository.finishWork(
        state.assignment!.issueId,
        notes: state.notes.isNotEmpty ? state.notes : null,
        proofs: state.proofFiles.isNotEmpty ? state.proofFiles : null,
        consumables: consumables.isNotEmpty ? consumables : null,
      );

      state = state.copyWith(
        assignment: updatedAssignment,
        isLoading: false,
        isSuccess: true,
        syncStatus: updatedAssignment.syncStatus,
      );

      _ref.read(assignmentListProvider.notifier).updateAssignment(updatedAssignment);

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('WorkExecutionNotifier: Finish work failed - $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to finish work. Please try again.',
      );
      return false;
    }
  }

  /// Add proof file
  void addProofFile(File file) {
    state = state.copyWith(proofFiles: [...state.proofFiles, file]);
  }

  /// Remove proof file
  void removeProofFile(int index) {
    final updatedFiles = List<File>.from(state.proofFiles);
    if (index >= 0 && index < updatedFiles.length) {
      updatedFiles.removeAt(index);
      state = state.copyWith(proofFiles: updatedFiles);
    }
  }

  /// Add consumable
  void addConsumable(ConsumableUsageEntry consumable) {
    state = state.copyWith(consumables: [...state.consumables, consumable]);
  }

  /// Update consumable quantity
  void updateConsumableQuantity(int index, int quantity) {
    if (index >= 0 && index < state.consumables.length) {
      final updatedConsumables = List<ConsumableUsageEntry>.from(state.consumables);
      updatedConsumables[index] = updatedConsumables[index].copyWith(quantity: quantity);
      state = state.copyWith(consumables: updatedConsumables);
    }
  }

  /// Remove consumable
  void removeConsumable(int index) {
    if (index >= 0 && index < state.consumables.length) {
      final updatedConsumables = List<ConsumableUsageEntry>.from(state.consumables);
      updatedConsumables.removeAt(index);
      state = state.copyWith(consumables: updatedConsumables);
    }
  }

  /// Update notes
  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Reset state
  void reset() {
    state = const WorkExecutionState();
  }
}

/// Provider for work execution
final workExecutionProvider =
    StateNotifierProvider.autoDispose<WorkExecutionNotifier, WorkExecutionState>(
        (ref) {
  final repository = ref.watch(assignmentRepositoryProvider);
  return WorkExecutionNotifier(repository, ref);
});

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Provider for assignments loading state
final assignmentsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(assignmentListProvider).isLoading;
});

/// Provider for assignments error state
final assignmentsErrorProvider = Provider<String?>((ref) {
  return ref.watch(assignmentListProvider).error;
});

/// Provider for pending sync count
final assignmentPendingSyncCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.getPendingSyncCount();
});

/// Provider for active assignments only
final activeAssignmentsProvider = Provider<List<AssignmentModel>>((ref) {
  return ref.watch(assignmentListProvider).activeAssignments;
});

/// Provider for in-progress assignments
final inProgressAssignmentsProvider = Provider<List<AssignmentModel>>((ref) {
  return ref.watch(assignmentListProvider).inProgressAssignments;
});

/// Provider for today's assignments
final todayAssignmentsProvider = Provider<List<AssignmentModel>>((ref) {
  return ref.watch(assignmentListProvider).todayAssignments;
});

/// Provider for assignments by status
final assignmentsByStatusProvider =
    Provider.family<List<AssignmentModel>, AssignmentStatus>((ref, status) {
  final assignments = ref.watch(assignmentListProvider).assignments;
  return assignments.where((a) => a.status == status).toList();
});
