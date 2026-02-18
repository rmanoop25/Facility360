import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/consumable_model.dart';
import '../../../data/models/category_model.dart';
import '../../providers/admin_consumable_provider.dart';
import '../../providers/admin_category_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../widgets/admin/admin_list_shimmer.dart';
import '../../widgets/admin/admin_error_state.dart';

/// Consumables Screen
/// List and manage consumables with swipeable category tabs
class ConsumablesScreen extends ConsumerStatefulWidget {
  const ConsumablesScreen({super.key});

  @override
  ConsumerState<ConsumablesScreen> createState() => _ConsumablesScreenState();
}

class _ConsumablesScreenState extends ConsumerState<ConsumablesScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _searchController = TextEditingController();
  final _scrollControllers = <int, ScrollController>{};
  Timer? _searchDebounce;
  int? _currentCategoryFilter;
  List<CategoryModel> _lastCategories = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminConsumableListProvider.notifier)
        ..filterByCategory(null) // All categories
        ..search('')
        ..loadConsumables();
      ref.read(adminCategoryListProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    _tabController?.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final query = _searchController.text;
        ref.read(adminConsumableListProvider.notifier).search(query);
      }
    });
  }

  void _onTabChanged(List<CategoryModel> categories) {
    if (_tabController == null || _tabController!.indexIsChanging) return;

    final tabIndex = _tabController!.index;
    final categoryId = tabIndex > 0 && tabIndex <= categories.length
        ? categories[tabIndex - 1].id
        : null;

    if (_currentCategoryFilter != categoryId) {
      _currentCategoryFilter = categoryId;
      ref.read(adminConsumableListProvider.notifier)
        ..filterByCategory(categoryId)
        ..loadConsumables();
    }
  }

  void _onScroll(int tabIndex) {
    final controller = _scrollControllers[tabIndex];
    if (controller == null) {
      debugPrint('ConsumablesScreen: _onScroll - controller is null for tab $tabIndex');
      return;
    }

    final pixels = controller.position.pixels;
    final maxScrollExtent = controller.position.maxScrollExtent;
    final threshold = maxScrollExtent - 200;

    // debugPrint('ConsumablesScreen: _onScroll tab=$tabIndex pixels=$pixels max=$maxScrollExtent threshold=$threshold');

    if (pixels >= threshold) {
      debugPrint('ConsumablesScreen: _onScroll - triggering loadMore() for tab $tabIndex');
      ref.read(adminConsumableListProvider.notifier).loadMore();
    }
  }

  void _updateTabController(List<CategoryModel> categories) {
    if (_lastCategories.length != categories.length) {
      // Dispose old scroll controllers
      for (var controller in _scrollControllers.values) {
        controller.dispose();
      }
      _scrollControllers.clear();

      // Create new scroll controllers for each tab
      for (int i = 0; i <= categories.length; i++) {
        _scrollControllers[i] = ScrollController();
        _scrollControllers[i]!.addListener(() => _onScroll(i));
      }

      _tabController?.dispose();
      _tabController = TabController(
        length: categories.length + 1,
        vsync: this,
      );
      _tabController!.addListener(() => _onTabChanged(categories));
      _lastCategories = categories;
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(adminConsumableListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminConsumableListProvider);
    final categoriesState = ref.watch(adminCategoryListProvider);
    final canCreate = ref.watch(canCreateConsumablesProvider);
    final canUpdate = ref.watch(canUpdateConsumablesProvider);
    final canDelete = ref.watch(canDeleteConsumablesProvider);

    // Update tab controller when categories change
    _updateTabController(categoriesState.categories);

    // Build tabs list
    final tabs = [
      Tab(text: 'admin.all'.tr()),
      ...categoriesState.categories.map((cat) => Tab(text: cat.localizedName(context.locale.languageCode))),
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('consumables.title'.tr()),
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: tabs,
              )
            : null,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: AppSpacing.allLg,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'consumables.search'.tr(),
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

          // Consumables list with TabBarView
          Expanded(
            child: state.consumables.isEmpty && state.isLoading
                ? const AdminGroupedListShimmer()
                : state.error != null && state.consumables.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: AdminErrorState(
                            error: state.error,
                            onRetry: () => ref.read(adminConsumableListProvider.notifier).loadConsumables(),
                          ),
                        ),
                      )
                    : _tabController != null
                        ? TabBarView(
                            controller: _tabController,
                            children: List.generate(
                              categoriesState.categories.length + 1,
                              (tabIndex) {
                                if (state.consumables.isEmpty && !state.isLoading) {
                                  return _EmptyState(
                                    tabIndex: tabIndex,
                                    categoryName: tabIndex > 0 && tabIndex <= categoriesState.categories.length
                                        ? categoriesState.categories[tabIndex - 1].localizedName(context.locale.languageCode)
                                        : null,
                                  );
                                }

                                return RefreshIndicator(
                                  onRefresh: _onRefresh,
                                  child: ListView.builder(
                                    controller: _scrollControllers[tabIndex],
                                    padding: AppSpacing.horizontalLg,
                                    itemCount: state.consumables.length + (state.isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= state.consumables.length) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }

                                      final consumable = state.consumables[index];
                                      final category = categoriesState.categories
                                          .where((c) => c.id == consumable.categoryId)
                                          .firstOrNull;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                        child: _ConsumableCard(
                                          consumable: consumable,
                                          category: category,
                                          onTap: () => _showConsumableDetails(context, consumable, category),
                                          onLongPress: (canUpdate || canDelete)
                                              ? () => _showConsumableActions(context, consumable, canUpdate, canDelete)
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          )
                        : const AdminGroupedListShimmer(),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('${RoutePaths.adminConsumables}/form'),
              icon: const Icon(Icons.add),
              label: Text('consumables.add'.tr()),
            )
          : null,
    );
  }

  void _showConsumableDetails(BuildContext context, ConsumableModel consumable, CategoryModel? category) {
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: context.colors.warning.withOpacity(0.1),
                    borderRadius: AppRadius.allLg,
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: context.colors.warning,
                  ),
                ),
                AppSpacing.gapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        consumable.nameEn,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        consumable.nameAr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.vGapXl,
            _DetailRow(
              icon: Icons.category_outlined,
              label: 'create_issue.category'.tr(),
              value: category?.localizedName(context.locale.languageCode) ?? 'common.na'.tr(),
            ),
            AppSpacing.vGapMd,
            _DetailRow(
              icon: Icons.check_circle_outline,
              label: 'issue.status'.tr(),
              value: consumable.isActive ? 'common.active'.tr() : 'common.inactive'.tr(),
            ),
            AppSpacing.vGapXl,
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showConsumableActions(BuildContext context, ConsumableModel consumable, bool canUpdate, bool canDelete) {
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
                title: Text('consumables.edit'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  context.push('${RoutePaths.adminConsumables}/form?id=${consumable.id}');
                },
              ),
            if (canUpdate)
              ListTile(
                leading: Icon(
                  consumable.isActive ? Icons.block : Icons.check_circle_outline,
                  color: consumable.isActive ? context.colors.error : context.colors.success,
                ),
                title: Text(consumable.isActive ? 'consumables.deactivate'.tr() : 'consumables.activate'.tr()),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await ref.read(adminConsumableActionProvider.notifier).toggleActive(consumable.id);
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(consumable.isActive ? 'consumables.deactivated'.tr() : 'consumables.activated'.tr())),
                    );
                  }
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline, color: context.colors.error),
                title: Text('common.delete'.tr(), style: TextStyle(color: context.colors.error)),
                onTap: () => _confirmDelete(context, consumable),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ConsumableModel consumable) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('common.confirm_delete'.tr()),
        content: Text('consumables.delete_confirm'.tr(namedArgs: {'name': consumable.nameEn})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(adminConsumableActionProvider.notifier).deleteConsumable(consumable.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'consumables.deleted'.tr() : 'errors.delete_failed'.tr()),
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

/// Consumable card widget
class _ConsumableCard extends StatelessWidget {
  final ConsumableModel consumable;
  final CategoryModel? category;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ConsumableCard({
    required this.consumable,
    this.category,
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
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            boxShadow: context.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.warning.withOpacity(0.1),
                  borderRadius: AppRadius.allMd,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: context.colors.warning,
                  size: 20,
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            consumable.nameEn,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!consumable.isActive)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.colors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            consumable.nameAr,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                        if (category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withOpacity(0.1),
                              borderRadius: AppRadius.badgeRadius,
                            ),
                            child: Text(
                              category!.localizedName(context.locale.languageCode),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.colors.primary,
                              ),
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
  final String? categoryName;

  const _EmptyState({required this.tabIndex, this.categoryName});

  @override
  Widget build(BuildContext context) {
    final isAllTab = tabIndex == 0;
    final title = isAllTab
        ? 'consumables.not_found'.tr()
        : 'consumables.no_in_category'.tr(namedArgs: {'category': categoryName ?? ''});
    final subtitle = isAllTab
        ? 'consumables.adjust_search'.tr()
        : 'consumables.category_appear'.tr();

    return Center(
      child: Padding(
        padding: AppSpacing.allXxl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: context.colors.textTertiary),
            AppSpacing.vGapLg,
            Text(
              title,
              textAlign: TextAlign.center,
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
