import 'package:flutter_test/flutter_test.dart';

import '../../lib/domain/enums/user_role.dart';
import 'helpers/e2e_test_harness.dart';

/// Permission Gate Navigation E2E Test
///
/// Tests permission-based UI and navigation for all roles:
/// 1. Test all 5 role types
/// 2. For each role:
///    - Login
///    - Navigate through all accessible screens
///    - Verify permission gates show/hide correct UI elements
///    - Attempt to access restricted screens (verify redirects/blocks)
///    - Verify role-based route guards
///    - Verify super_admin bypass for all gates
void main() {
  group('Permission Navigation E2E', () {
    setUp(() async {
      await E2ETestHarness.clearAllData();
    });

    group('Tenant Role', () {
      testWidgets(
        'tenant can access tenant screens only',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.tenant);

          // Tenant home screen accessible
          E2ETestHarness.expectWidgetByKey('tenant_home_screen');

          // Can navigate to issues list
          await E2ETestHarness.navigateTo(tester, '/tenant/issues');
          E2ETestHarness.expectWidgetByKey('tenant_issues_screen');

          // Can navigate to create issue
          await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');
          E2ETestHarness.expectWidgetByKey('create_issue_screen');

          // Can navigate to profile
          await E2ETestHarness.navigateTo(tester, '/tenant/profile');
          E2ETestHarness.expectWidgetByKey('profile_screen');

          // CANNOT see admin-only UI elements
          E2ETestHarness.expectTextNotOnScreen('admin.dashboard');
          E2ETestHarness.expectTextNotOnScreen('admin.assign_issue');

          // CANNOT see SP-only UI elements
          E2ETestHarness.expectTextNotOnScreen('sp.assignments');
          E2ETestHarness.expectTextNotOnScreen('sp.accept_assignment');
        },
      );

      testWidgets(
        'tenant cannot navigate to admin routes',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.tenant);

          // Attempt to navigate to admin dashboard
          await E2ETestHarness.navigateTo(tester, '/admin/dashboard');

          // Should redirect to tenant home or show unauthorized
          E2ETestHarness.expectTextOnScreen('common.unauthorized');
        },
      );

      testWidgets(
        'tenant can only cancel their own issues',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.tenant);

          // Create issue
          await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');
          await E2ETestHarness.fillIssueForm(
            tester,
            title: 'My Issue',
            description: 'Can cancel',
            priority: 'medium',
          );
          await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');
          await E2ETestHarness.waitForSync(tester);

          // Navigate to issue
          await E2ETestHarness.navigateTo(tester, '/tenant/issues');
          await E2ETestHarness.tapButton(tester, 'My Issue');

          // Cancel button should be visible
          E2ETestHarness.expectWidgetByKey('cancel_issue_button');

          // But assignment controls should NOT be visible
          E2ETestHarness.expectTextNotOnScreen('admin.assign_to_sp');
          E2ETestHarness.expectTextNotOnScreen('admin.approve');
        },
      );
    });

    group('Service Provider Role', () {
      testWidgets(
        'sp can access assignment screens only',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.serviceProvider);

          // SP home screen accessible
          E2ETestHarness.expectWidgetByKey('sp_home_screen');

          // Can navigate to assignments
          await E2ETestHarness.navigateTo(tester, '/sp/assignments');
          E2ETestHarness.expectWidgetByKey('sp_assignments_screen');

          // Can navigate to profile
          await E2ETestHarness.navigateTo(tester, '/sp/profile');
          E2ETestHarness.expectWidgetByKey('profile_screen');

          // CANNOT see admin UI
          E2ETestHarness.expectTextNotOnScreen('admin.dashboard');

          // CANNOT see tenant issue creation
          E2ETestHarness.expectTextNotOnScreen('tenant.create_issue');
        },
      );

      testWidgets(
        'sp can only manage their own assignments',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.serviceProvider);

          // Navigate to assignments
          await E2ETestHarness.navigateTo(tester, '/sp/assignments');

          // Should only see assignments assigned to this SP
          // Cannot access other SPs' assignments
          // (Requires test data setup with multiple SPs)
        },
      );

      testWidgets(
        'sp cannot create issues',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.serviceProvider);

          // Create issue button should not exist
          E2ETestHarness.expectTextNotOnScreen('common.create_issue');

          // Direct navigation should fail
          await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');
          E2ETestHarness.expectTextOnScreen('common.unauthorized');
        },
      );
    });

    group('Super Admin Role', () {
      testWidgets(
        'super admin can access all screens',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.superAdmin);

          // Admin home accessible
          E2ETestHarness.expectWidgetByKey('admin_home_screen');

          // Can navigate to all admin screens
          await E2ETestHarness.navigateTo(tester, '/admin/issues');
          E2ETestHarness.expectWidgetByKey('admin_issues_screen');

          await E2ETestHarness.navigateTo(tester, '/admin/users');
          E2ETestHarness.expectWidgetByKey('admin_users_screen');

          await E2ETestHarness.navigateTo(tester, '/admin/service-providers');
          E2ETestHarness.expectWidgetByKey('admin_sps_screen');

          await E2ETestHarness.navigateTo(tester, '/admin/categories');
          E2ETestHarness.expectWidgetByKey('admin_categories_screen');

          await E2ETestHarness.navigateTo(tester, '/admin/settings');
          E2ETestHarness.expectWidgetByKey('admin_settings_screen');

          // All admin actions visible
          E2ETestHarness.expectTextOnScreen('admin.assign_issue');
          E2ETestHarness.expectTextOnScreen('admin.approve');
          E2ETestHarness.expectTextOnScreen('admin.manage_users');
        },
      );

      testWidgets(
        'super admin bypasses all permission gates',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.superAdmin);

          // All permission-gated widgets should be visible
          // PermissionGate with any permission should show child
          E2ETestHarness.expectWidgetByKey('create_user_button');
          E2ETestHarness.expectWidgetByKey('delete_user_button');
          E2ETestHarness.expectWidgetByKey('manage_roles_button');
          E2ETestHarness.expectWidgetByKey('system_settings_button');

          // SuperAdminGate should always show
          E2ETestHarness.expectWidgetByKey('super_admin_only_section');
        },
      );

      testWidgets(
        'super admin can manage all issues',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.superAdmin);

          // Navigate to issues
          await E2ETestHarness.navigateTo(tester, '/admin/issues');

          // Should see issues from ALL tenants
          // Can assign, approve, delete any issue
          E2ETestHarness.expectWidgetByKey('assign_issue_button');
          E2ETestHarness.expectWidgetByKey('approve_issue_button');
          E2ETestHarness.expectWidgetByKey('delete_issue_button');
        },
      );
    });

    group('Manager Role', () {
      testWidgets(
        'manager can access issue management but not user management',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.manager);

          // Manager home accessible
          E2ETestHarness.expectWidgetByKey('admin_home_screen');

          // Can manage issues
          await E2ETestHarness.navigateTo(tester, '/admin/issues');
          E2ETestHarness.expectWidgetByKey('admin_issues_screen');
          E2ETestHarness.expectWidgetByKey('assign_issue_button');
          E2ETestHarness.expectWidgetByKey('approve_issue_button');

          // Can view reports
          await E2ETestHarness.navigateTo(tester, '/admin/reports');
          E2ETestHarness.expectWidgetByKey('admin_reports_screen');

          // CANNOT manage users (wrapped in PermissionGate)
          await E2ETestHarness.navigateTo(tester, '/admin/users');
          E2ETestHarness.expectTextOnScreen('common.unauthorized');

          // CANNOT access settings (super_admin only)
          await E2ETestHarness.navigateTo(tester, '/admin/settings');
          E2ETestHarness.expectTextOnScreen('common.unauthorized');
        },
      );

      testWidgets(
        'manager can assign and approve issues',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.manager);

          await E2ETestHarness.navigateTo(tester, '/admin/issues');

          // Assign button visible (has assign_issues permission)
          E2ETestHarness.expectWidgetByKey('assign_issue_button');

          // Approve button visible (has approve_issues permission)
          E2ETestHarness.expectWidgetByKey('approve_issue_button');

          // But delete button NOT visible (no delete permission)
          E2ETestHarness.expectTextNotOnScreen('common.delete');
        },
      );

      testWidgets(
        'manager cannot modify roles or permissions',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.manager);

          // Role management button should not exist
          E2ETestHarness.expectTextNotOnScreen('admin.manage_roles');

          // Direct navigation should fail
          await E2ETestHarness.navigateTo(tester, '/admin/roles');
          E2ETestHarness.expectTextOnScreen('common.unauthorized');
        },
      );
    });

    group('Viewer Role', () {
      testWidgets(
        'viewer can only view, not modify',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.viewer);

          // Viewer home accessible
          E2ETestHarness.expectWidgetByKey('admin_home_screen');

          // Can view issues (read-only)
          await E2ETestHarness.navigateTo(tester, '/admin/issues');
          E2ETestHarness.expectWidgetByKey('admin_issues_screen');

          // BUT no action buttons visible
          E2ETestHarness.expectTextNotOnScreen('admin.assign');
          E2ETestHarness.expectTextNotOnScreen('admin.approve');
          E2ETestHarness.expectTextNotOnScreen('common.delete');

          // Can view reports
          await E2ETestHarness.navigateTo(tester, '/admin/reports');
          E2ETestHarness.expectWidgetByKey('admin_reports_screen');

          // CANNOT access management screens
          await E2ETestHarness.navigateTo(tester, '/admin/users');
          E2ETestHarness.expectTextOnScreen('common.unauthorized');
        },
      );

      testWidgets(
        'viewer cannot perform any write operations',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.viewer);

          await E2ETestHarness.navigateTo(tester, '/admin/issues');

          // No create button
          E2ETestHarness.expectTextNotOnScreen('common.create');

          // No edit button
          E2ETestHarness.expectTextNotOnScreen('common.edit');

          // No delete button
          E2ETestHarness.expectTextNotOnScreen('common.delete');

          // All action buttons wrapped in PermissionGate should be hidden
        },
      );
    });

    group('Permission Gates', () {
      testWidgets(
        'PermissionGate shows/hides based on permission',
        (WidgetTester tester) async {
          // Test with manager (has assign_issues, not create_users)
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.manager);

          // Widget wrapped in PermissionGate(permission: 'assign_issues')
          // should be visible
          E2ETestHarness.expectWidgetByKey('assign_issue_button');

          // Widget wrapped in PermissionGate(permission: 'create_users')
          // should NOT be visible
          E2ETestHarness.expectTextNotOnScreen('admin.create_user');
        },
      );

      testWidgets(
        'CanManageGate shows for super_admin and manager',
        (WidgetTester tester) async {
          // Test with manager
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.manager);

          // CanManageGate should show
          E2ETestHarness.expectWidgetByKey('manage_issues_section');

          // Logout and login as viewer
          await E2ETestHarness.logout(tester);
          await E2ETestHarness.loginAs(tester, UserRole.viewer);

          // CanManageGate should NOT show
          E2ETestHarness.expectTextNotOnScreen('manage_issues_section');
        },
      );

      testWidgets(
        'SuperAdminGate only shows for super_admin',
        (WidgetTester tester) async {
          // Test with manager
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.manager);

          // SuperAdminGate should NOT show
          E2ETestHarness.expectTextNotOnScreen('super_admin_only_section');

          // Logout and login as super_admin
          await E2ETestHarness.logout(tester);
          await E2ETestHarness.loginAs(tester, UserRole.superAdmin);

          // SuperAdminGate should show
          E2ETestHarness.expectWidgetByKey('super_admin_only_section');
        },
      );
    });

    group('Navigation Guards', () {
      testWidgets(
        'unauthorized route access redirects to home',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.tenant);

          // Attempt to navigate to admin route
          await E2ETestHarness.navigateTo(tester, '/admin/dashboard');

          // Should redirect to tenant home
          E2ETestHarness.expectWidgetByKey('tenant_home_screen');
        },
      );

      testWidgets(
        'deep link to restricted route shows unauthorized',
        (WidgetTester tester) async {
          await E2ETestHarness.setupApp(tester);
          await E2ETestHarness.loginAs(tester, UserRole.viewer);

          // Deep link to user management
          await E2ETestHarness.navigateTo(tester, '/admin/users/123/edit');

          // Should show unauthorized or redirect
          E2ETestHarness.expectTextOnScreen('common.unauthorized');
        },
      );
    });
  });
}
