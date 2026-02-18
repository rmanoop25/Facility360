import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import 'admin_home_screen.dart';
import 'admin_issues_screen.dart';
import 'management_hub_screen.dart';
import 'admin_profile_screen.dart';

/// Admin navigation shell with bottom navigation (no swipe to avoid conflict with TabBarView)
/// - Dashboard
/// - Issues
/// - Management
/// - Profile
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _currentIndex = 0;

  final _routes = [
    RoutePaths.adminHome,
    RoutePaths.adminIssues,
    RoutePaths.adminManagement,
    RoutePaths.adminProfile,
  ];

  // Tab screens
  final _screens = const [
    AdminHomeScreen(),
    AdminIssuesScreen(),
    ManagementHubScreen(),
    AdminProfileScreen(),
  ];

  void _onNavTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  int _getIndexFromRoute(String location) {
    if (location.startsWith(RoutePaths.adminProfile)) {
      return 3;
    } else if (location.startsWith(RoutePaths.adminManagement) ||
        location.startsWith(RoutePaths.adminTenants) ||
        location.startsWith(RoutePaths.adminSPs) ||
        location.startsWith(RoutePaths.adminCategories) ||
        location.startsWith(RoutePaths.adminConsumables) ||
        location.startsWith(RoutePaths.adminAdminUsers) ||
        location.startsWith(RoutePaths.adminCalendar)) {
      return 2;
    } else if (location.startsWith(RoutePaths.adminIssues)) {
      return 1;
    } else if (location.startsWith(RoutePaths.adminHome)) {
      return 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Get the actual current path from GoRouter (not the shell's matched location)
    final location = GoRouter.of(context).routeInformationProvider.value.uri.path;
    final isSubScreen = _isManagementSubScreen(location);

    // Sync the current index with the route on every build
    // This ensures navigation from within screens updates the tab properly
    final routeIndex = _getIndexFromRoute(location);
    if (routeIndex != _currentIndex) {
      // Use post-frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && routeIndex != _currentIndex) {
          setState(() => _currentIndex = routeIndex);
        }
      });
    }

    return Scaffold(
      body: isSubScreen
          ? widget.child // Show the actual routed screen
          : IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  bool _isManagementSubScreen(String location) {
    return location.startsWith(RoutePaths.adminTenants) ||
        location.startsWith(RoutePaths.adminSPs) ||
        location.startsWith(RoutePaths.adminCategories) ||
        location.startsWith(RoutePaths.adminConsumables) ||
        location.startsWith(RoutePaths.adminAdminUsers) ||
        location.startsWith(RoutePaths.adminCalendar);
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: context.bottomNavShadow,
      ),
      child: SafeArea(
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavTapped,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_rounded),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: 'nav.dashboard'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.assignment_rounded),
              selectedIcon: const Icon(Icons.assignment_rounded),
              label: 'nav.issues'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_rounded),
              selectedIcon: const Icon(Icons.grid_view_rounded),
              label: 'nav.manage'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: 'nav.profile'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
