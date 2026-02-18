import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/calendar_event_model.dart';

/// Individual day cell widget for calendar grid
///
/// Displays:
/// - Day number
/// - Event indicator dots (max 3 visible + "+X" label)
/// - Selection/today highlighting
/// - Different styling for current month vs other months
class CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final List<CalendarEventModel> events;
  final bool isSelected;
  final bool isToday;
  final bool isCurrentMonth;
  final VoidCallback onTap;

  const CalendarDayCell({
    super.key,
    required this.date,
    required this.events,
    required this.isSelected,
    required this.isToday,
    required this.isCurrentMonth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getBackgroundColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: isToday && !isSelected
              ? Border.all(color: context.colors.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day number
            Text(
              '${date.day}',
              style: context.textTheme.bodyMedium?.copyWith(
                color: _getTextColor(context),
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            // Event indicators
            if (events.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xs),
              _buildEventIndicators(context),
            ],
          ],
        ),
      ),
    );
  }

  /// Build event indicator dots
  Widget _buildEventIndicators(BuildContext context) {
    final visibleEvents = events.take(3).toList();
    final remainingCount = events.length > 3 ? events.length - 3 : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Show up to 3 dots
        ...visibleEvents.map((event) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _getEventStatusColor(context, event.status.value),
                shape: BoxShape.circle,
              ),
            )),

        // Show "+X" label if more than 3 events
        if (remainingCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              '+$remainingCount',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? context.colors.onPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  /// Get background color based on selection and current month
  Color _getBackgroundColor(BuildContext context) {
    if (isSelected) {
      return context.colors.primary;
    }
    if (!isCurrentMonth) {
      return context.colors.surfaceVariant;
    }
    return Colors.transparent;
  }

  /// Get text color based on selection and current month
  Color _getTextColor(BuildContext context) {
    if (isSelected) {
      return context.colors.onPrimary;
    }
    if (!isCurrentMonth) {
      return context.colors.textDisabled;
    }
    return context.colors.textPrimary;
  }

  /// Get event status color using theme extension
  Color _getEventStatusColor(BuildContext context, String statusValue) {
    return switch (statusValue) {
      'pending' => context.colors.statusPending,
      'assigned' => context.colors.statusAssigned,
      'in_progress' => context.colors.statusInProgress,
      'on_hold' => context.colors.statusOnHold,
      'finished' => context.colors.statusFinished,
      'completed' => context.colors.statusCompleted,
      'cancelled' => context.colors.statusCancelled,
      _ => context.colors.textSecondary,
    };
  }
}
