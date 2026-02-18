import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/data/models/user_model.dart';
import '../../lib/domain/enums/user_role.dart';
import '../../lib/presentation/providers/auth_provider.dart';
import '../../lib/presentation/widgets/admin/permission_gate.dart';

/// Widget tests for all permission gate components.
///
/// Each gate must:
///   - Show child when permission is met
///   - Hide child (show fallback or SizedBox.shrink) when not met
///   - Handle null/unauthenticated user correctly
void main() {
  group('PermissionGate', () {
    testWidgets('shows child when user role is in allowedRoles', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.superAdmin),
        child: PermissionGate(
          allowedRoles: const [UserRole.superAdmin, UserRole.manager],
          child: const Text('VISIBLE'),
        ),
      ));

      expect(find.text('VISIBLE'), findsOneWidget);
    });

    testWidgets('hides child when user role is NOT in allowedRoles', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.viewer),
        child: PermissionGate(
          allowedRoles: const [UserRole.superAdmin, UserRole.manager],
          child: const Text('VISIBLE'),
        ),
      ));

      expect(find.text('VISIBLE'), findsNothing);
    });

    testWidgets('shows fallback when role is not allowed and fallback is provided', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.tenant),
        child: PermissionGate(
          allowedRoles: const [UserRole.superAdmin],
          fallback: const Text('DENIED'),
          child: const Text('VISIBLE'),
        ),
      ));

      expect(find.text('VISIBLE'), findsNothing);
      expect(find.text('DENIED'), findsOneWidget);
    });

    testWidgets('shows nothing when user is null (unauthenticated)', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: null,
        child: PermissionGate(
          allowedRoles: const [UserRole.superAdmin],
          child: const Text('VISIBLE'),
        ),
      ));

      expect(find.text('VISIBLE'), findsNothing);
    });

    testWidgets('shows fallback when user is null and fallback provided', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: null,
        child: PermissionGate(
          allowedRoles: const [UserRole.superAdmin],
          fallback: const Text('NOT_LOGGED_IN'),
          child: const Text('VISIBLE'),
        ),
      ));

      expect(find.text('VISIBLE'), findsNothing);
      expect(find.text('NOT_LOGGED_IN'), findsOneWidget);
    });
  });

  group('CanManageGate', () {
    testWidgets('shows for superAdmin', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.superAdmin),
        child: const CanManageGate(child: Text('MANAGE')),
      ));

      expect(find.text('MANAGE'), findsOneWidget);
    });

    testWidgets('shows for manager', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.manager),
        child: const CanManageGate(child: Text('MANAGE')),
      ));

      expect(find.text('MANAGE'), findsOneWidget);
    });

    testWidgets('hides for viewer', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.viewer),
        child: const CanManageGate(child: Text('MANAGE')),
      ));

      expect(find.text('MANAGE'), findsNothing);
    });

    testWidgets('hides for tenant', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.tenant),
        child: const CanManageGate(child: Text('MANAGE')),
      ));

      expect(find.text('MANAGE'), findsNothing);
    });

    testWidgets('hides for service_provider', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.serviceProvider),
        child: const CanManageGate(child: Text('MANAGE')),
      ));

      expect(find.text('MANAGE'), findsNothing);
    });
  });

  group('SuperAdminGate', () {
    testWidgets('shows only for superAdmin', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.superAdmin),
        child: const SuperAdminGate(child: Text('SUPER')),
      ));

      expect(find.text('SUPER'), findsOneWidget);
    });

    testWidgets('hides for manager', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.manager),
        child: const SuperAdminGate(child: Text('SUPER')),
      ));

      expect(find.text('SUPER'), findsNothing);
    });

    testWidgets('hides for viewer', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.viewer),
        child: const SuperAdminGate(child: Text('SUPER')),
      ));

      expect(find.text('SUPER'), findsNothing);
    });

    testWidgets('hides for tenant', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.tenant),
        child: const SuperAdminGate(child: Text('SUPER')),
      ));

      expect(find.text('SUPER'), findsNothing);
    });
  });

  group('NotReadOnlyGate', () {
    testWidgets('shows for superAdmin (not read-only)', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.superAdmin),
        child: const NotReadOnlyGate(child: Text('WRITABLE')),
      ));

      expect(find.text('WRITABLE'), findsOneWidget);
    });

    testWidgets('shows for manager (not read-only)', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.manager),
        child: const NotReadOnlyGate(child: Text('WRITABLE')),
      ));

      expect(find.text('WRITABLE'), findsOneWidget);
    });

    testWidgets('hides for viewer (read-only)', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.viewer),
        child: const NotReadOnlyGate(child: Text('WRITABLE')),
      ));

      expect(find.text('WRITABLE'), findsNothing);
    });

    testWidgets('shows for tenant (not read-only)', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.tenant),
        child: const NotReadOnlyGate(child: Text('WRITABLE')),
      ));

      expect(find.text('WRITABLE'), findsOneWidget);
    });

    testWidgets('hides when user is null', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: null,
        child: const NotReadOnlyGate(child: Text('WRITABLE')),
      ));

      expect(find.text('WRITABLE'), findsNothing);
    });
  });

  group('PermissionBasedGate', () {
    testWidgets('shows when user has the permission', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.manager, permissions: ['assign_issues']),
        child: const PermissionBasedGate(
          permission: 'assign_issues',
          child: Text('ASSIGN'),
        ),
      ));

      expect(find.text('ASSIGN'), findsOneWidget);
    });

    testWidgets('hides when user lacks the permission', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.viewer, permissions: ['view_issues']),
        child: const PermissionBasedGate(
          permission: 'assign_issues',
          child: Text('ASSIGN'),
        ),
      ));

      expect(find.text('ASSIGN'), findsNothing);
    });

    testWidgets('super_admin always has permission (bypass)', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.superAdmin, permissions: []),
        child: const PermissionBasedGate(
          permission: 'anything_at_all',
          child: Text('BYPASS'),
        ),
      ));

      expect(find.text('BYPASS'), findsOneWidget);
    });

    testWidgets('shows fallback when denied', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.viewer, permissions: []),
        child: const PermissionBasedGate(
          permission: 'delete_tenants',
          fallback: Text('NO_ACCESS'),
          child: Text('DELETE'),
        ),
      ));

      expect(find.text('DELETE'), findsNothing);
      expect(find.text('NO_ACCESS'), findsOneWidget);
    });
  });

  group('CanCreateGate', () {
    testWidgets('constructs create_<entity> permission correctly', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.manager, permissions: ['create_categories']),
        child: const CanCreateGate(
          entity: 'categories',
          child: Text('CREATE_CAT'),
        ),
      ));

      expect(find.text('CREATE_CAT'), findsOneWidget);
    });

    testWidgets('hides when user lacks create permission', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.viewer, permissions: ['view_categories']),
        child: const CanCreateGate(
          entity: 'categories',
          child: Text('CREATE_CAT'),
        ),
      ));

      expect(find.text('CREATE_CAT'), findsNothing);
    });
  });

  group('CanUpdateGate', () {
    testWidgets('constructs update_<entity> permission correctly', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.manager, permissions: ['update_tenants']),
        child: const CanUpdateGate(
          entity: 'tenants',
          child: Text('UPDATE_TENANT'),
        ),
      ));

      expect(find.text('UPDATE_TENANT'), findsOneWidget);
    });
  });

  group('CanDeleteGate', () {
    testWidgets('constructs delete_<entity> permission correctly', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.superAdmin, permissions: []),
        child: const CanDeleteGate(
          entity: 'tenants',
          child: Text('DELETE_TENANT'),
        ),
      ));

      // super_admin bypasses, so visible even with empty permissions
      expect(find.text('DELETE_TENANT'), findsOneWidget);
    });

    testWidgets('hides when non-admin lacks delete permission', (tester) async {
      await tester.pumpWidget(_buildApp(
        user: _createUser(UserRole.manager, permissions: ['view_tenants']),
        child: const CanDeleteGate(
          entity: 'tenants',
          child: Text('DELETE_TENANT'),
        ),
      ));

      expect(find.text('DELETE_TENANT'), findsNothing);
    });
  });

  group('All gates handle role transitions', () {
    testWidgets('all 5 roles are tested against PermissionGate', (tester) async {
      final allRoles = UserRole.values;

      for (final role in allRoles) {
        await tester.pumpWidget(_buildApp(
          user: _createUser(role),
          child: PermissionGate(
            allowedRoles: const [UserRole.superAdmin],
            child: const Text('TEST'),
          ),
        ));

        if (role == UserRole.superAdmin) {
          expect(find.text('TEST'), findsOneWidget,
              reason: '${role.value} should see the widget');
        } else {
          expect(find.text('TEST'), findsNothing,
              reason: '${role.value} should NOT see the widget');
        }
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds a minimal MaterialApp wrapped in ProviderScope with auth override.
Widget _buildApp({
  required UserModel? user,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => _FakeAuthNotifier(user),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// Creates a [UserModel] for testing with a given role and permissions.
UserModel _createUser(
  UserRole role, {
  List<String> permissions = const [],
}) {
  return UserModel(
    id: 1,
    name: 'Test User',
    email: 'test@test.com',
    role: role,
    roles: [role.value],
    permissions: permissions,
    isTenantFlag: role == UserRole.tenant,
    isServiceProviderFlag: role == UserRole.serviceProvider,
    isAdminFlag: role == UserRole.superAdmin ||
        role == UserRole.manager ||
        role == UserRole.viewer,
  );
}

/// Minimal fake AuthNotifier that returns a fixed auth state.
class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(UserModel? user)
      : super(AuthState(
          isLoggedIn: user != null,
          user: user,
          isLoading: false,
          isInitialized: true,
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
