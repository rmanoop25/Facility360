import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'multi_category_chips_display.dart';
import 'multi_category_selector_sheet.dart';

/// A complete multi-category selector widget that combines display and sheet trigger
///
/// Usage:
/// ```dart
/// MultiCategorySelector(
///   selectedIds: _selectedCategoryIds,
///   onChanged: (ids) => setState(() => _selectedCategoryIds = ids),
///   required: true,
///   label: 'create_issue.category'.tr(),
/// )
/// ```
class MultiCategorySelector extends ConsumerWidget {
  /// Set of currently selected category IDs
  final Set<int> selectedIds;

  /// Called when selection changes
  final void Function(Set<int> ids) onChanged;

  /// Whether at least one category is required
  final bool required;

  /// Label text displayed above the selector
  final String? label;

  /// Placeholder text when no categories selected
  final String? placeholder;

  /// Title for the selector sheet
  final String? sheetTitle;

  /// Maximum visible chips before showing "+N more"
  final int maxVisibleChips;

  /// Whether the selector is enabled
  final bool enabled;

  const MultiCategorySelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    this.required = false,
    this.label,
    this.placeholder,
    this.sheetTitle,
    this.maxVisibleChips = 3,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MultiCategoriesChipsDisplay(
      selectedIds: selectedIds,
      onTap: () => _openSelector(context),
      onRemove: enabled ? _removeCategory : null,
      maxVisible: maxVisibleChips,
      placeholder: placeholder ?? 'category_selector.select_categories'.tr(),
      required: required,
      label: label,
      enabled: enabled,
    );
  }

  void _removeCategory(int id) {
    final newSelection = Set<int>.from(selectedIds)..remove(id);
    onChanged(newSelection);
  }

  Future<void> _openSelector(BuildContext context) async {
    final result = await MultiCategorySelectorSheet.show(
      context,
      initialSelection: selectedIds,
      title: sheetTitle,
    );

    if (result != null) {
      onChanged(result);
    }
  }
}
