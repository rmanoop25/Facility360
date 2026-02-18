import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/issue_model.dart';
import '../../data/repositories/issue_repository.dart';
import '../../domain/enums/issue_status.dart';
import '../../domain/enums/issue_priority.dart';
import '../../domain/enums/sync_status.dart';

// ============================================================================
// ISSUE LIST STATE & PROVIDER
// ============================================================================

/// State for issue list with pagination and filtering
class IssueListState {
  final List<IssueModel> issues;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final String? statusFilter;
  final String? priorityFilter;
  final bool isRefreshing;

  const IssueListState({
    this.issues = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.statusFilter,
    this.priorityFilter,
    this.isRefreshing = false,
  });

  IssueListState copyWith({
    List<IssueModel>? issues,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    String? statusFilter,
    String? priorityFilter,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return IssueListState(
      issues: issues ?? this.issues,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Check if list is empty
  bool get isEmpty => issues.isEmpty && !isLoading;

  /// Check if initial load is in progress
  bool get isInitialLoading => isLoading && issues.isEmpty;

  /// Get issues filtered by active status (not completed/cancelled)
  List<IssueModel> get activeIssues =>
      issues.where((i) => i.status.isActive).toList();

  /// Get issues grouped by status
  Map<IssueStatus, List<IssueModel>> get issuesByStatus {
    final map = <IssueStatus, List<IssueModel>>{};
    for (final issue in issues) {
      map.putIfAbsent(issue.status, () => []).add(issue);
    }
    return map;
  }
}

/// Issue list notifier with pagination and filtering
/// Implements WhatsApp-like seamless loading:
/// - Data is ALWAYS visible from cache
/// - No loading spinners (except very first app launch with empty cache)
/// - New data is merged incrementally
class IssueListNotifier extends StateNotifier<IssueListState> {
  final IssueRepository _repository;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  IssueListNotifier(this._repository) : super(const IssueListState()) {
    // Initialize with cached data immediately
    _initializeWithCache();
  }

  /// Load cached data first, then sync in background (WhatsApp-like)
  Future<void> _initializeWithCache() async {
    try {
      // 1. Load from cache FIRST (fast, instant display)
      final cachedIssues = await _repository.getCachedIssues();
      if (cachedIssues.isNotEmpty) {
        state = state.copyWith(
          issues: cachedIssues,
          isLoading: false, // Never show loading if we have cache
        );
      }
      _isInitialized = true;

      // 2. Then silently sync from server in background
      _syncFromServer();
    } catch (e) {
      debugPrint('IssueListNotifier: Cache init failed - $e');
      _isInitialized = true;
      // Fallback to regular load
      loadIssues();
    }
  }

  /// Silent background sync - never shows loading
  /// Implements debouncing to prevent multiple simultaneous syncs
  Future<void> _syncFromServer() async {
    // Debounce: Don't sync if synced in last 10 seconds
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) <
            const Duration(seconds: 10)) {
      debugPrint('IssueListNotifier: Sync skipped (debounced)');
      return;
    }

    if (_isSyncing) {
      debugPrint('IssueListNotifier: Sync already in progress');
      return;
    }

    _isSyncing = true;

    try {
      final response = await _repository.getIssues(page: 1, forceRefresh: true);
      // Merge new data incrementally instead of replacing entire list
      _mergeIssuesIncrementally(response.data);
      _lastSyncTime = DateTime.now();
    } catch (e) {
      // Silently fail - user still sees cached data
      debugPrint('IssueListNotifier: Background sync failed - $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Intelligently merge server data with minimal UI disruption
  /// Only updates changed items, adds new items, removes deleted items
  /// This prevents full list refreshes and provides WhatsApp-like smooth updates
  /// IMPORTANT: Preserves local issues with pending sync over server data
  void _mergeIssuesIncrementally(List<IssueModel> serverIssues) {
    // Build lookup map for efficient server issue lookup
    final serverIssuesMap = <int, IssueModel>{
      for (var i in serverIssues) i.id: i,
    };

    final itemsToKeep = <IssueModel>[];
    final newItems = <IssueModel>[];

    // Count pending sync items for debugging
    final pendingSyncCount = state.issues
        .where((i) => i.syncStatus != SyncStatus.synced)
        .length;
    debugPrint(
      'IssueListNotifier: Merging ${serverIssues.length} server issues, $pendingSyncCount have pending sync',
    );

    // Step 1: Process existing items - keep or update
    for (final current in state.issues) {
      // CRITICAL: Preserve ANY issue with pending sync (not just local-only)
      // This includes existing server issues that were modified offline (e.g., cancelled)
      if (current.syncStatus != SyncStatus.synced) {
        // Check if it was just synced (appears in server list with same localId or same changes)
        // Also try content-based matching for cases where localId was migrated
        IssueModel? syncedVersion;
        for (final s in serverIssues) {
          // Match by localId
          if (s.localId == current.localId) {
            syncedVersion = s;
            break;
          }
          // Match by id + status (for updates)
          if (s.id == current.id && s.status == current.status) {
            syncedVersion = s;
            break;
          }
          // Match by content (for newly synced local issues where localId changed)
          // Local issues have negative IDs, if we find a server issue with same title
          // and similar creation time, it's likely the synced version
          if (current.id < 0 &&
              s.title == current.title &&
              _isWithinMinutes(s.createdAt, current.createdAt, 5)) {
            debugPrint(
              'IssueListNotifier: Found synced version ${s.id} by content match for local ${current.localId}',
            );
            syncedVersion = s;
            break;
          }
        }

        if (syncedVersion != null &&
            syncedVersion.syncStatus == SyncStatus.synced) {
          // Issue was synced successfully, use server version
          debugPrint(
            'IssueListNotifier: Issue ${current.id} synced successfully, using server version ${syncedVersion.id}',
          );
          itemsToKeep.add(syncedVersion);
          serverIssuesMap.remove(syncedVersion.id); // Mark as processed
        } else {
          // Still pending, keep local version over server
          debugPrint(
            'IssueListNotifier: Preserving local pending sync for issue ${current.id} (status: ${current.status})',
          );
          itemsToKeep.add(current);
          serverIssuesMap.remove(
            current.id,
          ); // Don't overwrite with server version
        }
        continue;
      }

      // For fully synced issues, check if updated on server
      if (serverIssuesMap.containsKey(current.id)) {
        final serverVersion = serverIssuesMap[current.id]!;
        // Use server version if it has changes, otherwise keep current
        if (!_areIssuesEqual(current, serverVersion)) {
          itemsToKeep.add(serverVersion);
        } else {
          itemsToKeep.add(current); // No change, keep existing reference
        }
        serverIssuesMap.remove(current.id); // Mark as processed
      }
      // If not on server and fully synced, it was deleted - don't keep
    }

    // Step 2: Identify truly new items from server (not yet processed)
    newItems.addAll(serverIssuesMap.values);

    // Step 3: Combine new items at top, then existing items
    final mergedList = [...newItems, ...itemsToKeep];

    // Step 4: Deduplicate by serverId to prevent duplicate issues after sync
    // This handles race conditions where Hive might have both old localId key and new server_* key
    final seenServerIds = <int>{};
    final deduplicatedList = <IssueModel>[];
    for (final issue in mergedList) {
      if (issue.id > 0) {
        // Server issue - deduplicate by id
        if (seenServerIds.contains(issue.id)) {
          debugPrint(
            'IssueListNotifier: Removing duplicate issue with serverId ${issue.id}',
          );
          continue;
        }
        seenServerIds.add(issue.id);
      }
      // Local-only issues (id <= 0) are always kept (they have unique localIds)
      deduplicatedList.add(issue);
    }

    // Sort by date (newest first)
    deduplicatedList.sort(
      (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
        a.createdAt ?? DateTime.now(),
      ),
    );

    // Only update state if there are actual changes (prevents unnecessary rebuilds)
    if (!_listsAreEqual(state.issues, deduplicatedList)) {
      state = state.copyWith(issues: deduplicatedList);
      if (newItems.isNotEmpty) {
        debugPrint('IssueListNotifier: Added ${newItems.length} new items');
      }
      if (mergedList.length != deduplicatedList.length) {
        debugPrint(
          'IssueListNotifier: Removed ${mergedList.length - deduplicatedList.length} duplicates',
        );
      }
    } else {
      debugPrint(
        'IssueListNotifier: No changes detected, skipping state update',
      );
    }
  }

  /// Compare two issue lists for equality
  /// Returns true if both lists contain the same issues in the same order
  bool _listsAreEqual(List<IssueModel> a, List<IssueModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_areIssuesEqual(a[i], b[i])) return false;
    }
    return true;
  }

  /// Compare two issues to detect meaningful changes
  /// Returns true if issues are functionally equal (no UI update needed)
  bool _areIssuesEqual(IssueModel a, IssueModel b) {
    return a.id == b.id &&
        a.title == b.title &&
        a.description == b.description &&
        a.status == b.status &&
        a.priority == b.priority &&
        a.syncStatus == b.syncStatus &&
        a.updatedAt == b.updatedAt;
  }

  /// Load issues - NEVER shows loading if cache exists
  Future<void> loadIssues({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    // Only show loading on VERY FIRST load with empty cache
    final showLoading = !_isInitialized && state.issues.isEmpty;

    if (showLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    if (refresh) {
      state = state.copyWith(isRefreshing: true);
    }

    try {
      final response = await _repository.getIssues(
        page: 1,
        forceRefresh: refresh,
      );

      // Merge issues incrementally instead of replacing
      _mergeIssuesIncrementally(response.data);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        hasMore: response.hasMore,
        currentPage: 1,
        clearError: true,
      );
    } on ApiException catch (e) {
      // Only show error if we have NO data at all
      if (state.issues.isEmpty) {
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
      debugPrint('IssueListNotifier: Unexpected error - $e');
      debugPrint('Stack trace: $stackTrace');
      if (state.issues.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: 'Failed to load issues. Please try again.',
        );
      } else {
        state = state.copyWith(isLoading: false, isRefreshing: false);
      }
    }
  }

  /// Load more issues (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.getIssues(
        status: state.statusFilter,
        priority: state.priorityFilter,
        page: state.currentPage + 1,
      );

      state = state.copyWith(
        issues: [...state.issues, ...response.data],
        currentPage: response.currentPage,
        hasMore: response.hasMore,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.message);
    } catch (e) {
      debugPrint('IssueListNotifier: Load more failed - $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load more issues.',
      );
    }
  }

