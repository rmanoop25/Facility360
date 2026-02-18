import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';
import '../common/error_placeholder.dart';

/// A bottom sheet for selecting a single category with search
class SingleCategorySelectorSheet extends ConsumerStatefulWidget {
  /// Initial selected category ID
  final int? initialSelection;

  /// Called when user selects a category
  final void Function(int categoryId) onSelect;

  /// Optional title override
  final String? title;

  const SingleCategorySelectorSheet({
    super.key,
    this.initialSelection,
    required this.onSelect,
    this.title,
  });

  /// Show the bottom sheet
  static Future<int?> show(
    BuildContext context, {
    int? initialSelection,
    String? title,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SingleCategorySelectorSheet(
        initialSelection: initialSelection,
        title: title,
        onSelect: (id) => Navigator.of(context).pop(id),
      ),
    );
  }

  @override
  ConsumerState<SingleCategorySelectorSheet> createState() =>
      _SingleCategorySelectorSheetState();
}

class _SingleCategorySelectorSheetState
    extends ConsumerState<SingleCategorySelectorSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _searchQuery = '';
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialSelection;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Debounce search to avoid excessive filtering
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = query.toLowerCase());
      }
    });
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<CategoryModel> _filterCategories(List<CategoryModel> categories) {
    if (_searchQuery.isEmpty) {
      return categories;
    }

    return categories.where((category) {
      final nameEn = category.nameEn.toLowerCase();
      final nameAr = category.nameAr.toLowerCase();
      return nameEn.contains(_searchQuery) || nameAr.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesStateProvider);
    final allCategories = categoriesState.activeCategories;
    final filteredCategories = _filterCategories(allCategories);

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
            title: widget.title ?? 'category_selector.select_category'.tr(),
            onClose: () => Navigator.of(context).pop(),
          ),

          // Search bar
          _SearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            onClear: _onClearSearch,
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
                    : filteredCategories.isEmpty
                        ? _EmptyState(
                            searchQuery: _searchQuery,
                          )
                        : _CategoryList(
                            categories: filteredCategories,
                            selectedCategoryId: _selectedCategoryId,
                            onSelect: (id) {
                              setState(() => _selectedCategoryId = id);
                              // Close sheet immediately after selection
                              widget.onSelect(id);
                            },
                          ),
          ),

          // Optional: Clear selection button
          if (_selectedCategoryId != null)
            _ClearButton(
              onClear: () {
                setState(() => _selectedCategoryId = null);
                Navigator.of(context).pop(null);
              },
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

/// Header with title and close button
class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _Header({
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
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

/// Search bar with clear button
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'category_selector.search_categories'.tr(),
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

/// Category list with radio selection
class _CategoryList extends ConsumerWidget {
  final List<CategoryModel> categories;
  final int? selectedCategoryId;
  final void Function(int id) onSelect;

  const _CategoryList({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCategories = ref.watch(categoriesStateProvider).categories;
    final locale = context.locale.languageCode;

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = category.id == selectedCategoryId;

        // Get breadcrumb path (ancestors only, not including self)
        final path = allCategories.pathOf(category.id);
        final breadcrumbPath = path.length > 1
            ? path
                .take(path.length - 1)
                .map((c) => c.localizedName(locale))
                .join(' > ')
            : null;

        return _CategoryRadioTile(
          category: category,
          isSelected: isSelected,
          breadcrumb: breadcrumbPath,
          onTap: () => onSelect(category.id),
        );
      },
    );
  }
}

/// Individual category tile with radio selection
class _CategoryRadioTile extends StatelessWidget {
  final CategoryModel category;
  final bool isSelected;
  final String? breadcrumb;
  final VoidCallback onTap;

  const _CategoryRadioTile({
    required this.category,
    required this.isSelected,
    this.breadcrumb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Radio button
            SizedBox(
              width: 24,
              height: 24,
              child: Radio<bool>(
                value: true,
                groupValue: isSelected,
                onChanged: (_) => onTap(),
                activeColor: context.colors.primary,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return context.colors.primary;
                  }
                  return context.colors.border;
                }),
              ),
            ),
            AppSpacing.gapMd,

            // Category icon
            if (category.icon != null) ...[
              Icon(
                _getCategoryIcon(category.icon!),
                size: 20,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
              AppSpacing.gapSm,
            ],

            // Category name and breadcrumb
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.localizedName(locale),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textPrimary,
                    ),
                  ),
                  if (breadcrumb != null) ...[
                    AppSpacing.vGapXs,
                    Text(
                      breadcrumb!,
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

/// Empty state when no categories match search
class _EmptyState extends StatelessWidget {
  final String searchQuery;

  const _EmptyState({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searchQuery.isEmpty
                ? Icons.category_rounded
                : Icons.search_off_rounded,
            size: 48,
            color: context.colors.textTertiary,
          ),
          AppSpacing.vGapMd,
          Text(
            searchQuery.isEmpty
                ? 'category_selector.no_categories'.tr()
                : 'category_selector.no_results'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clear selection button
class _ClearButton extends StatelessWidget {
  final VoidCallback onClear;

  const _ClearButton({required this.onClear});

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
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              side: BorderSide(color: context.colors.border),
            ),
            child: Text(
              'category_selector.clear_selection'.tr(),
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
