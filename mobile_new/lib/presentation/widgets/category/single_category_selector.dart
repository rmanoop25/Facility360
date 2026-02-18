import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';
import 'single_category_selector_sheet.dart';

/// A single category selector widget that displays the selected category with hierarchy
///
/// Usage:
/// ```dart
/// SingleCategorySelector(
///   selectedCategoryId: _selectedCategoryId,
///   onChanged: (id) => setState(() => _selectedCategoryId = id),
///   required: true,
///   label: 'consumable_form.category'.tr(),
/// )
/// ```
class SingleCategorySelector extends ConsumerWidget {
  /// Currently selected category ID
  final int? selectedCategoryId;

  /// Called when selection changes
  final void Function(int? id) onChanged;

  /// Whether a category is required
  final bool required;

  /// Label text displayed above the selector
  final String? label;

  /// Placeholder text when no category selected
  final String? placeholder;

  /// Title for the selector sheet
  final String? sheetTitle;

  /// Whether the selector is enabled
  final bool enabled;

  /// Error message to display (for validation)
  final String? errorText;

  const SingleCategorySelector({
    super.key,
    required this.selectedCategoryId,
    required this.onChanged,
    this.required = false,
    this.label,
    this.placeholder,
    this.sheetTitle,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesStateProvider).categories;
    final locale = context.locale.languageCode;

    // Get selected category if any
    CategoryModel? selectedCategory;
    List<CategoryModel> breadcrumb = [];

    if (selectedCategoryId != null) {
      selectedCategory = categories
          .where((c) => c.id == selectedCategoryId)
          .firstOrNull;

      if (selectedCategory != null) {
        // Get full path (ancestors + self) for breadcrumb
        breadcrumb = ref.watch(categoryPathProvider(selectedCategoryId!));
      }
    }

    final hasError = errorText != null && errorText!.isNotEmpty;

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

        // Category selector container
        InkWell(
          onTap: enabled ? () => _openSelector(context) : null,
          borderRadius: AppRadius.allMd,
          child: Container(
            width: double.infinity,
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.allMd,
              border: Border.all(
                color: hasError
                    ? context.colors.error
                    : enabled
                        ? context.colors.border
                        : context.colors.border.withOpacity(0.5),
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: selectedCategory == null
                ? _EmptyState(
                    placeholder: placeholder ??
                        'category_selector.select_category'.tr(),
                    enabled: enabled,
                  )
                : _CategoryDisplay(
                    category: selectedCategory,
                    breadcrumb: breadcrumb,
                    locale: locale,
                    enabled: enabled,
                    onClear: !required && enabled
                        ? () => onChanged(null)
                        : null,
                  ),
          ),
        ),

        // Error text
        if (hasError) ...[
          AppSpacing.vGapXs,
          Padding(
            padding: EdgeInsets.only(left: AppSpacing.md),
            child: Text(
              errorText!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final result = await SingleCategorySelectorSheet.show(
      context,
      initialSelection: selectedCategoryId,
      title: sheetTitle,
    );

    if (result != null) {
      onChanged(result);
    }
  }
}

/// Empty state placeholder when no category is selected
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
        Expanded(
          child: Text(
            placeholder,
            style: context.textTheme.bodyMedium?.copyWith(
              color: enabled
                  ? context.colors.textTertiary
                  : context.colors.textTertiary.withOpacity(0.5),
            ),
          ),
        ),
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

/// Display selected category with breadcrumb path
class _CategoryDisplay extends StatelessWidget {
  final CategoryModel category;
  final List<CategoryModel> breadcrumb;
  final String locale;
  final bool enabled;
  final VoidCallback? onClear;

  const _CategoryDisplay({
    required this.category,
    required this.breadcrumb,
    required this.locale,
    required this.enabled,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // Build breadcrumb text (e.g., "HVAC > Cooling > AC Units")
    final breadcrumbText = breadcrumb
        .map((c) => c.localizedName(locale))
        .join(' > ');

    return Row(
      children: [
        // Category icon
        if (category.icon != null)
          Icon(
            _getCategoryIcon(category.icon!),
            size: 20,
            color: enabled
                ? context.colors.primary
                : context.colors.primary.withOpacity(0.5),
          ),
        if (category.icon != null) AppSpacing.gapSm,

        // Breadcrumb text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.localizedName(locale),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? context.colors.textPrimary
                      : context.colors.textPrimary.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (breadcrumb.length > 1) ...[
                AppSpacing.vGapXs,
                Text(
                  breadcrumbText,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: enabled
                        ? context.colors.textTertiary
                        : context.colors.textTertiary.withOpacity(0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Clear button or dropdown icon
        if (onClear != null)
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: context.colors.textTertiary,
            ),
          )
        else
          Icon(
            Icons.arrow_drop_down_rounded,
            color: enabled
                ? context.colors.textTertiary
                : context.colors.textTertiary.withOpacity(0.5),
          ),
      ],
    );
  }

  /// Map icon string to Flutter IconData
  IconData _getCategoryIcon(String iconName) {
    // Remove 'heroicon-o-' prefix if present
    final name = iconName.replaceAll('heroicon-o-', '');

    return switch (name) {
      'sun' => Icons.wb_sunny_rounded,
      'wrench-screwdriver' => Icons.build_rounded,
      'home' => Icons.home_rounded,
      'light-bulb' => Icons.lightbulb_rounded,
      'cog' => Icons.settings_rounded,
      'fire' => Icons.local_fire_department_rounded,
      'bolt' => Icons.bolt_rounded,
      'water' => Icons.water_drop_rounded,
      'trash' => Icons.delete_rounded,
      'beaker' => Icons.science_rounded,
      'shield-check' => Icons.shield_rounded,
      'cube' => Icons.category_rounded,
      'wrench' => Icons.construction_rounded,
      'paint-brush' => Icons.brush_rounded,
      'hammer' => Icons.handyman_rounded,
      _ => Icons.category_rounded,
    };
  }
}