  /// Refresh issues - shows only refresh indicator, not loading spinner
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
    // Don't call loadIssues() - filtering is done locally in UI
  }

  /// Set priority filter (for explicit filtering if needed)
  void setPriorityFilter(String? priority) {
    if (state.priorityFilter == priority) return;
    state = state.copyWith(priorityFilter: priority);
    // Don't call loadIssues() - filtering is done locally in UI
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(statusFilter: null, priorityFilter: null);
    // Don't call loadIssues() - just clear the filters, UI handles display
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Update a single issue in the list (after detail update)
  void updateIssue(IssueModel updatedIssue) {
    final index = state.issues.indexWhere(
      (i) =>
          i.id == updatedIssue.id ||
          (i.localId != null && i.localId == updatedIssue.localId),
    );

    if (index != -1) {
      final updatedList = List<IssueModel>.from(state.issues);
      updatedList[index] = updatedIssue;
      state = state.copyWith(issues: updatedList);
    }
  }

  /// Add a new issue to the beginning of the list
  void addIssue(IssueModel issue) {
    state = state.copyWith(issues: [issue, ...state.issues]);
  }

  /// Remove an issue from the list
  void removeIssue(int id) {
    state = state.copyWith(
      issues: state.issues.where((i) => i.id != id).toList(),
    );
  }

  /// Called after sync to replace old local issue with synced server version
  /// This prevents duplicates when Hive migrates from UUID key to server_* key
  Future<void> refreshAfterSync({
    required String oldLocalId,
    required int newServerId,
  }) async {
    debugPrint(
      'IssueListNotifier: refreshAfterSync called - oldLocalId: $oldLocalId, newServerId: $newServerId',
    );

    // Find and remove the old local issue from state
    final updatedIssues = state.issues.where((issue) {
      // Remove old local issue (negative ID matching localId)
      if (issue.localId == oldLocalId && issue.id < 0) {
        debugPrint(
          'IssueListNotifier: Removing synced local issue $oldLocalId (id: ${issue.id})',
        );
        return false;
      }
      // Also remove any existing entry with the server ID to avoid duplicates
      if (issue.id == newServerId) {
        debugPrint(
          'IssueListNotifier: Removing existing server issue $newServerId to replace with fresh data',
        );
        return false;
      }
      return true;
    }).toList();

    // Fetch the synced issue from Hive (now under server_* key)
    try {
      final syncedIssue = await _repository.getIssue(newServerId);
      // Add the synced issue
      updatedIssues.insert(0, syncedIssue);
      // Sort by date (newest first)
      updatedIssues.sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );
      debugPrint('IssueListNotifier: Added synced issue $newServerId to list');
    } catch (e) {
      debugPrint(
        'IssueListNotifier: Warning - could not fetch synced issue $newServerId: $e',
      );
    }

    state = state.copyWith(issues: updatedIssues);
    debugPrint(
      'IssueListNotifier: State updated after sync - total issues: ${updatedIssues.length}',
    );
  }

  /// Helper to check if two DateTimes are within N minutes of each other
  bool _isWithinMinutes(DateTime? a, DateTime? b, int minutes) {
    if (a == null || b == null) return false;
    return a.difference(b).inMinutes.abs() <= minutes;
  }
}

