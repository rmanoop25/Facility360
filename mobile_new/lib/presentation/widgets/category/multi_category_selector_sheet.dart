import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/multi_category_provider.dart';
import '../common/error_placeholder.dart';

/// A bottom sheet for selecting multiple categories with search and accordion UI
class MultiCategorySelectorSheet extends ConsumerStatefulWidget {
  /// Initial selected category IDs
  final Set<int> initialSelection;

  /// Called when user confirms selection
  final void Function(Set<int> selectedIds) onConfirm;

  /// Optional title override
  final String? title;

  const MultiCategorySelectorSheet({
    super.key,
    this.initialSelection = const {},
    required this.onConfirm,
    this.title,
  });

  /// Show the bottom sheet
  static Future<Set<int>?> show(
    BuildContext context, {
    Set<int> initialSelection = const {},
    String? title,
  }) async {
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiCategorySelectorSheet(
        initialSelection: initialSelection,
        title: title,
        onConfirm: (ids) => Navigator.of(context).pop(ids),
      ),
    );
  }

  @override
  ConsumerState<MultiCategorySelectorSheet> createState() =>
      _MultiCategorySelectorSheetState();
}

class _MultiCategorySelectorSheetState
    extends ConsumerState<MultiCategorySelectorSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize selection state after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(multiCategorySelectionProvider.notifier)
          .initialize(widget.initialSelection);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiCategorySelectionProvider);
    final categoriesState = ref.watch(categoriesStateProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.bottomSheetRadius,
      ),
      child: Column(
        children: [
          // Handle bar
          _HandleBar(),

          // Header
          _Header(
            title: widget.title ?? 'category_selector.title'.tr(),
            selectedCount: state.selectionCount,
            onClose: () => Navigator.of(context).pop(),
          ),

          // Search bar
          _SearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (query) {
              ref
                  .read(multiCategorySelectionProvider.notifier)
                  .setSearchQuery(query);
            },
            onClear: () {
              _searchController.clear();
              ref
                  .read(multiCategorySelectionProvider.notifier)
                  .clearSearch();
            },
          ),

          // Category list
          Expanded(
            child: categoriesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : categoriesState.error != null
                    ? ErrorPlaceholder(
                        isFullScreen: false,
                        onRetry: () =>
                            ref.read(categoriesStateProvider.notifier).refresh(),
                      )
                    : state.isSearching
                        ? _SearchResults()
                        : _AccordionCategoryList(),
          ),

          // Footer with confirm button
          _Footer(
            selectedCount: state.selectionCount,
            onClearAll: state.hasSelection
                ? () =>
                    ref.read(multiCategorySelectionProvider.notifier).clearAll()
                : null,
            onConfirm: () => widget.onConfirm(state.selectedIds),
          ),
        ],
      ),
    );
  }
}

/// Handle bar at top of sheet
class _HandleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: context.colors.border,
        borderRadius: AppRadius.allXs,
      ),
    );
  }
}

/// Header with title, count badge, and close button
class _Header extends StatelessWidget {
  final String title;
  final int selectedCount;
  final VoidCallback onClose;

  const _Header({
    required this.title,
    required this.selectedCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            title,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (selectedCount > 0) ...[
            AppSpacing.gapSm,
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: AppRadius.allFull,
              ),
              child: Text(
                '$selectedCount',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Search bar
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'category_selector.search_hint'.tr(),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.colors.textTertiary,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.clear_rounded,
                    color: context.colors.textTertiary,
                  ),
                )
              : null,
          filled: true,
          fillColor: context.colors.surface,
          border: OutlineInputBorder(
            borderRadius: AppRadius.allMd,
            borderSide: BorderSide.none,
          ),
          contentPadding: AppSpacing.horizontalLg,
        ),
      ),
    );
  }
}

/// Search results view (flat list)
class _SearchResults extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredCategories = ref.watch(filteredCategoriesProvider);
    final state = ref.watch(multiCategorySelectionProvider);
    final allCategories = ref.watch(categoriesStateProvider).categories;
    final locale = context.locale.languageCode;

    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: context.colors.textTertiary,
            ),
            AppSpacing.vGapMd,
            Text(
              'category_selector.no_results'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.horizontalLg,
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        final isSelected = state.isSelected(category.id);
        final path = allCategories.pathOf(category.id);
        final pathString = path.length > 1
            ? path
                .take(path.length - 1)
                .map((c) => c.localizedName(locale))
                .join(' > ')
            : null;

        return _CategoryCheckboxTile(
          category: category,
          isSelected: isSelected,
          subtitle: pathString,
          onTap: () {
            ref
                .read(multiCategorySelectionProvider.notifier)
                .toggleCategory(category.id);
          },
        );
      },
    );
  }
}

