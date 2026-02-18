import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/user_role.dart';
import 'auth_provider.dart';
import 'issue_provider.dart';
import 'assignment_provider.dart';
import 'admin_dashboard_provider.dart';
import 'admin_issue_provider.dart';
import 'category_provider.dart';

/// State for app initialization after login
class AppInitState {
  final bool isInitializing;
  final bool isInitialized;
  final String? error;

  const AppInitState({
    this.isInitializing = false,
    this.isInitialized = false,
    this.error,
  });

  AppInitState copyWith({
    bool? isInitializing,
    bool? isInitialized,
    String? error,
    bool clearError = false,
  }) {
    return AppInitState(
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for app initialization
///
/// Performs parallel data fetching after login to improve perceived performance.
/// This ensures that when the user lands on their home screen, data is already
/// loading or available, reducing the time they see skeleton/shimmer UI.
class AppInitNotifier extends StateNotifier<AppInitState> {
  final Ref _ref;

  AppInitNotifier(this._ref) : super(const AppInitState());

  /// Initialize app data based on user role
  ///
  /// This should be called after successful login to prefetch role-specific data.
  /// All fetches run in parallel for optimal performance.
  Future<void> initialize() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      debugPrint('AppInitNotifier: No user found, skipping initialization');
      return;
    }

    if (state.isInitializing || state.isInitialized) {
      debugPrint('AppInitNotifier: Already initialized or initializing');
      return;
    }

    state = state.copyWith(isInitializing: true, clearError: true);
    debugPrint('AppInitNotifier: Starting parallel data fetch for ${user.role.name}');

    try {
      // Fetch categories (used by all roles)
      final categoryFuture = _fetchCategories();

      // Role-specific data fetching (all in parallel)
      final List<Future<void>> futures = [categoryFuture];

      switch (user.role) {
        case UserRole.tenant:
          // Tenant: fetch their issues
          futures.add(_fetchTenantData());
          break;

        case UserRole.serviceProvider:
          // Service Provider: fetch their assignments
          futures.add(_fetchServiceProviderData());
          break;

        case UserRole.superAdmin:
        case UserRole.manager:
        case UserRole.viewer:
          // Admin roles: fetch dashboard stats and issues
          futures.add(_fetchAdminData());
          break;
      }

      // Wait for all fetches to complete (or fail gracefully)
      await Future.wait(futures, eagerError: false);

      state = state.copyWith(isInitializing: false, isInitialized: true);
      debugPrint('AppInitNotifier: Initialization complete');
    } catch (e) {
      debugPrint('AppInitNotifier: Initialization error - $e');
      // Don't block the user - they can still use the app with cached data
      state = state.copyWith(
        isInitializing: false,
        isInitialized: true,
        error: e.toString(),
      );
    }
  }

  /// Fetch categories (used by all roles for creating/viewing issues)
  Future<void> _fetchCategories() async {
    try {
      await _ref.read(categoriesStateProvider.notifier).fetchCategories();
      debugPrint('AppInitNotifier: Categories fetched');
    } catch (e) {
      debugPrint('AppInitNotifier: Categories fetch failed - $e');
      // Don't throw - categories will be fetched on demand
    }
  }

  /// Fetch tenant-specific data
  Future<void> _fetchTenantData() async {
    try {
      // Issues are loaded automatically by the provider's init
      // But we can trigger a refresh to ensure fresh data
      await _ref.read(issueListProvider.notifier).loadIssues();
      debugPrint('AppInitNotifier: Tenant issues fetched');
    } catch (e) {
      debugPrint('AppInitNotifier: Tenant data fetch failed - $e');
      // Don't throw - cached data will be shown
    }
  }

  /// Fetch service provider-specific data
  Future<void> _fetchServiceProviderData() async {
    try {
      // Assignments are loaded automatically by the provider's init
      await _ref.read(assignmentListProvider.notifier).loadAssignments();
      debugPrint('AppInitNotifier: SP assignments fetched');
    } catch (e) {
      debugPrint('AppInitNotifier: SP data fetch failed - $e');
      // Don't throw - cached data will be shown
    }
  }

  /// Fetch admin-specific data
  Future<void> _fetchAdminData() async {
    try {
      // Fetch dashboard stats and issues in parallel
      await Future.wait([
        _ref.read(adminDashboardProvider.notifier).loadStats(),
        _ref.read(adminIssueListProvider.notifier).loadIssues(),
      ], eagerError: false);
      debugPrint('AppInitNotifier: Admin data fetched');
    } catch (e) {
      debugPrint('AppInitNotifier: Admin data fetch failed - $e');
      // Don't throw - screen will show loading state
    }
  }

  /// Reset initialization state (call on logout)
  void reset() {
    state = const AppInitState();
  }
}

/// Provider for app initialization
final appInitProvider =
    StateNotifierProvider<AppInitNotifier, AppInitState>((ref) {
  return AppInitNotifier(ref);
});

/// Convenience provider to check if app is initialized
final isAppInitializedProvider = Provider<bool>((ref) {
  return ref.watch(appInitProvider).isInitialized;
});

/// Convenience provider to check if app is initializing
final isAppInitializingProvider = Provider<bool>((ref) {
  return ref.watch(appInitProvider).isInitializing;
});
