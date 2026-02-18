import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/service_provider_model.dart';
import '../../providers/admin_service_provider_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../widgets/admin/admin_list_shimmer.dart';
import '../../widgets/admin/admin_error_state.dart';

/// Service Providers List Screen
/// Displays list of service providers with search and swipeable filter tabs
class SPListScreen extends ConsumerStatefulWidget {
  const SPListScreen({super.key});

  @override
  ConsumerState<SPListScreen> createState() => _SPListScreenState();
}

class _SPListScreenState extends ConsumerState<SPListScreen>
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
      ref.read(adminServiceProviderListProvider.notifier)
        ..filterByAvailability(null) // All
        ..filterByActive(true)       // Only active users
        ..filterByCategory(null)     // Clear any persisted category filter
        ..search('')
        ..loadServiceProviders();
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
        ref.read(adminServiceProviderListProvider.notifier).search(query);
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final isAvailable = switch (_tabController.index) {
      0 => null,    // All
      1 => true,    // Available
      2 => false,   // Busy
      _ => null,
    };

    ref.read(adminServiceProviderListProvider.notifier)
      ..filterByAvailability(isAvailable)
      ..loadServiceProviders();
  }

  void _onScroll(int tabIndex) {
    final controller = _scrollControllers[tabIndex];
    if (controller == null) return;

    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 200) {
      ref.read(adminServiceProviderListProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(adminServiceProviderListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminServiceProviderListProvider);
    final canCreate = ref.watch(canCreateServiceProvidersProvider);
    final canUpdate = ref.watch(canUpdateServiceProvidersProvider);
    final canDelete = ref.watch(canDeleteServiceProvidersProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('sp_list.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'admin.all'.tr()),
            Tab(text: 'sp.available'.tr()),
            Tab(text: 'sp.busy'.tr()),
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
                hintText: 'sp_list.search'.tr(),
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

          // SP list with TabBarView
          Expanded(
            child: state.serviceProviders.isEmpty && state.isLoading
                ? const AdminListShimmer()
                : state.error != null && state.serviceProviders.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: AdminErrorState(
                            error: state.error,
                            onRetry: () => ref.read(adminServiceProviderListProvider.notifier).loadServiceProviders(),
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(3, (tabIndex) {
                          if (state.serviceProviders.isEmpty && !state.isLoading) {
                            return _EmptyState(tabIndex: tabIndex);
                          }

                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              controller: _scrollControllers[tabIndex],
                              padding: AppSpacing.horizontalLg,
                              itemCount: state.serviceProviders.length + (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= state.serviceProviders.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final sp = state.serviceProviders[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: _SPCard(
                                    sp: sp,
                                    onTap: () => _showSPDetails(sp),
                                    onLongPress: (canUpdate || canDelete)
                                        ? () => _showSPActions(sp, canUpdate, canDelete)
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
              onPressed: () => context.push('${RoutePaths.adminSPs}/form'),
              icon: const Icon(Icons.add),
              label: Text('sp_list.add'.tr()),
            )
          : null,
    );
  }

  void _showSPDetails(ServiceProviderModel sp) {
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
                  backgroundImage: sp.userProfilePhotoUrl != null && sp.userProfilePhotoUrl!.isNotEmpty
                      ? NetworkImage(sp.userProfilePhotoUrl!)
                      : null,
                  child: sp.userProfilePhotoUrl == null || sp.userProfilePhotoUrl!.isEmpty
                      ? Text(
                          (sp.userName ?? 'S')[0].toUpperCase(),
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
                        sp.userName ?? 'common.na'.tr(),
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (sp.categories.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primary.withOpacity(0.1),
                                borderRadius: AppRadius.badgeRadius,
                              ),
                              child: Text(
                                sp.categories.first.localizedName(context.locale.languageCode),
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          AppSpacing.gapSm,
                          if (sp.rating != null)
                            Row(
                              children: [
                                Icon(Icons.star, size: 16, color: context.colors.warning),
                                const SizedBox(width: 2),
                                Text(
                                  '${sp.rating}',
                                  style: context.textTheme.bodySmall,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sp.isAvailable
                        ? context.colors.success.withOpacity(0.1)
                        : context.colors.warning.withOpacity(0.1),
                    borderRadius: AppRadius.badgeRadius,
                  ),
                  child: Text(
                    sp.isAvailable ? 'sp.available'.tr() : 'sp.busy'.tr(),
                    style: TextStyle(
                      color: sp.isAvailable ? context.colors.success : context.colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.vGapXl,
            _DetailRow(icon: Icons.email_outlined, label: 'tenants_list.email'.tr(), value: sp.userEmail ?? '-'),
            AppSpacing.vGapMd,
            _DetailRow(icon: Icons.phone_outlined, label: 'tenants_list.phone'.tr(), value: sp.userPhone ?? '-'),
            AppSpacing.vGapMd,
            _DetailRow(
              icon: Icons.assignment_outlined,
              label: 'sp.active_jobs'.tr(),
              value: '${sp.activeJobs ?? 0}',
            ),
            AppSpacing.vGapXl,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('${RoutePaths.adminSPs}/${sp.id}/slots');
                },
                icon: const Icon(Icons.schedule),
                label: Text('sp_list.manage_slots'.tr()),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showSPActions(ServiceProviderModel sp, bool canUpdate, bool canDelete) {
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
                title: Text('sp_list.edit'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  context.push('${RoutePaths.adminSPs}/form?id=${sp.id}');
                },
              ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text('sp_list.manage_slots'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.push('${RoutePaths.adminSPs}/${sp.id}/slots');
              },
            ),
            if (canUpdate)
              ListTile(
                leading: Icon(
                  sp.isAvailable ? Icons.do_not_disturb : Icons.check_circle_outline,
                  color: sp.isAvailable ? context.colors.warning : context.colors.success,
                ),
                title: Text(sp.isAvailable ? 'sp.set_busy'.tr() : 'sp.set_available'.tr()),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await ref.read(adminServiceProviderActionProvider.notifier).toggleAvailability(sp.id);
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          sp.isAvailable ? 'sp.now_busy'.tr() : 'sp.now_available'.tr(),
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
                onTap: () => _confirmDelete(sp),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ServiceProviderModel sp) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('common.confirm_delete'.tr()),
        content: Text('sp_list.delete_confirm'.tr(namedArgs: {'name': sp.userName ?? 'this service provider'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(adminServiceProviderActionProvider.notifier).deleteServiceProvider(sp.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'sp_list.deleted'.tr() : 'errors.delete_failed'.tr(),
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

/// SP card widget
class _SPCard extends StatelessWidget {
  final ServiceProviderModel sp;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SPCard({
    required this.sp,
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
                backgroundImage: sp.userProfilePhotoUrl != null && sp.userProfilePhotoUrl!.isNotEmpty
                    ? NetworkImage(sp.userProfilePhotoUrl!)
                    : null,
                child: sp.userProfilePhotoUrl == null || sp.userProfilePhotoUrl!.isEmpty
                    ? Text(
                        (sp.userName ?? 'S')[0].toUpperCase(),
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
                            sp.userName ?? 'common.na'.tr(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: sp.isAvailable
                                ? context.colors.success.withOpacity(0.1)
                                : context.colors.warning.withOpacity(0.1),
                            borderRadius: AppRadius.badgeRadius,
                          ),
                          child: Text(
                            sp.isAvailable ? 'sp.available'.tr() : 'sp.busy'.tr(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: sp.isAvailable
                                  ? context.colors.success
                                  : context.colors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vGapXs,
                    Row(
                      children: [
                        if (sp.categories.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withOpacity(0.1),
                              borderRadius: AppRadius.badgeRadius,
                            ),
                            child: Text(
                              sp.categories.first.localizedName(context.locale.languageCode),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                        if (sp.categories.isNotEmpty) AppSpacing.gapMd,
                        if (sp.rating != null) ...[
                          Icon(Icons.star, size: 14, color: context.colors.warning),
                          const SizedBox(width: 2),
                          Text(
                            '${sp.rating}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                          const Text(' • '),
                        ],
                        Text(
                          'sp.active_count'.tr(namedArgs: {'count': '${sp.activeJobs ?? 0}'}),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
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
      0 => (Icons.engineering_outlined, 'sp_list.not_found'.tr(), 'tenants_list.adjust_search'.tr()),
      1 => (Icons.check_circle_outline, 'sp_list.no_available'.tr(), 'sp_list.available_appear'.tr()),
      2 => (Icons.do_not_disturb, 'sp_list.no_busy'.tr(), 'sp_list.busy_appear'.tr()),
      _ => (Icons.engineering_outlined, 'sp_list.not_found'.tr(), 'tenants_list.adjust_search'.tr()),
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