/// Accordion-style category list
class _AccordionCategoryList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootCategories = ref.watch(rootCategoriesProvider);

    if (rootCategories.isEmpty) {
      return Center(
        child: Text(
          'category_selector.no_results'.tr(),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.horizontalLg,
      itemCount: rootCategories.length,
      itemBuilder: (context, index) {
        return _CategoryAccordion(category: rootCategories[index]);
      },
    );
  }
}

/// Accordion for a parent category with its children
class _CategoryAccordion extends ConsumerWidget {
  final CategoryModel category;
  final int depth;

  const _CategoryAccordion({
    required this.category,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(multiCategorySelectionProvider);
    final hasChildren = ref.watch(categoryHasChildrenProvider(category.id));
    final isSelected = state.isSelected(category.id);
    final isExpanded = state.isExpanded(category.id);
    final selectedChildrenCount =
        ref.watch(selectedChildrenCountProvider(category.id));

    final locale = context.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category row with checkbox
        InkWell(
          onTap: () {
            if (hasChildren) {
              ref
                  .read(multiCategorySelectionProvider.notifier)
                  .toggleExpanded(category.id);
            } else {
              ref
                  .read(multiCategorySelectionProvider.notifier)
                  .toggleCategory(category.id);
            }
          },
          borderRadius: AppRadius.allSm,
          child: Container(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.sm + (depth * AppSpacing.xl),
              end: AppSpacing.sm,
              top: AppSpacing.md,
              bottom: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Checkbox for selection
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) {
                      ref
                          .read(multiCategorySelectionProvider.notifier)
                          .toggleCategory(category.id);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.allXs,
                    ),
                    activeColor: context.colors.primary,
                    side: BorderSide(color: context.colors.border, width: 1.5),
                  ),
                ),
                AppSpacing.gapMd,

                // Category icon
                Icon(
                  _getCategoryIcon(category.iconName),
                  size: 20,
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.textSecondary,
                ),
                AppSpacing.gapSm,

                // Category name
                Expanded(
                  child: Text(
                    category.localizedName(locale),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textPrimary,
                    ),
                  ),
                ),

                // Selected children count badge
                if (selectedChildrenCount > 0 && !isSelected) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm - 2, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withOpacity(0.1),
                      borderRadius: AppRadius.allFull,
                    ),
                    child: Text(
                      '$selectedChildrenCount',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppSpacing.gapSm,
                ],

                // Expand/collapse chevron
                if (hasChildren)
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 24,
                    color: context.colors.textTertiary,
                  ),
              ],
            ),
          ),
        ),

        // Divider
        Divider(
          height: 1,
          indent: AppSpacing.sm + (depth * AppSpacing.xl) + AppSpacing.xl + AppSpacing.lg,
          color: context.colors.border.withOpacity(0.5),
        ),

        // Children (if expanded)
        if (hasChildren && isExpanded) _ChildCategories(
          parentId: category.id,
          depth: depth + 1,
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String icon) {
    return switch (icon.toLowerCase()) {
      'plumbing' => Icons.plumbing_rounded,
      'electrical' => Icons.electrical_services_rounded,
      'hvac' => Icons.ac_unit_rounded,
      'carpentry' => Icons.carpenter_rounded,
      'painting' => Icons.format_paint_rounded,
      'cleaning' => Icons.cleaning_services_rounded,
      'security' => Icons.security_rounded,
      'landscaping' => Icons.grass_rounded,
      'pest' => Icons.bug_report_rounded,
      _ => Icons.category_rounded,
    };
  }
}

/// Children of a parent category
class _ChildCategories extends ConsumerWidget {
  final int parentId;
  final int depth;

  const _ChildCategories({
    required this.parentId,
    required this.depth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childCategoriesProvider(parentId));

    return Column(
      children: children
          .map((child) => _CategoryAccordion(
                category: child,
                depth: depth,
              ))
          .toList(),
    );
  }
}

/// Individual category checkbox tile (for search results)
class _CategoryCheckboxTile extends StatelessWidget {
  final CategoryModel category;
  final bool isSelected;
  final String? subtitle;
  final VoidCallback onTap;

  const _CategoryCheckboxTile({
    required this.category,
    required this.isSelected,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.allXs,
                ),
                activeColor: context.colors.primary,
                side: BorderSide(color: context.colors.border, width: 1.5),
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.localizedName(locale),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    AppSpacing.vGapXs,
                    Text(
                      subtitle!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer with clear all and confirm buttons
class _Footer extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onClearAll;
  final VoidCallback onConfirm;

  const _Footer({
    required this.selectedCount,
    this.onClearAll,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(
          top: BorderSide(color: context.colors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (onClearAll != null)
              TextButton(
                onPressed: onClearAll,
                child: Text(
                  'category_selector.clear_all'.tr(),
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              ),
              child: Text(
                selectedCount > 0
                    ? 'category_selector.confirm_count'
                        .tr(namedArgs: {'count': '$selectedCount'})
                    : 'common.confirm'.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