/// Provider for issue list
final issueListProvider =
    StateNotifierProvider<IssueListNotifier, IssueListState>((ref) {
      final repository = ref.watch(issueRepositoryProvider);
      return IssueListNotifier(repository);
    });

// ============================================================================
// ISSUE DETAIL PROVIDER
// ============================================================================

/// Provider for single issue detail
///
/// Optimized to check list cache first before fetching from server.
/// This prevents unnecessary network requests and loading spinners when
/// navigating back and forth between list and detail screens.
final issueDetailProvider = FutureProvider.family<IssueModel, int>((
  ref,
  id,
) async {
  // Watch the list to be notified when it changes
  final listState = ref.watch(issueListProvider);
  final cached = listState.issues.where((i) => i.id == id).firstOrNull;

  if (cached != null) {
    // Return cached data immediately
    // If list cache was invalidated, this provider will automatically
    // trigger a rebuild with the fresh list data
    return cached;
  }

  // Not in cache, fetch from repository
  final repository = ref.read(issueRepositoryProvider);
  return repository.getIssue(id);
});

/// Provider for issue by local ID (for locally created issues)
final issueByLocalIdProvider = FutureProvider.autoDispose
    .family<IssueModel?, String>((ref, localId) async {
      final repository = ref.watch(issueRepositoryProvider);
      return repository.getIssueByLocalId(localId);
    });

