import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show navigatorKey;
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/tenant/tenant_shell.dart';
import '../../presentation/screens/tenant/tenant_home_screen.dart';
import '../../presentation/screens/tenant/issue_list_screen.dart';
import '../../presentation/screens/tenant/issue_detail_screen.dart';
import '../../presentation/screens/tenant/create_issue_screen.dart';
import '../../presentation/screens/tenant/tenant_profile_screen.dart';
import '../../presentation/screens/service_provider/sp_shell.dart';
import '../../presentation/screens/service_provider/sp_home_screen.dart';
import '../../presentation/screens/service_provider/assignment_list_screen.dart';
import '../../presentation/screens/service_provider/assignment_detail_screen.dart';
import '../../presentation/screens/service_provider/work_execution_screen.dart';
import '../../presentation/screens/service_provider/sp_profile_screen.dart';
import '../../presentation/screens/admin/admin_shell.dart';
import '../../presentation/screens/admin/admin_home_screen.dart';
import '../../presentation/screens/admin/admin_issues_screen.dart';
import '../../presentation/screens/admin/admin_issue_detail_screen.dart';
import '../../presentation/screens/admin/assign_issue_screen.dart';
import '../../presentation/screens/admin/approve_work_screen.dart';
import '../../presentation/screens/admin/management_hub_screen.dart';
import '../../presentation/screens/admin/tenants_list_screen.dart';
import '../../presentation/screens/admin/tenant_form_screen.dart';
import '../../presentation/screens/admin/sp_list_screen.dart';
import '../../presentation/screens/admin/sp_form_screen.dart';
import '../../presentation/screens/admin/time_slots_screen.dart';
import '../../presentation/screens/admin/categories_screen.dart';
import '../../presentation/screens/admin/category_form_screen.dart';
import '../../presentation/screens/admin/consumables_screen.dart';
import '../../presentation/screens/admin/consumable_form_screen.dart';
import '../../presentation/screens/admin/admin_users_screen.dart';
import '../../presentation/screens/admin/admin_user_form_screen.dart';
import '../../presentation/screens/admin/admin_profile_screen.dart';
import '../../presentation/screens/admin/calendar_screen.dart';
import '../../data/models/issue_model.dart';
import '../../presentation/screens/admin/admin_create_issue_screen.dart';
import '../../presentation/screens/admin/admin_edit_issue_screen.dart';
import '../../presentation/screens/admin/edit_assignment_screen.dart';
import '../../presentation/screens/admin/time_extensions_screen.dart';
import '../../presentation/screens/admin/time_extension_detail_screen.dart';
import '../../presentation/screens/common/privacy_policy_screen.dart';
import '../../presentation/screens/common/terms_of_service_screen.dart';

