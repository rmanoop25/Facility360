import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/category_model.dart';
import '../../providers/admin_category_provider.dart';

/// Category Form Screen
/// Create or edit category with parent selection
class CategoryFormScreen extends ConsumerStatefulWidget {
  final String? categoryId;
  final String? parentId;

  const CategoryFormScreen({super.key, this.categoryId, this.parentId});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameEnController = TextEditingController();
  final _nameArController = TextEditingController();
  final _descriptionEnController = TextEditingController();
  final _descriptionArController = TextEditingController();

  String _selectedIcon = 'general';
  bool _isActive = true;
  bool _isLoadingData = false;
  int? _selectedParentId;
  int? _currentCategoryDepth;

  bool get _isEditing => widget.categoryId != null;
  int? get _categoryId => widget.categoryId != null ? int.tryParse(widget.categoryId!) : null;

  final _availableIcons = [
    ('plumbing', Icons.plumbing_rounded, 'Plumbing'),
    ('electrical', Icons.electrical_services_rounded, 'Electrical'),
    ('hvac', Icons.ac_unit_rounded, 'HVAC'),
    ('carpentry', Icons.carpenter_rounded, 'Carpentry'),
    ('painting', Icons.format_paint_rounded, 'Painting'),
    ('general', Icons.build_rounded, 'General'),
    ('cleaning', Icons.cleaning_services_rounded, 'Cleaning'),
    ('landscaping', Icons.grass_rounded, 'Landscaping'),
    ('security', Icons.security_rounded, 'Security'),
    ('elevator', Icons.elevator_rounded, 'Elevator'),
    ('pool', Icons.pool_rounded, 'Pool'),
    ('gym', Icons.fitness_center_rounded, 'Gym'),
  ];

  @override
  void initState() {
    super.initState();
    // Set initial parent if provided via route
    if (widget.parentId != null) {
      _selectedParentId = int.tryParse(widget.parentId!);
    }
    if (_isEditing && _categoryId != null) {
      _loadCategoryData();
    }
  }

