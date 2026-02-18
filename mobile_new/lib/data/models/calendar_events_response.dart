import 'calendar_event_model.dart';

/// API response wrapper for calendar events endpoint
///
/// GET /api/v1/admin/calendar/events returns:
/// - assignments: Scheduled work with scheduled_date
/// - pending_issues: Unassigned issues shown on created_at date
class CalendarEventsResponse {
  final List<CalendarEventModel> assignments;
  final List<CalendarEventModel> pendingIssues;
  final CalendarMeta? meta;

  const CalendarEventsResponse({
    this.assignments = const [],
    this.pendingIssues = const [],
    this.meta,
  });

  /// Get all events combined (assignments + pending issues)
  List<CalendarEventModel> get allEvents => [...assignments, ...pendingIssues];

  /// Get total event count
  int get totalCount => assignments.length + pendingIssues.length;

  /// Check if response is empty
  bool get isEmpty => assignments.isEmpty && pendingIssues.isEmpty;

  /// Group all events by date (normalized to midnight)
  Map<DateTime, List<CalendarEventModel>> get eventsByDate {
    final map = <DateTime, List<CalendarEventModel>>{};
    for (final event in allEvents) {
      final normalizedDate = DateTime(
        event.scheduledDate.year,
        event.scheduledDate.month,
        event.scheduledDate.day,
      );
      map.putIfAbsent(normalizedDate, () => []).add(event);
    }
    return map;
  }

  factory CalendarEventsResponse.fromJson(Map<String, dynamic> json) {
    return CalendarEventsResponse(
      assignments: (json['assignments'] as List<dynamic>?)
              ?.map((e) =>
                  CalendarEventModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingIssues: (json['pending_issues'] as List<dynamic>?)
              ?.map((e) =>
                  CalendarEventModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      meta: json['meta'] != null
          ? CalendarMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignments': assignments.map((e) => e.toJson()).toList(),
      'pending_issues': pendingIssues.map((e) => e.toJson()).toList(),
      'meta': meta?.toJson(),
    };
  }
}

/// Calendar meta information from API response
class CalendarMeta {
  final String startDate;
  final String endDate;
  final int totalAssignments;
  final int totalPending;

  const CalendarMeta({
    required this.startDate,
    required this.endDate,
    required this.totalAssignments,
    required this.totalPending,
  });

  factory CalendarMeta.fromJson(Map<String, dynamic> json) {
    return CalendarMeta(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      totalAssignments: json['total_assignments'] as int? ?? 0,
      totalPending: json['total_pending'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate,
      'end_date': endDate,
      'total_assignments': totalAssignments,
      'total_pending': totalPending,
    };
  }
}