/// Notifier for router refresh on auth state changes
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// Router notifier provider
final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Route paths
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';

  // Tenant routes
  static const String tenantHome = '/tenant';
  static const String tenantIssues = '/tenant/issues';
  static const String tenantIssueDetail = '/tenant/issues/:id';
  static const String tenantLocalIssueDetail = '/tenant/issues/local/:localId';
  static const String tenantCreateIssue = '/tenant/issues/create';
  static const String tenantProfile = '/tenant/profile';

  // Service Provider routes
  static const String spHome = '/sp';
  static const String spAssignments = '/sp/assignments';
  static const String spAssignmentDetail = '/sp/assignments/:id';
  static const String spWorkExecution = '/sp/assignments/:id/work';
  static const String spProfile = '/sp/profile';

  // Admin routes
  static const String adminHome = '/admin';
  static const String adminIssues = '/admin/issues';
  static const String adminCreateIssue = '/admin/issues/create';
  static const String adminIssueDetail = '/admin/issues/:id';
  static const String adminEditIssue = '/admin/issues/:id/edit';
  static const String adminAssignIssue = '/admin/issues/:id/assign';
  static const String adminApproveWork = '/admin/issues/:id/approve';
  static const String adminEditAssignment =
      '/admin/issues/:issueId/assignments/:assignmentId/edit';
  static const String adminManagement = '/admin/management';
  static const String adminTenants = '/admin/tenants';
  static const String adminTenantForm = '/admin/tenants/form';
  static const String adminSPs = '/admin/service-providers';
  static const String adminSPForm = '/admin/service-providers/form';
  static const String adminTimeSlots = '/admin/service-providers/:id/slots';
  static const String adminCategories = '/admin/categories';
  static const String adminCategoryForm = '/admin/categories/form';
  static const String adminConsumables = '/admin/consumables';
  static const String adminConsumableForm = '/admin/consumables/form';
  static const String adminAdminUsers = '/admin/users';
  static const String adminAdminUserForm = '/admin/users/form';
  static const String adminProfile = '/admin/profile';
  static const String adminCalendar = '/admin/calendar';
  static const String adminTimeExtensions = '/admin/time-extensions';
  static const String adminTimeExtensionDetail = '/admin/time-extensions/:id';

  // Common routes (accessible by all roles)
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,

    // Redirect logic based on auth state
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isInitialized = ref.read(appInitializedProvider);
      final isLoggedIn = authState.isLoggedIn;
      final user = authState.user;
      final isOnSplash = state.matchedLocation == RoutePaths.splash;
      final isOnLogin = state.matchedLocation == RoutePaths.login;

      // If app not initialized yet, only allow splash screen
      if (!isInitialized) {
        return isOnSplash ? null : RoutePaths.splash;
      }

      // After initialization, never go back to splash
      if (isOnSplash) {
        if (isLoggedIn && user != null) {
          return user.homeRoute; // Uses userType for dynamic role support
        }
        return RoutePaths.login;
      }

      // If not logged in, redirect to login (except if already there)
      if (!isLoggedIn) {
        return isOnLogin ? null : RoutePaths.login;
      }

      // If logged in and on login page, redirect to appropriate home
      if (isOnLogin) {
        return user?.role.homeRoute ?? RoutePaths.tenantHome;
      }

      // Check role-based access
      if (user != null) {
        final currentPath = state.matchedLocation;

        // Tenant trying to access SP or admin routes
        if (user.isTenant) {
          if (currentPath.startsWith('/sp') ||
              currentPath.startsWith('/admin')) {
            return RoutePaths.tenantHome;
          }
        }

        // SP trying to access tenant or admin routes
        if (user.isServiceProvider) {
          if (currentPath.startsWith('/tenant') ||
              currentPath.startsWith('/admin')) {
            return RoutePaths.spHome;
          }
        }

        // Admin trying to access tenant or SP routes
        if (user.isAdmin) {
          if (currentPath.startsWith('/tenant') ||
              currentPath.startsWith('/sp')) {
            return RoutePaths.adminHome;
          }
        }
      }

      return null;
    },

    routes: [
      // Splash screen
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Login screen
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Tenant routes with shell (only tabs that show bottom nav)
      ShellRoute(
        builder: (context, state, child) => TenantShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.tenantHome,
            builder: (context, state) => const TenantHomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.tenantIssues,
            builder: (context, state) => const IssueListScreen(),
          ),
          GoRoute(
            path: RoutePaths.tenantProfile,
            builder: (context, state) => const TenantProfileScreen(),
          ),
        ],
      ),

      // Tenant full-screen routes (no bottom nav)
      // Note: Create and local routes must come before :id route to avoid matching as an ID
      GoRoute(
        path: RoutePaths.tenantCreateIssue,
        builder: (context, state) => const CreateIssueScreen(),
      ),
      GoRoute(
        path: RoutePaths.tenantLocalIssueDetail,
        builder: (context, state) {
          final localId = state.pathParameters['localId']!;
          return IssueDetailScreen(issueId: localId, isLocalId: true);
        },
      ),
      GoRoute(
        path: RoutePaths.tenantIssueDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return IssueDetailScreen(issueId: id);
        },
      ),

      // Service Provider routes with shell (only tabs that show bottom nav)
      ShellRoute(
        builder: (context, state, child) => SPShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.spHome,
            builder: (context, state) => const SPHomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.spAssignments,
            builder: (context, state) => const AssignmentListScreen(),
          ),
          GoRoute(
            path: RoutePaths.spProfile,
            builder: (context, state) => const SPProfileScreen(),
          ),
        ],
      ),

      // SP full-screen routes (no bottom nav)
      // Note: Work execution route must come before :id route
      GoRoute(
        path: RoutePaths.spWorkExecution,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WorkExecutionScreen(assignmentId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.spAssignmentDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AssignmentDetailScreen(assignmentId: id);
        },
      ),

      // Admin routes with shell (tabs that show bottom nav)
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.adminHome,
            builder: (context, state) => const AdminHomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminIssues,
            builder: (context, state) => const AdminIssuesScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminManagement,
            builder: (context, state) => const ManagementHubScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminProfile,
            builder: (context, state) => const AdminProfileScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminCalendar,
            builder: (context, state) => const CalendarScreen(),
          ),
          // Management sub-screens (still show bottom nav)
          GoRoute(
            path: RoutePaths.adminTenants,
            builder: (context, state) => const TenantsListScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminSPs,
            builder: (context, state) => const SPListScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminCategories,
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminConsumables,
            builder: (context, state) => const ConsumablesScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminAdminUsers,
            builder: (context, state) => const AdminUsersScreen(),
          ),
        ],
      ),

      // Admin full-screen routes (no bottom nav)
      // Note: Create route must come before :id route to avoid matching "create" as an ID
      GoRoute(
        path: RoutePaths.adminCreateIssue,
        builder: (context, state) => const AdminCreateIssueScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminEditIssue,
        builder: (context, state) {
          final issue = state.extra as IssueModel;
          return AdminEditIssueScreen(issue: issue);
        },
      ),
      GoRoute(
        path: RoutePaths.adminIssueDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AdminIssueDetailScreen(issueId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.adminAssignIssue,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AssignIssueScreen(issueId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.adminApproveWork,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ApproveWorkScreen(issueId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.adminEditAssignment,
        builder: (context, state) {
          final issueId = state.pathParameters['issueId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return EditAssignmentScreen(
            issueId: issueId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.adminTenantForm,
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['id'];
          return TenantFormScreen(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminSPForm,
        builder: (context, state) {
          final spId = state.uri.queryParameters['id'];
          return SPFormScreen(spId: spId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminTimeSlots,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TimeSlotsScreen(spId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.adminCategoryForm,
        builder: (context, state) {
          final categoryId = state.uri.queryParameters['id'];
          final parentId = state.uri.queryParameters['parent_id'];
          return CategoryFormScreen(categoryId: categoryId, parentId: parentId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminConsumableForm,
        builder: (context, state) {
          final consumableId = state.uri.queryParameters['id'];
          return ConsumableFormScreen(consumableId: consumableId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminAdminUserForm,
        builder: (context, state) {
          final userId = state.uri.queryParameters['id'];
          return AdminUserFormScreen(userId: userId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminTimeExtensions,
        builder: (context, state) => const TimeExtensionsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminTimeExtensionDetail,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TimeExtensionDetailScreen(extensionId: id);
        },
      ),

      // Common routes accessible by all roles
      GoRoute(
        path: RoutePaths.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.termsOfService,
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'errors.page_not_found'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.matchedLocation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.splash),
              child: Text('common.go_home'.tr()),
            ),
          ],
        ),
      ),
    ),
  );
});
