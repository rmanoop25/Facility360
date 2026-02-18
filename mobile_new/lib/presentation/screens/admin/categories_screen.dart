import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/category_model.dart';
import '../../providers/admin_category_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../widgets/admin/admin_list_shimmer.dart';
import '../../widgets/admin/admin_error_state.dart';

/// Categories Screen with hierarchical tree view
/// List and manage issue categories with parent-child relationships
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    // Load categories when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminCategoryListProvider.notifier).loadCategories();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(adminCategoryListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminCategoryListProvider);
    final canCreate = ref.watch(canCreateCategoriesProvider);
    final canUpdate = ref.watch(canUpdateCategoriesProvider);
    final canDelete = ref.watch(canDeleteCategoriesProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('categories_list.title'.tr()),
        actions: [
          // Expand/Collapse all toggle
          if (state.categories.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.unfold_more_rounded),
              onPressed: () => ref.read(adminCategoryListProvider.notifier).expandAll(),
              tooltip: 'categories_list.expand_all'.tr(),
            ),
            IconButton(
              icon: const Icon(Icons.unfold_less_rounded),
              onPressed: () => ref.read(adminCategoryListProvider.notifier).collapseAll(),
              tooltip: 'categories_list.collapse_all'.tr(),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(context, state, canUpdate, canDelete),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('${RoutePaths.adminCategories}/form'),
              icon: const Icon(Icons.add),
              label: Text('categories_list.add'.tr()),
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AdminCategoryListState state,
    bool canUpdate,
    bool canDelete,
  ) {
    // Loading state
    if (state.isLoading && state.categories.isEmpty) {
      return const AdminListShimmer();
    }

    // Error state
    if (state.error != null && state.categories.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: AdminErrorState(
            error: state.error,
            onRetry: () => ref.read(adminCategoryListProvider.notifier).loadCategories(),
          ),
        ),
      );
    }

    // Empty state
    if (state.categories.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _EmptyState(),
        ),
      );
    }

    // Tree view
    return ListView.builder(
      padding: AppSpacing.allLg,
      itemCount: state.rootCategories.length,
      itemBuilder: (context, index) {
        final rootCategory = state.rootCategories[index];
        return _buildCategoryTree(
          context,
          rootCategory,
          state,
          canUpdate,
          canDelete,
          0,
        );
      },
    );
  }

  /// Recursively build category tree
  Widget _buildCategoryTree(
    BuildContext context,
    CategoryModel category,
    AdminCategoryListState state,
    bool canUpdate,
    bool canDelete,
    int depth,
  ) {
    final hasChildren = category.hasChildCategories;
    final isExpanded = state.isExpanded(category.id);
    final children = state.childrenOf(category.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryTreeItem(
          category: category,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onTap: () => _showCategoryDetails(context, category),
          onLongPress: (canUpdate || canDelete)
              ? () => _showCategoryActions(context, category, canUpdate, canDelete)
              : null,
          onToggleExpand: hasChildren
              ? () => ref.read(adminCategoryListProvider.notifier).toggleExpanded(category.id)
              : null,
        ),
        // Render children if expanded
        if (isExpanded && children.isNotEmpty)
          ...children.map((child) => _buildCategoryTree(
                context,
                child,
                state,
                canUpdate,
                canDelete,
                depth + 1,
              )),
      ],
    );
  }

  void _showCategoryDetails(BuildContext context, CategoryModel category) {
    final locale = context.locale.languageCode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: AppSpacing.allLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.vGapLg,

              // Header
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withOpacity(0.1),
                      borderRadius: AppRadius.allLg,
                    ),
                    child: Icon(
                      _getCategoryIcon(category.icon),
                      size: 32,
                      color: context.colors.primary,
                    ),
                  ),
                  AppSpacing.gapLg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.localizedName(locale),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          locale == 'ar' ? category.nameEn : category.nameAr,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: category.isActive
                          ? context.colors.success.withOpacity(0.1)
                          : context.colors.error.withOpacity(0.1),
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Text(
                      category.isActive ? 'common.active'.tr() : 'common.inactive'.tr(),
                      style: TextStyle(
                        color: category.isActive ? context.colors.success : context.colors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              AppSpacing.vGapXl,

              // Hierarchy info
              if (category.depth > 0 || category.childrenCount != null && category.childrenCount! > 0)
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.account_tree_rounded,
                      label: 'categories_list.depth'.tr(namedArgs: {'depth': '${category.depth}'}),
                      color: _getDepthColor(context, category.depth),
                    ),
                    if (category.childrenCount != null && category.childrenCount! > 0) ...[
                      AppSpacing.gapMd,
                      _StatChip(
                        icon: Icons.subdirectory_arrow_right_rounded,
                        label: 'categories_list.children_count'.tr(namedArgs: {'count': '${category.childrenCount}'}),
                        color: context.colors.info,
                      ),
                    ],
                  ],
                ),

              if (category.depth > 0 || (category.childrenCount != null && category.childrenCount! > 0))
                AppSpacing.vGapMd,

              // Stats
              Row(
                children: [
                  _StatChip(
                    icon: Icons.engineering_rounded,
                    label: 'categories_list.providers_count'.tr(namedArgs: {'count': '${category.serviceProvidersCount ?? 0}'}),
                    color: context.colors.primary,
                  ),
                  AppSpacing.gapMd,
                  _StatChip(
                    icon: Icons.inventory_2_rounded,
                    label: 'categories_list.consumables_count'.tr(namedArgs: {'count': '${category.consumablesCount ?? 0}'}),
                    color: context.colors.warning,
                  ),
                ],
              ),

              if (category.descriptionEn != null && category.descriptionEn!.isNotEmpty) ...[
                AppSpacing.vGapXl,
                Text(
                  'common.description'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vGapSm,
                Text(
                  locale == 'ar' && category.descriptionAr != null
                      ? category.descriptionAr!
                      : category.descriptionEn!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],

              const Spacer(),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryActions(
    BuildContext context,
    CategoryModel category,
    bool canUpdate,
    bool canDelete,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canUpdate) ...[
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text('categories_list.edit'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  context.push('${RoutePaths.adminCategories}/form?id=${category.id}');
                },
              ),
              // Add subcategory option
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text('categories_list.add_subcategory'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  context.push('${RoutePaths.adminCategories}/form?parent_id=${category.id}');
                },
              ),
              ListTile(
                leading: Icon(
                  category.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                  color: category.isActive ? context.colors.error : context.colors.success,
                ),
                title: Text(
                  category.isActive ? 'categories_list.deactivate'.tr() : 'categories_list.activate'.tr(),
                ),
                subtitle: category.hasChildCategories && category.isActive
                    ? Text(
                        'categories_list.deactivate_cascade_warning'.tr(),
                        style: TextStyle(
                          color: context.colors.error,
                          fontSize: 12,
                        ),
                      )
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  final success = await ref.read(adminCategoryActionProvider.notifier).toggleActive(category.id);
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          category.isActive
                              ? 'categories_list.deactivated'.tr()
                              : 'categories_list.activated'.tr(),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
            if (canDelete)
              ListTile(
                leading: Icon(Icons.archive_rounded, color: context.colors.warning),
                title: Text('categories_list.archive'.tr()),
                subtitle: category.hasChildCategories
                    ? Text(
                        'categories_list.archive_cascade_warning'.tr(),
                        style: TextStyle(
                          color: context.colors.warning,
                          fontSize: 12,
                        ),
                      )
                    : null,
                onTap: () => _confirmArchive(context, category),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _confirmArchive(BuildContext context, CategoryModel category) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('categories_list.archive_confirm_title'.tr()),
        content: Text(
          category.hasChildCategories
              ? 'categories_list.archive_confirm_with_children'.tr(namedArgs: {
                  'name': category.nameEn,
                  'count': '${category.childrenCount ?? 0}',
                })
              : 'categories_list.archive_confirm'.tr(namedArgs: {'name': category.nameEn}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(adminCategoryActionProvider.notifier).deleteCategory(category.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'categories_list.archived'.tr() : 'errors.delete_failed'.tr(),
                    ),
                    backgroundColor: success ? null : context.colors.error,
                  ),
                );
              }
            },
            child: Text('categories_list.archive'.tr(), style: TextStyle(color: context.colors.warning)),
          ),
        ],
      ),
    );
  }

  Color _getDepthColor(BuildContext context, int depth) {
    return switch (depth) {
      0 => context.colors.primary,
      1 => context.colors.info,
      2 => context.colors.success,
      _ => context.colors.warning,
    };
  }

  IconData _getCategoryIcon(String? icon) {
    return switch (icon) {
      'plumbing' => Icons.plumbing_rounded,
      'electrical' => Icons.electrical_services_rounded,
      'hvac' => Icons.ac_unit_rounded,
      'carpentry' => Icons.carpenter_rounded,
      'painting' => Icons.format_paint_rounded,
      'general' => Icons.build_rounded,
      'cleaning' => Icons.cleaning_services_rounded,
      'landscaping' => Icons.grass_rounded,
      'security' => Icons.security_rounded,
      'elevator' => Icons.elevator_rounded,
      'pool' => Icons.pool_rounded,
      'gym' => Icons.fitness_center_rounded,
      _ => Icons.category_rounded,
    };
  }
}

