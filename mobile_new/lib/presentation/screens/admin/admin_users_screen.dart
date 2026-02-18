import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/enums/user_role.dart';
import '../../../mock/mock_data.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin/role_badge.dart';

/// Admin Users Screen (Super Admin only)
/// List and manage admin users (Super Admin, Manager, Viewer) with swipeable tabs
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Mock admin users
  final _mockAdminUsers = [
    MockData.superAdminUser,
    MockData.managerUser,
    MockData.viewerUser,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  Future<void> _onRefresh() async {
    // Trigger rebuild to "refresh" mock data
    setState(() {});
    // Future: Replace with actual API call
    // await ref.read(someProvider.notifier).refresh();
  }

  /// Local filtering - no API call on tab change
  List<dynamic> _getFilteredUsers(int tabIndex) {
    var users = _mockAdminUsers.toList();

    // Filter by tab (role)
    users = switch (tabIndex) {
      0 => users, // All
      1 => users.where((u) => u.role == UserRole.superAdmin).toList(),
      2 => users.where((u) => u.role == UserRole.manager).toList(),
      3 => users.where((u) => u.role == UserRole.viewer).toList(),
      _ => users,
    };

    // Filter by search (local filter)
    if (_searchQuery.isNotEmpty) {
      users = users.where((u) {
        final name = u.name.toLowerCase();
        final email = u.email.toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }

    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('admin_users.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'common.all'.tr()),
            Tab(text: 'roles.super_admin'.tr()),
            Tab(text: 'roles.manager'.tr()),
            Tab(text: 'roles.viewer'.tr()),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: AppSpacing.allLg,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'admin_users.search'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Info banner
          Container(
            margin: AppSpacing.horizontalLg,
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: context.colors.infoBg,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.colors.info, size: 20),
                AppSpacing.gapMd,
                Expanded(
                  child: Text(
                    'admin_users.info'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.vGapMd,

          // Admin users list with TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(4, (tabIndex) {
                final filteredUsers = _getFilteredUsers(tabIndex);

                if (filteredUsers.isEmpty) {
                  return _EmptyState(tabIndex: tabIndex);
                }

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    padding: AppSpacing.horizontalLg,
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _AdminUserCard(
                          user: user,
                          onTap: () => _showUserDetails(user),
                          onLongPress: () => _showUserActions(user),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${RoutePaths.adminAdminUsers}/form'),
        icon: const Icon(Icons.add),
        label: Text('admin_users.add'.tr()),
      ),
    );
  }

  void _showUserDetails(dynamic user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                  child: Text(
                    user.name[0],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
                AppSpacing.gapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.vGapXs,
                      RoleBadge(role: user.role),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.vGapXl,
            _DetailRow(icon: Icons.email_outlined, label: 'profile.email'.tr(), value: user.email),
            AppSpacing.vGapMd,
            _DetailRow(icon: Icons.phone_outlined, label: 'profile.phone'.tr(), value: user.phone ?? 'common.na'.tr()),
            AppSpacing.vGapMd,
            _DetailRow(
              icon: Icons.security_outlined,
              label: 'admin_users.permissions'.tr(),
              value: _getPermissionsSummary(user.role),
            ),
            AppSpacing.vGapXl,
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showUserActions(dynamic user) {
    final currentUser = ref.read(currentUserProvider);
    final isCurrentUser = currentUser?.id == user.id;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('admin_form.edit'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.push('${RoutePaths.adminAdminUsers}/form?id=${user.id}');
              },
            ),
            if (!isCurrentUser)
              ListTile(
                leading: Icon(Icons.block, color: context.colors.error),
                title: Text('admin_users.deactivate'.tr(), style: TextStyle(color: context.colors.error)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('admin_users.deactivated'.tr())),
                  );
                },
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => const Color(0xFF7C3AED),
      UserRole.manager => context.colors.statusAssigned,
      UserRole.viewer => context.colors.textSecondary,
      _ => context.colors.primary,
    };
  }

  String _getPermissionsSummary(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => 'admin_users.perm_full'.tr(),
      UserRole.manager => 'admin_users.perm_manage'.tr(),
      UserRole.viewer => 'admin_users.perm_readonly'.tr(),
      _ => 'common.na'.tr(),
    };
  }
}

/// Admin user card widget
class _AdminUserCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _AdminUserCard({
    required this.user,
    this.onTap,
    this.onLongPress,
  });

  Color _getRoleColor(BuildContext context) {
    return switch (user.role as UserRole) {
      UserRole.superAdmin => const Color(0xFF7C3AED),
      UserRole.manager => context.colors.statusAssigned,
      UserRole.viewer => context.colors.textSecondary,
      _ => context.colors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(context);
    return Material(
      color: context.colors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            boxShadow: context.cardShadow,
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: roleColor.withOpacity(0.1),
                child: Text(
                  user.name[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
              ),
              AppSpacing.gapMd,
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              RoleBadge(role: user.role, size: RoleBadgeSize.small),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail row for bottom sheet
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.textTertiary),
        AppSpacing.gapMd,
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// Empty state widget with tab-specific messaging
class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (tabIndex) {
      0 => (Icons.admin_panel_settings_outlined, 'admin_users.not_found'.tr(), 'admin_users.adjust_search'.tr()),
      1 => (Icons.admin_panel_settings_outlined, 'admin_users.no_super_admins'.tr(), 'admin_users.super_admin_appear'.tr()),
      2 => (Icons.manage_accounts_outlined, 'admin_users.no_managers'.tr(), 'admin_users.manager_appear'.tr()),
      3 => (Icons.visibility_outlined, 'admin_users.no_viewers'.tr(), 'admin_users.viewer_appear'.tr()),
      _ => (Icons.admin_panel_settings_outlined, 'admin_users.not_found'.tr(), 'admin_users.adjust_search'.tr()),
    };

    return Center(
      child: Padding(
        padding: AppSpacing.allXxl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: context.colors.textTertiary),
            AppSpacing.vGapLg,
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
