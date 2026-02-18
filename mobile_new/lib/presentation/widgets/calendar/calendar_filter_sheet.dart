import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../domain/enums/issue_status.dart';
import '../../providers/calendar_provider.dart';

/// Bottom sheet for filtering calendar events
///
/// Filters:
/// - Status (dropdown/selector)
/// - Service provider (dropdown)
/// - Category (dropdown)
/// - Clear filters button
/// - Apply button
class CalendarFilterSheet extends ConsumerWidget {
  const CalendarFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'calendar.filter_events'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),

          // Status filter
          _buildFilterSection(
            context,
            title: 'common.status'.tr(),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _buildStatusChip(
                  context,
                  'common.all'.tr(),
                  isSelected: state.filters.status == null,
                  onTap: () => notifier.setStatusFilter(null),
                ),
                ...IssueStatus.values.map((status) => _buildStatusChip(
                      context,
                      status.label,
                      isSelected: state.filters.status == status.value,
                      onTap: () => notifier.setStatusFilter(status.value),
                    )),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Note: Service Provider and Category filters can be added later
          // For now, we'll keep it simple with just status filter

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    notifier.clearFilters();
                    Navigator.pop(context);
                  },
                  child: Text('calendar.clear_all'.tr()),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('common.apply'.tr()),
                ),
              ),
            ],
          ),

          // Safe area padding at bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: context.colors.primary.withOpacity(0.2),
      checkmarkColor: context.colors.primary,
      backgroundColor: context.colors.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? context.colors.primary : context.colors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

/// Show calendar filter bottom sheet
void showCalendarFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CalendarFilterSheet(),
  );
}