  Future<void> _loadCategoryData() async {
    setState(() => _isLoadingData = true);

    try {
      final category = await ref.read(adminCategoryDetailProvider(_categoryId!).future);
      if (category != null && mounted) {
        setState(() {
          _nameEnController.text = category.nameEn;
          _nameArController.text = category.nameAr;
          _descriptionEnController.text = category.descriptionEn ?? '';
          _descriptionArController.text = category.descriptionAr ?? '';
          _selectedIcon = category.icon ?? 'general';
          _isActive = category.isActive;
          _selectedParentId = category.parentId;
          _currentCategoryDepth = category.depth;
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('errors.load_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameArController.dispose();
    _descriptionEnController.dispose();
    _descriptionArController.dispose();
    super.dispose();
  }

  /// Filter out the current category and its descendants from parent selection
  List<CategoryModel> _getSelectableParents(List<CategoryModel> allCategories) {
    if (!_isEditing || _categoryId == null) {
      return allCategories;
    }

    // Get current category's path to filter out descendants
    final currentCategory = allCategories.where((c) => c.id == _categoryId).firstOrNull;
    if (currentCategory == null) {
      return allCategories;
    }

    // Filter out self and any category whose path starts with current category's path
    return allCategories.where((c) {
      // Exclude self
      if (c.id == _categoryId) return false;

      // Exclude descendants (categories whose path contains current category's path)
      if (currentCategory.path != null && c.path != null) {
        // A category is a descendant if its path starts with the current category's path followed by /
        if (c.path!.startsWith('${currentCategory.path}/')) return false;
      }

      // Check by parentId chain as backup
      if (c.parentId == _categoryId) return false;

      return true;
    }).toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final actionNotifier = ref.read(adminCategoryActionProvider.notifier);
    bool success;

    if (_isEditing && _categoryId != null) {
      // For update, use -1 to indicate "set to null" (make root), null means "don't change"
      final parentIdToSend = _selectedParentId;

      success = await actionNotifier.updateCategory(
        _categoryId!,
        nameEn: _nameEnController.text.trim(),
        nameAr: _nameArController.text.trim(),
        parentId: parentIdToSend,
        descriptionEn: _descriptionEnController.text.trim().isEmpty
            ? null
            : _descriptionEnController.text.trim(),
        descriptionAr: _descriptionArController.text.trim().isEmpty
            ? null
            : _descriptionArController.text.trim(),
        icon: _selectedIcon,
        isActive: _isActive,
      );
    } else {
      success = await actionNotifier.createCategory(
        nameEn: _nameEnController.text.trim(),
        nameAr: _nameArController.text.trim(),
        parentId: _selectedParentId,
        descriptionEn: _descriptionEnController.text.trim().isEmpty
            ? null
            : _descriptionEnController.text.trim(),
        descriptionAr: _descriptionArController.text.trim().isEmpty
            ? null
            : _descriptionArController.text.trim(),
        icon: _selectedIcon,
        isActive: _isActive,
      );
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'category_form.updated'.tr()
                  : 'category_form.created'.tr(),
            ),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(adminCategoryActionProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'errors.save_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminCategoryActionProvider);
    final categoryListState = ref.watch(adminCategoryListProvider);
    final isSubmitting = actionState.isLoading;
    final locale = context.locale.languageCode;

    // Get selectable parents (all categories minus self and descendants)
    final selectableParents = _getSelectableParents(categoryListState.categories);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'categories_list.edit'.tr() : 'categories_list.add'.tr()),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: AppSpacing.screen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Preview
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: context.colors.primary.withOpacity(0.1),
                          borderRadius: AppRadius.allXl,
                        ),
                        child: Icon(
                          _getIconData(_selectedIcon),
                          size: 48,
                          color: context.colors.primary,
                        ),
                      ),
                    ),

                    AppSpacing.vGapXxl,

                    // Parent Category Selection
                    _SectionHeader(title: 'category_form.parent_category'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'category_form.parent_help'.tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                          AppSpacing.vGapMd,
                          _ParentCategoryDropdown(
                            categories: selectableParents,
                            selectedParentId: _selectedParentId,
                            locale: locale,
                            onChanged: (parentId) {
                              setState(() => _selectedParentId = parentId);
                            },
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Icon Selection
                    _SectionHeader(title: 'category_form.select_icon'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final (iconKey, iconData, _) = _availableIcons[index];
                          final isSelected = _selectedIcon == iconKey;

                          return Material(
                            color: isSelected
                                ? context.colors.primary.withOpacity(0.1)
                                : context.colors.surfaceVariant,
                            borderRadius: AppRadius.allMd,
                            child: InkWell(
                              onTap: () => setState(() => _selectedIcon = iconKey),
                              borderRadius: AppRadius.allMd,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: AppRadius.allMd,
                                  border: Border.all(
                                    color: isSelected
                                        ? context.colors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  iconData,
                                  color: isSelected
                                      ? context.colors.primary
                                      : context.colors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Category Names
                    _SectionHeader(title: 'category_form.category_names'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameEnController,
                            decoration: InputDecoration(
                              labelText: 'category_form.name_en'.tr(),
                              prefixIcon: const Icon(Icons.language_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'category_form.name_en_required'.tr();
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vGapLg,
                          TextFormField(
                            controller: _nameArController,
                            textDirection: ui.TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText: 'category_form.name_ar'.tr(),
                              prefixIcon: const Icon(Icons.language_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'category_form.name_ar_required'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Description (optional)
                    _SectionHeader(title: 'common.description'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _descriptionEnController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'category_form.description_en'.tr(),
                              alignLabelWithHint: true,
                            ),
                          ),
                          AppSpacing.vGapLg,
                          TextFormField(
                            controller: _descriptionArController,
                            maxLines: 3,
                            textDirection: ui.TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText: 'category_form.description_ar'.tr(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Status
                    _SectionHeader(title: 'issue.status'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: SwitchListTile(
                        title: Text('common.active'.tr()),
                        subtitle: Text(
                          _isActive
                              ? 'category_form.active_desc'.tr()
                              : 'category_form.inactive_desc'.tr(),
                        ),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    AppSpacing.vGapXxl,

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : _submit,
                        child: isSubmitting
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(context.colors.onPrimary),
                                ),
                              )
                            : Text(_isEditing ? 'category_form.update'.tr() : 'category_form.create'.tr()),
                      ),
                    ),

                    AppSpacing.vGapXxl,
                  ],
                ),
              ),
            ),
    );
  }

  IconData _getIconData(String iconKey) {
    final match = _availableIcons.where((i) => i.$1 == iconKey).firstOrNull;
    return match?.$2 ?? Icons.category_rounded;
  }
}

/// Parent category dropdown with tree-like display
class _ParentCategoryDropdown extends StatelessWidget {
  final List<CategoryModel> categories;
  final int? selectedParentId;
  final String locale;
  final ValueChanged<int?> onChanged;

  const _ParentCategoryDropdown({
    required this.categories,
    required this.selectedParentId,
    required this.locale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Build sorted list with proper hierarchy (roots first, then children)
    final sortedCategories = _buildSortedList(categories);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.allMd,
      ),
      child: DropdownButtonFormField<int?>(
        value: selectedParentId,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.account_tree_rounded,
            color: context.colors.textSecondary,
          ),
        ),
        hint: Text('category_form.no_parent'.tr()),
        items: [
          // "No Parent" option
          DropdownMenuItem<int?>(
            value: null,
            child: Row(
              children: [
                Icon(
                  Icons.home_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
                AppSpacing.gapSm,
                Text(
                  'category_form.root_category'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Category options with indentation
          ...sortedCategories.map((category) {
            final indent = category.depth * 16.0;
            return DropdownMenuItem<int?>(
              value: category.id,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: indent),
                child: Row(
                  children: [
                    if (category.depth > 0) ...[
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 14,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDepthColor(context, category.depth).withOpacity(0.1),
                        borderRadius: AppRadius.badgeRadius,
                      ),
                      child: Text(
                        category.depth == 0 ? 'L0' : 'L${category.depth}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _getDepthColor(context, category.depth),
                        ),
                      ),
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        category.localizedName(locale),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        onChanged: onChanged,
      ),
    );
  }

  /// Build a sorted list that shows hierarchy (roots first, then their children, etc.)
  List<CategoryModel> _buildSortedList(List<CategoryModel> categories) {
    final result = <CategoryModel>[];
    final roots = categories.where((c) => c.parentId == null || c.isRoot).toList();
    roots.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    void addWithChildren(CategoryModel category) {
      result.add(category);
      final children = categories.where((c) => c.parentId == category.id).toList();
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final child in children) {
        addWithChildren(child);
      }
    }

    for (final root in roots) {
      addWithChildren(root);
    }

    return result;
  }

  Color _getDepthColor(BuildContext context, int depth) {
    return switch (depth) {
      0 => context.colors.primary,
      1 => context.colors.info,
      2 => context.colors.success,
      _ => context.colors.warning,
    };
  }
}

/// Section header
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

/// Form card wrapper
class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: child,
    );
  }
}
