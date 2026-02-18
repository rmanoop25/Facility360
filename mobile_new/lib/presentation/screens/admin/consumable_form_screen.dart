import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../providers/admin_consumable_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/category/single_category_selector.dart';

/// Consumable Form Screen
/// Create or edit consumable
class ConsumableFormScreen extends ConsumerStatefulWidget {
  final String? consumableId;

  const ConsumableFormScreen({super.key, this.consumableId});

  @override
  ConsumerState<ConsumableFormScreen> createState() => _ConsumableFormScreenState();
}

class _ConsumableFormScreenState extends ConsumerState<ConsumableFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameEnController = TextEditingController();
  final _nameArController = TextEditingController();

  int? _selectedCategoryId;
  bool _isActive = true;
  bool _isLoadingData = false;

  bool get _isEditing => widget.consumableId != null;
  int? get _consumableId => widget.consumableId != null ? int.tryParse(widget.consumableId!) : null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && _consumableId != null) {
      _loadConsumableData();
    }
  }

  Future<void> _loadConsumableData() async {
    setState(() => _isLoadingData = true);

    try {
      final consumable = await ref.read(adminConsumableDetailProvider(_consumableId!).future);
      if (consumable != null && mounted) {
        setState(() {
          _nameEnController.text = consumable.nameEn;
          _nameArController.text = consumable.nameAr;
          _selectedCategoryId = consumable.categoryId;
          _isActive = consumable.isActive;
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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Defensive check for category selection
    if (_selectedCategoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('consumable_form.category_required'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
      return;
    }

    final actionNotifier = ref.read(adminConsumableActionProvider.notifier);
    bool success;

    if (_isEditing && _consumableId != null) {
      success = await actionNotifier.updateConsumable(
        _consumableId!,
        nameEn: _nameEnController.text.trim(),
        nameAr: _nameArController.text.trim(),
        categoryId: _selectedCategoryId,
        isActive: _isActive,
      );
    } else {
      debugPrint('Creating consumable - Category ID: $_selectedCategoryId');
      success = await actionNotifier.createConsumable(
        nameEn: _nameEnController.text.trim(),
        nameAr: _nameArController.text.trim(),
        categoryId: _selectedCategoryId!,
        isActive: _isActive,
      );
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'consumable_form.updated'.tr()
                  : 'consumable_form.created'.tr(),
            ),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(adminConsumableActionProvider).error;
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
    final actionState = ref.watch(adminConsumableActionProvider);
    final isSubmitting = actionState.isLoading;
    final categoriesState = ref.watch(categoriesStateProvider);
    final categories = categoriesState.activeCategories;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'consumables.edit'.tr() : 'consumables.add'.tr()),
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
                          color: context.colors.warning.withOpacity(0.1),
                          borderRadius: AppRadius.allXl,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: context.colors.warning,
                        ),
                      ),
                    ),

                    AppSpacing.vGapXxl,

                    // Consumable Names
                    _SectionHeader(title: 'consumable_form.names'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameEnController,
                            decoration: InputDecoration(
                              labelText: 'consumable_form.name_en'.tr(),
                              prefixIcon: const Icon(Icons.language),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'consumable_form.name_en_required'.tr();
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vGapLg,
                          TextFormField(
                            controller: _nameArController,
                            textDirection: ui.TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText: 'consumable_form.name_ar'.tr(),
                              prefixIcon: const Icon(Icons.language),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'consumable_form.name_ar_required'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Category Selection
                    SingleCategorySelector(
                      selectedCategoryId: _selectedCategoryId,
                      onChanged: (categoryId) => setState(() => _selectedCategoryId = categoryId),
                      required: true,
                      label: 'consumable_form.category'.tr(),
                      enabled: !isSubmitting,
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
                              ? 'consumable_form.active_desc'.tr()
                              : 'consumable_form.inactive_desc'.tr(),
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
                            : Text(_isEditing ? 'consumable_form.update'.tr() : 'consumable_form.create'.tr()),
                      ),
                    ),

                    AppSpacing.vGapXxl,
                  ],
                ),
              ),
            ),
    );
  }

  IconData _getCategoryIcon(String icon) {
    return switch (icon) {
      'plumbing' => Icons.plumbing,
      'electrical' => Icons.electrical_services,
      'hvac' => Icons.ac_unit,
      'carpentry' => Icons.carpenter,
      'painting' => Icons.format_paint,
      'general' => Icons.build,
      'cleaning' => Icons.cleaning_services,
      'landscaping' => Icons.grass,
      'security' => Icons.security,
      'elevator' => Icons.elevator,
      'pool' => Icons.pool,
      'gym' => Icons.fitness_center,
      _ => Icons.category,
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
