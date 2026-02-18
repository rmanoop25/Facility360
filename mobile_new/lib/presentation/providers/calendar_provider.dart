import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/repositories/calendar_repository.dart';

// ============================================================================
// CALENDAR STATE & PROVIDER
// ============================================================================

/// State for calendar view with filters and selection
class CalendarState {
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final List<CalendarEventModel> events;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final CalendarFilters filters;

  const CalendarState({
    required this.focusedMonth,
    this.selectedDate,
    this.events = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.filters = const CalendarFilters(),
  });

  CalendarState copyWith({
    DateTime? focusedMonth,
    DateTime? selectedDate,
    List<CalendarEventModel>? events,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    CalendarFilters? filters,
    bool clearError = false,
    bool clearSelectedDate = false,
  }) {
    return CalendarState(
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      filters: filters ?? this.filters,
    );
  }

  /// Check if initial load is in progress
  bool get isInitialLoading => isLoading && events.isEmpty;

  /// Group events by date (normalized to midnight)
  Map<DateTime, List<CalendarEventModel>> get eventsByDate {
    final map = <DateTime, List<CalendarEventModel>>{};
    for (final event in events) {
      final normalizedDate = DateTime(
        event.scheduledDate.year,
        event.scheduledDate.month,
        event.scheduledDate.day,
      );
      map.putIfAbsent(normalizedDate, () => []).add(event);
    }
    return map;
  }

  /// Get events for a specific date
  List<CalendarEventModel> eventsForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return eventsByDate[normalizedDate] ?? [];
  }

  /// Get total event count
  int get totalEventsCount => events.length;

  /// Check if date has events
  bool hasEventsOn(DateTime date) {
    return eventsForDate(date).isNotEmpty;
  }
}

/// Calendar filters
class CalendarFilters {
  final String? status;
  final int? serviceProviderId;
  final int? categoryId;

  const CalendarFilters({
    this.status,
    this.serviceProviderId,
    this.categoryId,
  });

  CalendarFilters copyWith({
    String? status,
    int? serviceProviderId,
    int? categoryId,
    bool clearStatus = false,
    bool clearServiceProvider = false,
    bool clearCategory = false,
  }) {
    return CalendarFilters(
      status: clearStatus ? null : (status ?? this.status),
      serviceProviderId: clearServiceProvider
          ? null
          : (serviceProviderId ?? this.serviceProviderId),
      categoryId:
          clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters =>
      status != null || serviceProviderId != null || categoryId != null;

  /// Get filter count
  int get activeFilterCount =>
      (status != null ? 1 : 0) +
      (serviceProviderId != null ? 1 : 0) +
      (categoryId != null ? 1 : 0);
}

/// Calendar notifier with month navigation and filtering
class CalendarNotifier extends StateNotifier<CalendarState> {
  final CalendarRepository _repository;

  CalendarNotifier(this._repository)
      : super(CalendarState(
          focusedMonth: DateTime(DateTime.now().year, DateTime.now().month),
        )) {
    // Load events on initialization
    loadEvents();
  }

  /// Load events for the focused month
  Future<void> loadEvents({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(
      isLoading: true,
      isRefreshing: refresh,
      clearError: true,
    );

    try {
      final response = await _repository.getMonthEvents(
        year: state.focusedMonth.year,
        month: state.focusedMonth.month,
        status: state.filters.status,
        serviceProviderId: state.filters.serviceProviderId,
        categoryId: state.filters.categoryId,
        forceRefresh: refresh,
      );

      state = state.copyWith(
        events: response.allEvents,
        isLoading: false,
        isRefreshing: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.message,
      );
    } catch (e, stackTrace) {
      debugPrint('CalendarNotifier: Unexpected error - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Failed to load calendar events. Please try again.',
      );
    }
  }

  /// Refresh events from server
  Future<void> refresh() async {
    await loadEvents(refresh: true);
  }

  /// Select a date
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  /// Clear selected date
  void clearSelection() {
    state = state.copyWith(clearSelectedDate: true);
  }

  /// Change focused month and reload events
  void changeFocusedMonth(DateTime month) {
    state = state.copyWith(
      focusedMonth: DateTime(month.year, month.month),
      clearSelectedDate: true,
    );
    loadEvents();
  }

  /// Go to next month
  void nextMonth() {
    final nextMonth = DateTime(
      state.focusedMonth.year,
      state.focusedMonth.month + 1,
    );
    changeFocusedMonth(nextMonth);
  }

  /// Go to previous month
  void previousMonth() {
    final prevMonth = DateTime(
      state.focusedMonth.year,
      state.focusedMonth.month - 1,
    );
    changeFocusedMonth(prevMonth);
  }

  /// Go to today's month
  void goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    changeFocusedMonth(DateTime(now.year, now.month));
    selectDate(today);
  }

  /// Set status filter
  void setStatusFilter(String? status) {
    if (state.filters.status == status) return;
    state = state.copyWith(
      filters: state.filters.copyWith(status: status),
    );
    loadEvents();
  }

  /// Set service provider filter
  void setServiceProviderFilter(int? serviceProviderId) {
    if (state.filters.serviceProviderId == serviceProviderId) return;
    state = state.copyWith(
      filters: state.filters.copyWith(serviceProviderId: serviceProviderId),
    );
    loadEvents();
  }

  /// Set category filter
  void setCategoryFilter(int? categoryId) {
    if (state.filters.categoryId == categoryId) return;
    state = state.copyWith(
      filters: state.filters.copyWith(categoryId: categoryId),
    );
    loadEvents();
  }

  /// Clear all filters
  void clearFilters() {
    if (!state.filters.hasActiveFilters) return;
    state = state.copyWith(
      filters: const CalendarFilters(),
    );
    loadEvents();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for calendar
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  return CalendarNotifier(repository);
});

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Provider for calendar loading state
final calendarLoadingProvider = Provider<bool>((ref) {
  return ref.watch(calendarProvider).isLoading;
});

/// Provider for calendar error state
final calendarErrorProvider = Provider<String?>((ref) {
  return ref.watch(calendarProvider).error;
});

/// Provider for events by date
final eventsByDateProvider =
    Provider<Map<DateTime, List<CalendarEventModel>>>((ref) {
  return ref.watch(calendarProvider).eventsByDate;
});

/// Provider for selected date events
final selectedDateEventsProvider =
    Provider<List<CalendarEventModel>?>((ref) {
  final state = ref.watch(calendarProvider);
  if (state.selectedDate == null) return null;
  return state.eventsForDate(state.selectedDate!);
});

/// Provider for active filters count
final activeFiltersCountProvider = Provider<int>((ref) {
  return ref.watch(calendarProvider).filters.activeFilterCount;
});
