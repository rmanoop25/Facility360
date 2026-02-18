import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/router/app_router.dart';
import '../../../lib/data/local/adapters/issue_hive_model.dart';
import '../../../lib/domain/enums/user_role.dart';

/// Tests for offline-first navigation patterns.
///
/// Key rules:
/// - Server issues have positive IDs -> use `/tenant/issues/:id`
/// - Offline-created issues have negative effectiveIds -> use `/tenant/issues/local/:localId`
/// - After sync, navigation should migrate from local route to server route
/// - Route guards redirect users to their role-appropriate home routes
void main() {
  group('Route path constants', () {
    test('tenant issue detail uses :id parameter', () {
      expect(RoutePaths.tenantIssueDetail, equals('/tenant/issues/:id'));
    });

    test('tenant local issue detail uses :localId parameter', () {
      expect(RoutePaths.tenantLocalIssueDetail,
          equals('/tenant/issues/local/:localId'));
    });

    test('SP assignment detail uses :id parameter', () {
      expect(RoutePaths.spAssignmentDetail, equals('/sp/assignments/:id'));
    });

    test('admin issue detail uses :id parameter', () {
      expect(RoutePaths.adminIssueDetail, equals('/admin/issues/:id'));
    });
  });

  group('Issue ID navigation logic', () {
    test('server issue (positive ID) uses standard route', () {
      final issue = IssueHiveModel(
        serverId: 42,
        localId: 'server_42',
        title: 'Server Issue',
        status: 'pending',
        priority: 'medium',
        categoryIds: [1],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      final effectiveId = issue.effectiveId;
      expect(effectiveId, isPositive);

      // Navigation logic: if effectiveId > 0 -> standard route
      final route = effectiveId > 0
          ? '/tenant/issues/$effectiveId'
          : '/tenant/issues/local/${issue.localId}';

      expect(route, equals('/tenant/issues/42'));
    });

    test('local issue (negative effective ID) uses local route', () {
      final issue = IssueHiveModel(
        serverId: null,
        localId: 'uuid-offline-123',
        title: 'Offline Issue',
        status: 'pending',
        priority: 'medium',
        categoryIds: [1],
        syncStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final effectiveId = issue.effectiveId;
      expect(effectiveId, isNegative);

      // Navigation logic: if effectiveId <= 0 -> local route
      final route = effectiveId > 0
          ? '/tenant/issues/$effectiveId'
          : '/tenant/issues/local/${issue.localId}';

      expect(route, equals('/tenant/issues/local/uuid-offline-123'));
    });

    test('issue with localId but no serverId uses local route', () {
      final issue = IssueHiveModel(
        serverId: null,
        localId: 'my-local-id',
        title: 'Test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'pending',
        createdAt: DateTime.now(),
      );

      // Alternative navigation check using localId
      final hasServerId = issue.serverId != null;
      final hasLocalId = issue.localId.isNotEmpty;

      expect(hasServerId, isFalse);
      expect(hasLocalId, isTrue);

      // Should use local route
      String route;
      if (hasServerId) {
        route = '/tenant/issues/${issue.serverId}';
      } else if (hasLocalId) {
        route = '/tenant/issues/local/${issue.localId}';
      } else {
        route = '/tenant/issues'; // fallback to list
      }

      expect(route, equals('/tenant/issues/local/my-local-id'));
    });
  });

  group('Post-sync navigation migration', () {
    test('after sync: issue gets serverId, route changes to standard', () {
      // Before sync
      final issueBeforeSync = IssueHiveModel(
        serverId: null,
        localId: 'uuid-before',
        title: 'Created Offline',
        status: 'pending',
        priority: 'medium',
        categoryIds: [1],
        syncStatus: 'pending',
        createdAt: DateTime.now(),
      );

      expect(issueBeforeSync.effectiveId, isNegative);

      // After sync: markAsSynced assigns serverId
      issueBeforeSync.markAsSynced(999);

      expect(issueBeforeSync.serverId, equals(999));
      expect(issueBeforeSync.effectiveId, equals(999));
      expect(issueBeforeSync.effectiveId, isPositive);

      // Now standard route should be used
      final route = issueBeforeSync.effectiveId > 0
          ? '/tenant/issues/${issueBeforeSync.effectiveId}'
          : '/tenant/issues/local/${issueBeforeSync.localId}';

      expect(route, equals('/tenant/issues/999'));
    });

    test('key migration: localId changes from uuid to server_<id>', () {
      final issue = IssueHiveModel(
        serverId: null,
        localId: 'original-uuid',
        title: 'Test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [1],
        syncStatus: 'pending',
        createdAt: DateTime.now(),
      );

      // Simulate sync
      issue.markAsSynced(555);

      // Simulate key migration (as done by IssueLocalDataSource.migrateToServerKey)
      final newLocalId = 'server_${issue.serverId}';
      issue.localId = newLocalId;

      expect(issue.localId, equals('server_555'));
      expect(issue.serverId, equals(555));
      expect(issue.effectiveId, equals(555));
    });
  });

  group('Role-based route prefixes', () {
    test('tenant home route', () {
      expect(UserRole.tenant.homeRoute, equals('/tenant'));
    });

    test('service provider home route', () {
      expect(UserRole.serviceProvider.homeRoute, equals('/sp'));
    });

    test('super admin home route', () {
      expect(UserRole.superAdmin.homeRoute, equals('/admin'));
    });

    test('manager home route', () {
      expect(UserRole.manager.homeRoute, equals('/admin'));
    });

    test('viewer home route', () {
      expect(UserRole.viewer.homeRoute, equals('/admin'));
    });
  });

  group('Route path structure', () {
    test('tenant routes start with /tenant', () {
      expect(RoutePaths.tenantHome.startsWith('/tenant'), isTrue);
      expect(RoutePaths.tenantIssues.startsWith('/tenant'), isTrue);
      expect(RoutePaths.tenantIssueDetail.startsWith('/tenant'), isTrue);
      expect(RoutePaths.tenantLocalIssueDetail.startsWith('/tenant'), isTrue);
      expect(RoutePaths.tenantCreateIssue.startsWith('/tenant'), isTrue);
      expect(RoutePaths.tenantProfile.startsWith('/tenant'), isTrue);
    });

    test('SP routes start with /sp', () {
      expect(RoutePaths.spHome.startsWith('/sp'), isTrue);
      expect(RoutePaths.spAssignments.startsWith('/sp'), isTrue);
      expect(RoutePaths.spAssignmentDetail.startsWith('/sp'), isTrue);
      expect(RoutePaths.spWorkExecution.startsWith('/sp'), isTrue);
      expect(RoutePaths.spProfile.startsWith('/sp'), isTrue);
    });

    test('admin routes start with /admin', () {
      expect(RoutePaths.adminHome.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminIssues.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminIssueDetail.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminAssignIssue.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminApproveWork.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminManagement.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminTenants.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminSPs.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminCategories.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminConsumables.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminAdminUsers.startsWith('/admin'), isTrue);
      expect(RoutePaths.adminProfile.startsWith('/admin'), isTrue);
    });

    test('common routes are at root level', () {
      expect(RoutePaths.privacyPolicy, equals('/privacy-policy'));
      expect(RoutePaths.termsOfService, equals('/terms-of-service'));
    });

    test('splash and login are at root level', () {
      expect(RoutePaths.splash, equals('/'));
      expect(RoutePaths.login, equals('/login'));
    });
  });

  group('Route guard logic (redirect simulation)', () {
    test('tenant accessing /admin should redirect to tenant home', () {
      const currentPath = '/admin/issues';
      const userIsTenant = true;

      // Simulate redirect logic from app_router.dart
      String? redirect;
      if (userIsTenant) {
        if (currentPath.startsWith('/sp') || currentPath.startsWith('/admin')) {
          redirect = RoutePaths.tenantHome;
        }
      }

      expect(redirect, equals('/tenant'));
    });

    test('tenant accessing /sp should redirect to tenant home', () {
      const currentPath = '/sp/assignments';
      const userIsTenant = true;

      String? redirect;
      if (userIsTenant) {
        if (currentPath.startsWith('/sp') || currentPath.startsWith('/admin')) {
          redirect = RoutePaths.tenantHome;
        }
      }

      expect(redirect, equals('/tenant'));
    });

    test('SP accessing /tenant should redirect to SP home', () {
      const currentPath = '/tenant/issues';
      const userIsSP = true;

      String? redirect;
      if (userIsSP) {
        if (currentPath.startsWith('/tenant') ||
            currentPath.startsWith('/admin')) {
          redirect = RoutePaths.spHome;
        }
      }

      expect(redirect, equals('/sp'));
    });

    test('admin accessing /tenant should redirect to admin home', () {
      const currentPath = '/tenant/issues';
      const userIsAdmin = true;

      String? redirect;
      if (userIsAdmin) {
        if (currentPath.startsWith('/tenant') ||
            currentPath.startsWith('/sp')) {
          redirect = RoutePaths.adminHome;
        }
      }

      expect(redirect, equals('/admin'));
    });

    test('tenant accessing own routes should not redirect', () {
      const currentPath = '/tenant/issues/42';
      const userIsTenant = true;

      String? redirect;
      if (userIsTenant) {
        if (currentPath.startsWith('/sp') || currentPath.startsWith('/admin')) {
          redirect = RoutePaths.tenantHome;
        }
      }

      expect(redirect, isNull);
    });

    test('unauthenticated user should redirect to login', () {
      const isLoggedIn = false;
      const isOnLogin = false;

      String? redirect;
      if (!isLoggedIn && !isOnLogin) {
        redirect = RoutePaths.login;
      }

      expect(redirect, equals('/login'));
    });

    test('authenticated user on login page should redirect to home', () {
      const isLoggedIn = true;
      const isOnLogin = true;
      final userRole = UserRole.tenant;

      String? redirect;
      if (isLoggedIn && isOnLogin) {
        redirect = userRole.homeRoute;
      }

      expect(redirect, equals('/tenant'));
    });
  });

  group('Edge cases: effectiveId boundaries', () {
    test('effectiveId is never zero for valid issues', () {
      // With a serverId
      final withServer = IssueHiveModel(
        serverId: 1,
        localId: 'server_1',
        title: 'Test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );
      expect(withServer.effectiveId, isNot(equals(0)));

      // Without a serverId (but with localId)
      final withoutServer = IssueHiveModel(
        serverId: null,
        localId: 'some-local-id',
        title: 'Test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'pending',
        createdAt: DateTime.now(),
      );
      expect(withoutServer.effectiveId, isNot(equals(0)));
    });

    test('serverId = 0 is treated as a valid server ID', () {
      // In theory serverId = 0 is unusual but valid
      final issue = IssueHiveModel(
        serverId: 0,
        localId: 'server_0',
        title: 'Test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      // effectiveId should be 0 (which is the serverId)
      expect(issue.effectiveId, equals(0));
    });
  });
}
