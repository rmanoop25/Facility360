import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/tenant_model.dart';
import '../../providers/admin_tenant_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../widgets/admin/admin_list_shimmer.dart';
import '../../widgets/admin/admin_error_state.dart';

/// Tenants List Screen
/// Displays list of tenants with search and swipeable filter tabs
class TenantsListScreen extends ConsumerStatefulWidget {
  const TenantsListScreen({super.key});

  @override
  ConsumerState<TenantsListScreen> createState() => _TenantsListScreenState();
}

class _TenantsListScreenState extends ConsumerState<TenantsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollControllers = <int, ScrollController>{};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize scroll controllers for each tab
    for (int i = 0; i < 3; i++) {
      _scrollControllers[i] = ScrollController();
      _scrollControllers[i]!.addListener(() => _onScroll(i));
    }

    _searchController.addListener(_onSearchChanged);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminTenantListProvider.notifier)
        ..filterByActive(null) // All tenants
        ..search('')
        ..loadTenants();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final query = _searchController.text;
        ref.read(adminTenantListProvider.notifier).search(query);
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final isActive = switch (_tabController.index) {
      0 => null,    // All
      1 => true,    // Active
      2 => false,   // Inactive
      _ => null,
    };

    ref.read(adminTenantListProvider.notifier)
      ..filterByActive(isActive)
      ..loadTenants();
  }

  void _onScroll(int tabIndex) {
    final controller = _scrollControllers[tabIndex];
    if (controller == null) return;

    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 200) {
      ref.read(adminTenantListProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(adminTenantListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminTenantListProvider);
    final canCreate = ref.watch(canCreateTenantsProvider);
    final canUpdate = ref.watch(canUpdateTenantsProvider);
    final canDelete = ref.watch(canDeleteTenantsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('tenants_list.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'admin.all'.tr()),
            Tab(text: 'common.active'.tr()),
            Tab(text: 'common.inactive'.tr()),
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
                hintText: 'tenants_list.search'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
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

          // Tenant list with TabBarView
          Expanded(
            child: state.tenants.isEmpty && state.isLoading
                ? const AdminListShimmer()
                : state.error != null && state.tenants.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: AdminErrorState(
                            error: state.error,
                            onRetry: () => ref.read(adminTenantListProvider.notifier).loadTenants(),
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(3, (tabIndex) {
                          if (state.tenants.isEmpty && !state.isLoading) {
                            return _EmptyState(tabIndex: tabIndex);
                          }

                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              controller: _scrollControllers[tabIndex],
                              padding: AppSpacing.horizontalLg,
                              itemCount: state.tenants.length + (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= state.tenants.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final tenant = state.tenants[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: _TenantCard(
                                    tenant: tenant,
                                    onTap: () => _showTenantDetails(tenant),
                                    onLongPress: (canUpdate || canDelete)
                                        ? () => _showTenantActions(tenant, canUpdate, canDelete)
                                        : null,
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
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('${RoutePaths.adminTenants}/form'),
              icon: const Icon(Icons.add),
              label: Text('tenants_list.add'.tr()),
            )
          : null,
    );
  }

  void _showTenantDetails(TenantModel tenant) {
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
                  backgroundColor: context.colors.primary.withOpacity(0.1),
                  backgroundImage: tenant.profilePhotoUrl != null && tenant.profilePhotoUrl!.isNotEmpty
                      ? NetworkImage(tenant.profilePhotoUrl!)
                      : null,
                  child: tenant.profilePhotoUrl == null || tenant.profilePhotoUrl!.isEmpty
                      ? Text(
                          (tenant.userName ?? 'T')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primary,
                          ),
                        )
                      : null,
                ),
                AppSpacing.gapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.userName ?? 'common.na'.tr(),
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${tenant.unitNumber ?? ''}, ${tenant.buildingName ?? ''}',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tenant.userIsActive
                        ? context.colors.success.withOpacity(0.1)
                        : context.colors.error.withOpacity(0.1),
                    borderRadius: AppRadius.badgeRadius,
                  ),
                  child: Text(
                    tenant.userIsActive ? 'common.active'.tr() : 'common.inactive'.tr(),
                    style: TextStyle(
                      color: tenant.userIsActive ? context.colors.success : context.colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.vGapXl,
            _DetailRow(icon: Icons.email_outlined, label: 'tenants_list.email'.tr(), value: tenant.userEmail ?? '-'),
            AppSpacing.vGapMd,
            _DetailRow(icon: Icons.phone_outlined, label: 'tenants_list.phone'.tr(), value: tenant.userPhone ?? '-'),
            AppSpacing.vGapMd,
            _DetailRow(
              icon: Icons.report_problem_outlined,
              label: 'nav.issues'.tr(),
              value: 'tenants_list.issues_count'.tr(namedArgs: {'count': '${tenant.issuesCount ?? 0}'}),
            ),
            AppSpacing.vGapXl,
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showTenantActions(TenantModel tenant, bool canUpdate, bool canDelete) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canUpdate)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('tenants_list.edit'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  context.push('${RoutePaths.adminTenants}/form?id=${tenant.id}');
                },
              ),
            if (canUpdate)
              ListTile(
                leading: Icon(
                  tenant.userIsActive ? Icons.block : Icons.check_circle_outline,
                  color: tenant.userIsActive ? context.colors.error : context.colors.success,
                ),
                title: Text(tenant.userIsActive ? 'tenants_list.deactivate'.tr() : 'tenants_list.activate'.tr()),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await ref.read(adminTenantActionProvider.notifier).toggleActive(tenant.id);
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tenant.userIsActive
                              ? 'tenants_list.deactivated'.tr()
                              : 'tenants_list.activated'.tr(),
                        ),
                      ),
                    );
                  }
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline, color: context.colors.error),
                title: Text('common.delete'.tr(), style: TextStyle(color: context.colors.error)),
                onTap: () => _confirmDelete(tenant),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(TenantModel tenant) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('common.confirm_delete'.tr()),
        content: Text('tenants_list.delete_confirm'.tr(namedArgs: {'name': tenant.userName ?? 'this tenant'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(adminTenantActionProvider.notifier).deleteTenant(tenant.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'tenants_list.deleted'.tr() : 'errors.delete_failed'.tr(),
                    ),
                    backgroundColor: success ? null : context.colors.error,
                  ),
                );
              }
            },
            child: Text('common.delete'.tr(), style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
  }
}

