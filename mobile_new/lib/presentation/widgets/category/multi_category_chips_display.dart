import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';

/// A compact chip display showing selected categories with remove buttons
class MultiCategoriesChipsDisplay extends ConsumerWidget {
  /// Set of selected category IDs
  final Set<int> selectedIds;

  /// Called when user taps the container (to open selector)
  final VoidCallback onTap;

  /// Called when user removes a single category
  final void Function(int id)? onRemove;

  /// Maximum visible chips before showing "+N more"
  final int maxVisible;

  /// Placeholder text when no categories selected
  final String? placeholder;

  /// Whether to show required indicator
  final bool required;

  /// Label text
  final String? label;

  /// Whether selection is enabled
  final bool enabled;

  const MultiCategoriesChipsDisplay({
    super.key,
    required this.selectedIds,
    required this.onTap,
    this.onRemove,
    this.maxVisible = 3,
    this.placeholder,
    this.required = false,
    this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesStateProvider).categories;
    final locale = context.locale.languageCode;

    // Get selected categories in order
    final selectedCategories = categories
        .where((c) => selectedIds.contains(c.id))
        .toList();

    // Split into visible and overflow
    final visibleCategories = selectedCategories.take(maxVisible).toList();
    final overflowCount = selectedCategories.length - maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (required) ...[
                AppSpacing.gapXs,
                Text(
                  '*',
                  style: context.textTheme.labelLarge?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.vGapSm,
        ],

        // Chips container
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.allMd,
          child: Container(
            width: double.infinity,
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.allMd,
              border: Border.all(
                color: enabled
                    ? context.colors.border
                    : context.colors.border.withOpacity(0.5),
              ),
            ),
            child: selectedCategories.isEmpty
                ? _EmptyState(
                    placeholder: placeholder ??
                        'category_selector.select_categories'.tr(),
                    enabled: enabled,
                  )
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ...visibleCategories.map(
                        (category) => _CategoryChip(
                          category: category,
                          locale: locale,
                          onRemove: enabled && onRemove != null
                              ? () => onRemove!(category.id)
                              : null,
                        ),
                      ),
                      if (overflowCount > 0)
                        _OverflowChip(count: overflowCount),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Empty state placeholder
class _EmptyState extends StatelessWidget {
  final String placeholder;
  final bool enabled;

  const _EmptyState({
    required this.placeholder,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.category_rounded,
          size: 20,
          color: enabled
              ? context.colors.textTertiary
              : context.colors.textTertiary.withOpacity(0.5),
        ),
        AppSpacing.gapSm,
        Text(
          placeholder,
          style: context.textTheme.bodyMedium?.copyWith(
            color: enabled
                ? context.colors.textTertiary
                : context.colors.textTertiary.withOpacity(0.5),
          ),
        ),
        const Spacer(),
        Icon(
          Icons.arrow_drop_down_rounded,
          color: enabled
              ? context.colors.textTertiary
              : context.colors.textTertiary.withOpacity(0.5),
        ),
      ],
    );
  }
}

/// Individual category chip with optional remove button
class _CategoryChip extends StatelessWidget {
  final CategoryModel category;
  final String locale;
  final VoidCallback? onRemove;

  const _CategoryChip({
    required this.category,
    required this.locale,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.1),
        borderRadius: AppRadius.badgeRadius,
        border: Border.all(
          color: context.colors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category.localizedName(locale),
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onRemove != null) ...[
            AppSpacing.gapXs,
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: context.colors.primary.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Overflow indicator chip showing "+N more"
class _OverflowChip extends StatelessWidget {
  final int count;

  const _OverflowChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: context.colors.textTertiary.withOpacity(0.1),
        borderRadius: AppRadius.badgeRadius,
      ),
      child: Text(
        'category_selector.more'.tr(namedArgs: {'count': '$count'}),
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