// ============================================================================
// CREATE ISSUE STATE & PROVIDER
// ============================================================================

/// State for creating a new issue
class CreateIssueState {
  final bool isLoading;
  final String? error;
  final IssueModel? createdIssue;
  final bool isSuccess;

  const CreateIssueState({
    this.isLoading = false,
    this.error,
    this.createdIssue,
    this.isSuccess = false,
  });

  CreateIssueState copyWith({
    bool? isLoading,
    String? error,
    IssueModel? createdIssue,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return CreateIssueState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      createdIssue: createdIssue ?? this.createdIssue,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Create issue notifier
class CreateIssueNotifier extends StateNotifier<CreateIssueState> {
  final IssueRepository _repository;
  final Ref _ref;

  CreateIssueNotifier(this._repository, this._ref)
    : super(const CreateIssueState());

  /// Create a new issue
  Future<bool> createIssue({
    required String title,
    String? description,
    required List<int> categoryIds,
    String priority = 'medium',
    double? latitude,
    double? longitude,
    String? address,
    List<File>? mediaFiles,
  }) async {
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);

    try {
      final issue = await _repository.createIssue(
        title: title,
        description: description,
        categoryIds: categoryIds,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
        address: address,
        mediaFiles: mediaFiles,
      );

      state = CreateIssueState(createdIssue: issue, isSuccess: true);

      // Add to issue list
      _ref.read(issueListProvider.notifier).addIssue(issue);

      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.firstError ?? 'Validation failed',
      );
      return false;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e, stackTrace) {
      debugPrint('CreateIssueNotifier: Unexpected error - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create issue. Please try again.',
      );
      return false;
    }
  }

  /// Reset state (for reuse)
  void reset() {
    state = const CreateIssueState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for creating issues
final createIssueProvider =
    StateNotifierProvider.autoDispose<CreateIssueNotifier, CreateIssueState>((
      ref,
    ) {
      final repository = ref.watch(issueRepositoryProvider);
      return CreateIssueNotifier(repository, ref);
    });

// ============================================================================
// CANCEL ISSUE STATE & PROVIDER
// ============================================================================

/// State for cancelling an issue
class CancelIssueState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const CancelIssueState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });
}