/// Tenant card widget
class _TenantCard extends StatelessWidget {
  final TenantModel tenant;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _TenantCard({
    required this.tenant,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
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
                backgroundColor: context.colors.primary.withOpacity(0.1),
                backgroundImage: tenant.profilePhotoUrl != null && tenant.profilePhotoUrl!.isNotEmpty
                    ? NetworkImage(tenant.profilePhotoUrl!)
                    : null,
                child: tenant.profilePhotoUrl == null || tenant.profilePhotoUrl!.isEmpty
                    ? Text(
                        (tenant.userName ?? 'T')[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.colors.primary,
                        ),
                      )
                    : null,
              ),
              AppSpacing.gapMd,
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant.userName ?? 'common.na'.tr(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tenant.userIsActive
                                ? context.colors.success
                                : context.colors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      '${tenant.unitNumber ?? ''}, ${tenant.buildingName ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    AppSpacing.vGapXs,
                    if ((tenant.issuesCount ?? 0) > 0)
                      Text(
                        '${tenant.issuesCount} active issues',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.warning,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colors.textTertiary,
              ),
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
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
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
      0 => (Icons.people_outline, 'tenants_list.not_found'.tr(), 'tenants_list.adjust_search'.tr()),
      1 => (Icons.check_circle_outline, 'tenants_list.no_active'.tr(), 'tenants_list.active_appear'.tr()),
      2 => (Icons.cancel_outlined, 'tenants_list.no_inactive'.tr(), 'tenants_list.inactive_appear'.tr()),
      _ => (Icons.people_outline, 'tenants_list.not_found'.tr(), 'tenants_list.adjust_search'.tr()),
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
