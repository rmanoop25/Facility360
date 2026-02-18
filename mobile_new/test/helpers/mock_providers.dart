import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lib/data/models/user_model.dart';
import '../../lib/presentation/providers/auth_provider.dart';
import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Auth State Overrides
// ---------------------------------------------------------------------------

/// Creates an [AuthState] override for the given user.
///
/// Usage in widget tests:
/// ```dart
/// await tester.pumpWidget(
///   ProviderScope(
///     overrides: [authOverrideFor(TestUsers.manager)],
///     child: MaterialApp(home: MyWidget()),
///   ),
/// );
/// ```
Override authOverrideFor(UserModel user) {
  return authStateProvider.overrideWith(
    (ref) => _FakeAuthNotifier(user),
  );
}

/// Creates an [AuthState] override for an unauthenticated (logged-out) state.
Override authOverrideLoggedOut() {
  return authStateProvider.overrideWith(
    (ref) => _FakeAuthNotifier(null),
  );
}

// ---------------------------------------------------------------------------
// Fake Notifiers
// ---------------------------------------------------------------------------

/// A minimal AuthNotifier that returns a fixed user without touching the
/// real AuthRepository, API client, or secure storage.
class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(UserModel? user)
      : super(
          AuthState(
            isLoggedIn: user != null,
            user: user,
            isLoading: false,
            isInitialized: true,
          ),
        );

  // Stub all public AuthNotifier methods that might be called.

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Swallow any calls to methods we do not care about in tests.
    return null;
  }
}

// ---------------------------------------------------------------------------
// Permission Provider Overrides
// ---------------------------------------------------------------------------

/// Override hasPermissionProvider to return a fixed set of permissions.
///
/// Usage:
/// ```dart
/// ProviderScope(
///   overrides: [
///     ...permissionOverrides({'assign_issues': true, 'delete_tenants': false}),
///   ],
///   child: ...,
/// )
/// ```
List<Override> permissionOverrides(Map<String, bool> permissionMap) {
  // In practice, permission resolution flows through the auth state provider
  // and the user's hasPermission() method. Override auth state with a user
  // that has the desired permissions instead.
  final permissions = permissionMap.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toList();

  final user = createTestUser(
    permissions: permissions,
  );

  return [authOverrideFor(user)];
}