/// Cancel issue notifier
class CancelIssueNotifier extends StateNotifier<CancelIssueState> {
  final IssueRepository _repository;
  final Ref _ref;

  CancelIssueNotifier(this._repository, this._ref)
    : super(const CancelIssueState());

  /// Cancel an issue
  Future<bool> cancelIssue(int id, {String? reason}) async {
    if (state.isLoading) return false;

    state = const CancelIssueState(isLoading: true);

    try {
      final cancelledIssue = await _repository.cancelIssue(id, reason: reason);

      state = const CancelIssueState(isSuccess: true);

      // Update in issue list
      _ref.read(issueListProvider.notifier).updateIssue(cancelledIssue);

      return true;
    } on ApiException catch (e) {
      state = CancelIssueState(error: e.message);
      return false;
    } catch (e) {
      debugPrint('CancelIssueNotifier: Error - $e');
      state = const CancelIssueState(
        error: 'Failed to cancel issue. Please try again.',
      );
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const CancelIssueState();
  }
}

/// Provider for cancelling issues
final cancelIssueProvider =
    StateNotifierProvider.autoDispose<CancelIssueNotifier, CancelIssueState>((
      ref,
    ) {
      final repository = ref.watch(issueRepositoryProvider);
      return CancelIssueNotifier(repository, ref);
    });

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Provider for issues loading state
final issuesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(issueListProvider).isLoading;
});

/// Provider for issues error state
final issuesErrorProvider = Provider<String?>((ref) {
  return ref.watch(issueListProvider).error;
});

/// Provider for pending sync count
final issuePendingSyncCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(issueRepositoryProvider);
  return repository.getPendingSyncCount();
});

/// Provider for active issues only
final activeIssuesProvider = Provider<List<IssueModel>>((ref) {
  return ref.watch(issueListProvider).activeIssues;
});

/// Provider for issues by status
final issuesByStatusProvider = Provider.family<List<IssueModel>, IssueStatus>((
  ref,
  status,
) {
  final issues = ref.watch(issueListProvider).issues;
  return issues.where((i) => i.status == status).toList();
});

/// Provider for issues by priority
final issuesByPriorityProvider =
    Provider.family<List<IssueModel>, IssuePriority>((ref, priority) {
      final issues = ref.watch(issueListProvider).issues;
      return issues.where((i) => i.priority == priority).toList();
    });
