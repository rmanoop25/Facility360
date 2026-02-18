import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/admin_dashboard_repository.dart';

// =============================================================================
// ADMIN DASHBOARD STATS PROVIDER
// =============================================================================

/// State for admin dashboard stats
class AdminDashboardState {
  final DashboardStatsModel? stats;
  final bool isLoading;
  final String? error;

  const AdminDashboardState({
    this.stats,
    this.isLoading = false,
    this.error,
  });

  bool get hasData => stats != null;
  bool get isInitialLoading => isLoading && stats == null;

  AdminDashboardState copyWith({
    DashboardStatsModel? stats,
    bool? isLoading,
    String? error,
  }) {
    return AdminDashboardState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for admin dashboard stats
class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  final AdminDashboardRepository _repository;

  AdminDashboardNotifier(this._repository) : super(const AdminDashboardState()) {
    loadStats();
  }

  /// Load dashboard statistics
  Future<void> loadStats() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final stats = await _repository.getStats();

      state = state.copyWith(
        stats: stats,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('AdminDashboardNotifier: loadStats error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh dashboard statistics
  Future<void> refresh() async {
    state = state.copyWith(error: null);
    await loadStats();
  }
}

/// Provider for admin dashboard stats
final adminDashboardProvider =
    StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>((ref) {
  final repository = ref.watch(adminDashboardRepositoryProvider);
  return AdminDashboardNotifier(repository);
});

// =============================================================================
// HELPER PROVIDERS
// =============================================================================

/// Provider for issue stats (convenient accessor)
final issueStatsProvider = Provider<IssueStatsModel?>((ref) {
  final dashboardState = ref.watch(adminDashboardProvider);
  return dashboardState.stats?.issues;
});

/// Provider for recent issues (convenient accessor)
final recentIssuesProvider = Provider<List<RecentIssueModel>>((ref) {
  final dashboardState = ref.watch(adminDashboardProvider);
  return dashboardState.stats?.recentIssues ?? [];
});