/// Category tree item widget
class _CategoryTreeItem extends StatelessWidget {
  final CategoryModel category;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleExpand;

  const _CategoryTreeItem({
    required this.category,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    this.onTap,
    this.onLongPress,
    this.onToggleExpand,
  });

  IconData get _icon {
    return switch (category.icon) {
      'plumbing' => Icons.plumbing_rounded,
      'electrical' => Icons.electrical_services_rounded,
      'hvac' => Icons.ac_unit_rounded,
      'carpentry' => Icons.carpenter_rounded,
      'painting' => Icons.format_paint_rounded,
      'general' => Icons.build_rounded,
      'cleaning' => Icons.cleaning_services_rounded,
      'landscaping' => Icons.grass_rounded,
      'security' => Icons.security_rounded,
      'elevator' => Icons.elevator_rounded,
      'pool' => Icons.pool_rounded,
      'gym' => Icons.fitness_center_rounded,
      _ => Icons.category_rounded,
    };
  }

  Color _getDepthColor(BuildContext context) {
    return switch (depth) {
      0 => context.colors.primary,
      1 => context.colors.info,
      2 => context.colors.success,
      _ => context.colors.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final indentation = depth * 24.0;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: indentation),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: context.colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMd,
          side: BorderSide(
            color: depth == 0
                ? context.colors.border
                : _getDepthColor(context).withOpacity(0.3),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: AppSpacing.allMd,
            child: Row(
              children: [
                // Expand/collapse button or spacer
                if (hasChildren)
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getDepthColor(context).withOpacity(0.1),
                        borderRadius: AppRadius.allSm,
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : (locale == 'ar'
                                ? Icons.keyboard_arrow_left_rounded
                                : Icons.keyboard_arrow_right_rounded),
                        size: 20,
                        color: _getDepthColor(context),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 32),

                AppSpacing.gapMd,

                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getDepthColor(context).withOpacity(0.1),
                    borderRadius: AppRadius.allMd,
                  ),
                  child: Icon(
                    _icon,
                    color: _getDepthColor(context),
                    size: 24,
                  ),
                ),

                AppSpacing.gapMd,

                // Name and info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.localizedName(locale),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!category.isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colors.error.withOpacity(0.1),
                                borderRadius: AppRadius.badgeRadius,
                              ),
                              child: Text(
                                'common.inactive'.tr(),
                                style: TextStyle(
                                  color: context.colors.error,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      AppSpacing.vGapXs,
                      Row(
                        children: [
                          // Depth badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getDepthColor(context).withOpacity(0.1),
                              borderRadius: AppRadius.badgeRadius,
                            ),
                            child: Text(
                              depth == 0
                                  ? 'categories_list.root'.tr()
                                  : 'L$depth',
                              style: TextStyle(
                                color: _getDepthColor(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (hasChildren) ...[
                            AppSpacing.gapSm,
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 12,
                              color: context.colors.textTertiary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${category.childrenCount ?? 0}',
                              style: TextStyle(
                                color: context.colors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          AppSpacing.gapSm,
                          Icon(
                            Icons.engineering_rounded,
                            size: 12,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${category.serviceProvidersCount ?? 0}',
                            style: TextStyle(
                              color: context.colors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          AppSpacing.gapSm,
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 12,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${category.consumablesCount ?? 0}',
                            style: TextStyle(
                              color: context.colors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // More options indicator
                Icon(
                  Icons.more_vert_rounded,
                  color: context.colors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat chip widget
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.badgeRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_rounded,
            size: 64,
            color: context.colors.textTertiary,
          ),
          AppSpacing.vGapLg,
          Text(
            'categories_list.no_categories'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vGapSm,
          Text(
            'categories_list.add_to_organize'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
