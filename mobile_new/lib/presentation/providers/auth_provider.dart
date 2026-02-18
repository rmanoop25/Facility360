import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/enums/user_role.dart';

/// Auth state
class AuthState {
  final bool isLoggedIn;
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const AuthState({
    this.isLoggedIn = false,
    this.user,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isInitialized,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Auth state provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(authRepository, apiClient: apiClient);
});

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<void>? _sessionExpiredSub;

  AuthNotifier(
    this._authRepository, {
    required ApiClient apiClient,
  }) : super(const AuthState()) {
    // Listen for session expiry events from the API client.
    // When token refresh fails, the interceptor fires this stream,
    // and we force-logout so the router redirects to login.
    _sessionExpiredSub = apiClient.onSessionExpired.listen((_) {
      debugPrint('AuthNotifier: session expired — forcing logout');
      _forceLogout();
    });
  }

  /// Force logout without calling the API (token is already invalid)
  void _forceLogout() {
    if (!mounted) return;
    state = const AuthState(isInitialized: true);
  }

  @override
  void dispose() {
    _sessionExpiredSub?.cancel();
    super.dispose();
  }

  /// Initialize auth state - check for existing session on app startup
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      final user = await _authRepository.restoreSession();
      if (user != null) {
        state = AuthState(isLoggedIn: true, user: user, isInitialized: true);
      } else {
        state = const AuthState(isInitialized: true);
      }
    } catch (e) {
      state = const AuthState(isInitialized: true);
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
      );

      state = AuthState(isLoggedIn: true, user: user, isInitialized: true);
      return true;
    } on ValidationException catch (e) {
      String errorMessage = 'Invalid email or password';
      if (e.firstError != null) {
        errorMessage = e.firstError!;
        // Check if error is about inactive tenant/user
        if (errorMessage.toLowerCase().contains('inactive')) {
          errorMessage = 'auth.you_are_inactive';
        }
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } on NetworkException {
      state = state.copyWith(
        isLoading: false,
        error: 'No internet connection. Please check your network.',
      );
      return false;
    } on ApiException catch (e) {
      String errorMessage = e.message;
      // Check if error is about inactive tenant/user
      if (errorMessage.toLowerCase().contains('inactive')) {
        errorMessage = 'auth.you_are_inactive';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    // Only call API if user is actually logged in
    if (!state.isLoggedIn) {
      state = const AuthState(isInitialized: true);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      await _authRepository.logout();
    } finally {
      state = const AuthState(isInitialized: true);
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Update user data (for profile updates, etc.)
  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  // Demo login methods - use real API with seeded credentials

  /// Login as tenant (for demo/testing)
  /// Uses: tenant1@maintenance.local / password
  Future<bool> loginAsTenant() async {
    return login('tenant1@maintenance.local', 'password');
  }

  /// Login as service provider (for demo/testing)
  /// Uses: plumber@maintenance.local / password
  Future<bool> loginAsServiceProvider() async {
    return login('plumber@maintenance.local', 'password');
  }

  /// Login as super admin (for demo/testing)
  /// Uses: admin@maintenance.local / password
  Future<bool> loginAsSuperAdmin() async {
    return login('admin@maintenance.local', 'password');
  }

  /// Login as manager (for demo/testing)
  /// Uses: manager@maintenance.local / password
  Future<bool> loginAsManager() async {
    return login('manager@maintenance.local', 'password');
  }

  /// Login as viewer (for demo/testing)
  /// Uses: viewer@maintenance.local / password
  Future<bool> loginAsViewer() async {
    return login('viewer@maintenance.local', 'password');
  }
}

/// Current user provider (convenience)
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authStateProvider).user;
});

/// Is logged in provider (convenience)
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoggedIn;
});

/// User role provider (convenience)
final userRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentUserProvider)?.role;
});

/// Tracks if the app has completed initial boot
/// This provider is only reset when the app is restarted
final appInitializedProvider = StateProvider<bool>((ref) => false);
