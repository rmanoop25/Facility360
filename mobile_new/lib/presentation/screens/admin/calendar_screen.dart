import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/shimmer/shimmer.dart';
import '../../widgets/calendar/calendar_day_cell.dart';
import '../../widgets/calendar/calendar_event_card.dart';
import '../../widgets/calendar/calendar_status_legend.dart';
import '../../widgets/calendar/calendar_filter_sheet.dart';

/// Admin Calendar Screen
///
/// Displays monthly calendar view with:
/// - Event indicators on dates
/// - Selected date event list
/// - Filters (status, service provider, category)
/// - Offline support with caching
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    // Load events on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarProvider.notifier).loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('nav.calendar'.tr()),
        actions: [
          // Today button
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'calendar.go_to_today'.tr(),
            onPressed: () => ref.read(calendarProvider.notifier).goToToday(),
          ),

          // Filter button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'calendar.filter_events'.tr(),
                onPressed: () => showCalendarFilterSheet(context),
              ),
              if (state.filters.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${state.filters.activeFilterCount}',
                      style: TextStyle(
                        color: context.colors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'calendar.refresh'.tr(),
            onPressed: () => ref.read(calendarProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          const OfflineBanner(),

          // Main content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(calendarProvider.notifier).refresh(),
              child: _buildContent(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(CalendarState state) {
    if (state.isInitialLoading) {
      return const CalendarShimmer();
    }

    if (state.error != null) {
      return _buildErrorState(state.error!);
    }

    return CustomScrollView(
      slivers: [
        // Status legend
        SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(height: AppSpacing.sm),
              const CalendarStatusLegend(),
              SizedBox(height: AppSpacing.md),
            ],
          ),
        ),

        // Month navigator
        SliverToBoxAdapter(
          child: _buildMonthNavigator(state),
        ),

        // Weekday labels
        SliverToBoxAdapter(
          child: _buildWeekdayLabels(),
        ),

        // Calendar grid
        SliverToBoxAdapter(
          child: _buildCalendarGrid(state),
        ),

        // Selected date event list
        if (state.selectedDate != null)
          SliverToBoxAdapter(
            child: _buildEventListSection(state),
          ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colors.error,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'calendar.load_failed'.tr(),
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => ref.read(calendarProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(CalendarState state) {
    final monthFormat = DateFormat('MMMM yyyy', context.locale.languageCode);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous month button
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(calendarProvider.notifier).previousMonth(),
          ),

          // Current month/year
          Text(
            monthFormat.format(state.focusedMonth),
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          // Next month button
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(calendarProvider.notifier).nextMonth(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    final weekdays = [
      'calendar.weekday_sun'.tr(),
      'calendar.weekday_mon'.tr(),
      'calendar.weekday_tue'.tr(),
      'calendar.weekday_wed'.tr(),
      'calendar.weekday_thu'.tr(),
      'calendar.weekday_fri'.tr(),
      'calendar.weekday_sat'.tr(),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: weekdays.map((day) => Expanded(
          child: Center(
            child: Text(
              day,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(CalendarState state) {
    final daysInMonth = _getDaysInMonth(state.focusedMonth);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 0.9,
        ),
        itemCount: daysInMonth.length,
        itemBuilder: (context, index) {
          final date = daysInMonth[index];
          final normalizedDate = DateTime(date.year, date.month, date.day);
          final dateEvents = state.eventsForDate(date);
          final normalizedSelectedDate = state.selectedDate != null
              ? DateTime(state.selectedDate!.year, state.selectedDate!.month, state.selectedDate!.day)
              : null;

          return CalendarDayCell(
            date: date,
            events: dateEvents,
            isSelected: normalizedSelectedDate == normalizedDate,
            isToday: normalizedToday == normalizedDate,
            isCurrentMonth: date.month == state.focusedMonth.month,
            onTap: () => ref.read(calendarProvider.notifier).selectDate(date),
          );
        },
      ),
    );
  }

  Widget _buildEventListSection(CalendarState state) {
    final selectedDate = state.selectedDate!;
    final events = state.eventsForDate(selectedDate);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy', context.locale.languageCode);

    return Container(
      margin: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: AppSpacing.allMd,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(selectedDate),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'calendar.events_count'.plural(events.length, namedArgs: {'count': '${events.length}'}),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(calendarProvider.notifier).clearSelection(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Event list or empty state
          if (events.isEmpty)
            _buildEmptyEventList()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: AppSpacing.allMd,
              itemCount: events.length,
              separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => CalendarEventCard(
                event: events[index],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyEventList() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: context.colors.textTertiary,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'calendar.no_events'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get all days to display in calendar grid (42 cells for 6 weeks)
  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    // Start from Sunday of the week containing the 1st
    final startDate = firstDay.subtract(Duration(days: firstDay.weekday % 7));

    // Generate 42 days (6 weeks * 7 days)
    return List.generate(42, (index) => startDate.add(Duration(days: index)));
  }
}
