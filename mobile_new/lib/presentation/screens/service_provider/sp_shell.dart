import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import 'sp_home_screen.dart';
import 'assignment_list_screen.dart';
import 'sp_profile_screen.dart';

/// Service Provider navigation shell with bottom navigation (no swipe to avoid conflict with TabBarView)
class SPShell extends ConsumerStatefulWidget {
  final Widget child;

  const SPShell({super.key, required this.child});

  @override
  ConsumerState<SPShell> createState() => _SPShellState();
}

class _SPShellState extends ConsumerState<SPShell> {
  int _currentIndex = 0;

  final _routes = [
    RoutePaths.spHome,
    RoutePaths.spAssignments,
    RoutePaths.spProfile,
  ];

  // Tab screens
  final _screens = const [
    SPHomeScreen(),
    AssignmentListScreen(),
    SPProfileScreen(),
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
    if (location.startsWith(RoutePaths.spProfile)) {
      newIndex = 2;
    } else if (location.startsWith(RoutePaths.spAssignments)) {
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
                icon: const Icon(Icons.dashboard_rounded),
                selectedIcon: const Icon(Icons.dashboard_rounded),
                label: 'nav.dashboard'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(Icons.assignment_rounded),
                selectedIcon: const Icon(Icons.assignment_rounded),
                label: 'nav.jobs'.tr(),
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
