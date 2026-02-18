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
import '../../providers/admin_tenant_provider.dart';
import '../../providers/admin_service_provider_provider.dart';
import '../../providers/admin_category_provider.dart';
import '../../providers/admin_consumable_provider.dart';

/// Management Hub Screen
/// Central navigation for entity management (Users, Master Data, Reports)
class ManagementHubScreen extends ConsumerStatefulWidget {
  const ManagementHubScreen({super.key});

  @override
  ConsumerState<ManagementHubScreen> createState() =>
      _ManagementHubScreenState();
}

class _ManagementHubScreenState extends ConsumerState<ManagementHubScreen> {
  @override
  void initState() {
    super.initState();
    // Load all entity counts on screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllCounts();
    });
  }

  void _loadAllCounts() {
    // Load tenants if not already loaded or if total is missing
    final tenantsState = ref.read(adminTenantListProvider);
    if ((tenantsState.tenants.isEmpty || tenantsState.total == 0) &&
        !tenantsState.isLoading) {
      ref.read(adminTenantListProvider.notifier).loadTenants();
    }

    // Load service providers if not already loaded or if total is missing
    final serviceProvidersState = ref.read(adminServiceProviderListProvider);
    if ((serviceProvidersState.serviceProviders.isEmpty ||
            serviceProvidersState.total == 0) &&
        !serviceProvidersState.isLoading) {
      ref
          .read(adminServiceProviderListProvider.notifier)
          .loadServiceProviders();
    }

    // Load categories if not already loaded or if total is missing
    final categoriesState = ref.read(adminCategoryListProvider);
    if ((categoriesState.categories.isEmpty || categoriesState.total == 0) &&
        !categoriesState.isLoading) {
      ref.read(adminCategoryListProvider.notifier).loadCategories();
    }

    // Load consumables if not already loaded or if total is missing
    final consumablesState = ref.read(adminConsumableListProvider);
    if ((consumablesState.consumables.isEmpty || consumablesState.total == 0) &&
        !consumablesState.isLoading) {
      ref.read(adminConsumableListProvider.notifier).loadConsumables();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isSuperAdmin = user?.role == UserRole.superAdmin;

    // Watch all entity counts
    final tenantsState = ref.watch(adminTenantListProvider);
    final serviceProvidersState = ref.watch(adminServiceProviderListProvider);
    final categoriesState = ref.watch(adminCategoryListProvider);
    final consumablesState = ref.watch(adminConsumableListProvider);

    // Use total from server if available and greater than loaded list length
    // This handles cases where only one page is cached but server has more
    final tenantsCount = tenantsState.total > tenantsState.tenants.length
        ? tenantsState.total
        : tenantsState.tenants.length;
    final serviceProvidersCount =
        serviceProvidersState.total >
            serviceProvidersState.serviceProviders.length
        ? serviceProvidersState.total
        : serviceProvidersState.serviceProviders.length;
    final categoriesCount =
        categoriesState.total > categoriesState.categories.length
        ? categoriesState.total
        : categoriesState.categories.length;
    final consumablesCount =
        consumablesState.total > consumablesState.consumables.length
        ? consumablesState.total
        : consumablesState.consumables.length;
    final adminUsersCount =
        MockData.adminUsers.length; // TODO: Create admin user provider

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text('management.title'.tr())),
      body: RefreshIndicator(
        onRefresh: _refreshAllCounts,
        child: SingleChildScrollView(
          padding: AppSpacing.screen,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Management Section
              _SectionHeader(title: 'management.user_management'.tr()),
              AppSpacing.vGapMd,

              // User Management Grid
              Row(
                children: [
                  Expanded(
                    child: _ManagementTile(
                      title: 'management.tenants'.tr(),
                      icon: Icons.people_rounded,
                      count: tenantsCount,
                      color: context.colors.statusAssigned,
                      onTap: () => context.push(RoutePaths.adminTenants),
                    ),
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: _ManagementTile(
                      title: 'management.service_providers'.tr(),
                      icon: Icons.engineering_rounded,
                      count: serviceProvidersCount,
                      color: context.colors.primary,
                      onTap: () => context.push(RoutePaths.adminSPs),
                    ),
                  ),
                ],
              ),

              // Admin Users (Super Admin only)
              if (isSuperAdmin) ...[
                AppSpacing.vGapMd,
                _ManagementTile(
                  title: 'management.admin_users'.tr(),
                  icon: Icons.admin_panel_settings_rounded,
                  count: adminUsersCount,
                  color: const Color(0xFF7C3AED), // Purple
                  badge: 'management.admin_only'.tr(),
                  onTap: () => context.push(RoutePaths.adminAdminUsers),
                ),
              ],

              AppSpacing.vGapXl,

              // Master Data Section
              _SectionHeader(title: 'management.master_data'.tr()),
              AppSpacing.vGapMd,

              Row(
                children: [
                  Expanded(
                    child: _ManagementTile(
                      title: 'management.categories'.tr(),
                      icon: Icons.category_rounded,
                      count: categoriesCount,
                      color: context.colors.info,
                      onTap: () => context.push(RoutePaths.adminCategories),
                    ),
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: _ManagementTile(
                      title: 'management.consumables'.tr(),
                      icon: Icons.inventory_2_rounded,
                      count: consumablesCount,
                      color: context.colors.warning,
                      onTap: () => context.push(RoutePaths.adminConsumables),
                    ),
                  ),
                ],
              ),

              AppSpacing.vGapXl,

              // Calendar Section
              _SectionHeader(title: 'management.calendar'.tr()),
              AppSpacing.vGapMd,

              _CompactTile(
                title: 'management.view_calendar'.tr(),
                subtitle: 'management.schedule_overview'.tr(),
                icon: Icons.calendar_month_rounded,
                color: context.colors.primary,
                onTap: () => context.push(RoutePaths.adminCalendar),
              ),

              AppSpacing.vGapXxl,
            ],
          ),
        ),
      ),
    );
  }

  /// Refresh all entity counts by reloading data
  Future<void> _refreshAllCounts() async {
    await Future.wait([
      ref.read(adminTenantListProvider.notifier).refresh(),
      ref.read(adminServiceProviderListProvider.notifier).refresh(),
      ref.read(adminCategoryListProvider.notifier).refresh(),
      ref.read(adminConsumableListProvider.notifier).refresh(),
    ]);
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
      ),
    );
  }
}

/// Management tile widget (for grid items)
class _ManagementTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _ManagementTile({
    required this.title,
    required this.icon,
    required this.count,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            boxShadow: context.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: AppRadius.allMd,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: AppRadius.badgeRadius,
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.vGapMd,
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              AppSpacing.vGapXs,
              Text(
                'management.items_count'.tr(namedArgs: {'count': '$count'}),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact tile widget (for list items)
class _CompactTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CompactTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            boxShadow: context.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: AppRadius.allMd,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
