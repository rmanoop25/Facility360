import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import 'tenant_home_screen.dart';
import 'issue_list_screen.dart';
import 'tenant_profile_screen.dart';

/// Tenant navigation shell with bottom navigation (no swipe to avoid conflict with TabBarView)
class TenantShell extends ConsumerStatefulWidget {
  final Widget child;

  const TenantShell({super.key, required this.child});

  @override
  ConsumerState<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends ConsumerState<TenantShell> {
  int _currentIndex = 0;

  final _routes = [
    RoutePaths.tenantHome,
    RoutePaths.tenantIssues,
    RoutePaths.tenantProfile,
  ];

  // Tab screens
  final _screens = const [
    TenantHomeScreen(),
    IssueListScreen(),
    TenantProfileScreen(),
  ];

  void _onNavTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update selected index based on current route (for deep linking)
    final location = GoRouterState.of(context).matchedLocation;
    int newIndex = 0;
    if (location.startsWith(RoutePaths.tenantProfile)) {
      newIndex = 2;
    } else if (location.startsWith(RoutePaths.tenantIssues)) {
      newIndex = 1;
    }

    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
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
                icon: const Icon(Icons.home_rounded),
                selectedIcon: const Icon(Icons.home_rounded),
                label: 'nav.home'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(Icons.assignment_rounded),
                selectedIcon: const Icon(Icons.assignment_rounded),
                label: 'nav.issues'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: 'nav.profile'.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
