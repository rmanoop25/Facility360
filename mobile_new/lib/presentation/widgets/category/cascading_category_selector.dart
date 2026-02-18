import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';

/// A cascading category selector that allows drilling down through hierarchy
///
/// Features:
/// - Shows root categories first
/// - On tap, reveals children if any
/// - Only allows final selection of leaf categories
/// - Shows breadcrumb of selected path
/// - Supports going back to parent level
class CascadingCategorySelector extends ConsumerWidget {
  /// Called when a leaf category is selected
  final void Function(CategoryModel category)? onCategorySelected;

  /// Called when selection is cleared
  final VoidCallback? onClear;

  /// Whether to show the clear button
  final bool showClearButton;

  /// Custom error widget
  final Widget? errorWidget;

  const CascadingCategorySelector({
    super.key,
    this.onCategorySelected,
    this.onClear,
    this.showClearButton = true,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesStateProvider);
    final cascadingState = ref.watch(cascadingCategoryProvider);
    final currentCategories = ref.watch(currentLevelCategoriesProvider);

    if (categoriesState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (categoriesState.error != null) {
      return errorWidget ?? _DefaultErrorWidget(
        error: categoriesState.error!,
        onRetry: () => ref.read(categoriesStateProvider.notifier).refresh(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb (if we have selected categories)
        if (cascadingState.selectedPath.isNotEmpty) ...[
          _CategoryBreadcrumb(
            selectedPath: cascadingState.selectedPath,
            categories: categoriesState.categories,
            onTapBreadcrumb: (index) {
              // Navigate back to that level
              final notifier = ref.read(cascadingCategoryProvider.notifier);
              if (index == 0) {
                notifier.reset();
              } else {
                // Set selection to the category at that index
                notifier.setSelection(cascadingState.selectedPath[index - 1]);
              }
            },
            onClear: showClearButton ? () {
              ref.read(cascadingCategoryProvider.notifier).reset();
              onClear?.call();
            } : null,
          ),
          AppSpacing.vGapMd,
        ],

        // Current level categories or completion state
        if (cascadingState.isComplete) ...[
          // Show selected category as chip
          _SelectedCategoryChip(
            category: _findCategory(
              categoriesState.categories,
              cascadingState.selectedCategoryId!,
            )!,
            onClear: () {
              ref.read(cascadingCategoryProvider.notifier).goBack();
            },
          ),
        ] else ...[
          // Show categories at current level
          if (currentCategories.isEmpty) ...[
            _EmptyState(),
          ] else ...[
            // Back button if not at root level
            if (cascadingState.selectedPath.isNotEmpty) ...[
              _BackButton(
                onTap: () {
                  ref.read(cascadingCategoryProvider.notifier).goBack();
                },
              ),
              AppSpacing.vGapSm,
            ],

            // Category chips
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: currentCategories.map((category) {
                return _CascadingCategoryChip(
                  category: category,
                  hasChildren: ref.watch(categoryHasChildrenProvider(category.id)),
                  onTap: () {
                    final notifier = ref.read(cascadingCategoryProvider.notifier);
                    notifier.selectCategory(category.id);

                    // Check if this selection completes the cascade
                    final newState = ref.read(cascadingCategoryProvider);
                    if (newState.isComplete) {
                      onCategorySelected?.call(category);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ],
    );
  }

  CategoryModel? _findCategory(List<CategoryModel> categories, int id) {
    return categories.where((c) => c.id == id).firstOrNull;
  }
}

/// Category breadcrumb showing selected path
class _CategoryBreadcrumb extends StatelessWidget {
  final List<int> selectedPath;
  final List<CategoryModel> categories;
  final void Function(int index) onTapBreadcrumb;
  final VoidCallback? onClear;

  const _CategoryBreadcrumb({
    required this.selectedPath,
    required this.categories,
    required this.onTapBreadcrumb,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final pathCategories = selectedPath
        .map((id) => categories.where((c) => c.id == id).firstOrNull)
        .whereType<CategoryModel>()
        .toList();

    final locale = context.locale.languageCode;

    return Container(
      padding: AppSpacing.allSm,
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.05),
        borderRadius: AppRadius.allSm,
        border: Border.all(color: context.colors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 16,
            color: context.colors.primary,
          ),
          AppSpacing.gapSm,
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Root "All Categories" tap target
                  GestureDetector(
                    onTap: () => onTapBreadcrumb(0),
                    child: Text(
                      'create_issue.all_categories'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ...pathCategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    final isLast = index == pathCategories.length - 1;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            locale == 'ar'
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                            size: 14,
                            color: context.colors.textTertiary,
                          ),
                        ),
                        GestureDetector(
                          onTap: isLast ? null : () => onTapBreadcrumb(index + 1),
                          child: Text(
                            category.localizedName(locale),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: isLast
                                  ? context.colors.textPrimary
                                  : context.colors.primary,
                              fontWeight: isLast
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          if (onClear != null) ...[
            AppSpacing.gapSm,
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.close,
                size: 18,
                color: context.colors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual category chip in cascading selector
class _CascadingCategoryChip extends StatelessWidget {
  final CategoryModel category;
  final bool hasChildren;
  final VoidCallback onTap;

  const _CascadingCategoryChip({
    required this.category,
    required this.hasChildren,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: AppRadius.badgeRadius,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCategoryIcon(category.iconName),
              size: 18,
              color: context.colors.textSecondary,
            ),
            AppSpacing.gapSm,
            Text(
              category.localizedName(locale),
              style: context.textTheme.labelLarge?.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            if (hasChildren) ...[
              AppSpacing.gapXs,
              Icon(
                locale == 'ar' ? Icons.chevron_left : Icons.chevron_right,
                size: 16,
                color: context.colors.textTertiary,
              ),
            ],
          ],
        ),
      ),
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
      _ => Icons.build_rounded,
    };
  }
}

/// Selected category chip (shown when leaf is selected)
class _SelectedCategoryChip extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onClear;

  const _SelectedCategoryChip({
    required this.category,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: AppRadius.badgeRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: context.colors.onPrimary,
          ),
          AppSpacing.gapSm,
          Text(
            category.localizedName(locale),
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapSm,
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.close,
              size: 18,
              color: context.colors.onPrimary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back button to go to parent level
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.border.withOpacity(0.3),
          borderRadius: AppRadius.badgeRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: context.colors.textSecondary,
            ),
            AppSpacing.gapXs,
            Text(
              'common.back'.tr(),
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no categories at current level
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.colors.textTertiary,
          ),
          AppSpacing.gapMd,
          Text(
            'create_issue.no_subcategories'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Default error widget
class _DefaultErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _DefaultErrorWidget({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.errorBg,
        borderRadius: AppRadius.allMd,
      ),
      child: Column(
        children: [
          Text(
            error,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          ),
          AppSpacing.vGapSm,
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }
}
