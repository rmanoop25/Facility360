/// Time gap within a slot (available time range)
class TimeGap {
  final String start; // "HH:mm" format
  final String end;   // "HH:mm" format
  final int durationMinutes;

  const TimeGap({
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  factory TimeGap.fromJson(Map<String, dynamic> json) {
    return TimeGap(
      start: json['start']?.toString() ?? '00:00',
      end: json['end']?.toString() ?? '00:00',
      durationMinutes: json['duration_minutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'duration_minutes': durationMinutes,
    };
  }
}

/// Time slot model matching Laravel backend TimeSlot entity
class TimeSlotModel {
  final int id;
  final int? serviceProviderId;
  final int dayOfWeek; // 0=Sunday, 6=Saturday
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Capacity tracking fields (from enhanced availability API)
  final int? totalMinutes;       // Total minutes in slot
  final int? bookedMinutes;      // Currently booked minutes
  final int? availableMinutes;   // Remaining available minutes
  final int? utilizationPercent; // Percentage booked (0-100)
  final String? nextAvailableStart; // "HH:mm" format
  final String? nextAvailableEnd;   // "HH:mm" format
  final List<TimeGap>? availableGaps; // Available time gaps within slot

  const TimeSlotModel({
    required this.id,
    this.serviceProviderId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.totalMinutes,
    this.bookedMinutes,
    this.availableMinutes,
    this.utilizationPercent,
    this.nextAvailableStart,
    this.nextAvailableEnd,
    this.availableGaps,
  });

  /// Get formatted time range (e.g., "09:00 - 12:00")
  String get formattedRange => '$startTime - $endTime';

  /// Calculate duration in minutes from start to end time
  int get durationMinutes {
    try {
      // Parse HH:mm format
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      if (startParts.length != 2 || endParts.length != 2) {
        return 0;
      }

      final startHour = int.tryParse(startParts[0]) ?? 0;
      final startMinute = int.tryParse(startParts[1]) ?? 0;
      final endHour = int.tryParse(endParts[0]) ?? 0;
      final endMinute = int.tryParse(endParts[1]) ?? 0;

      final startTotalMinutes = (startHour * 60) + startMinute;
      final endTotalMinutes = (endHour * 60) + endMinute;

      // Handle case where end time is before start time (crosses midnight)
      if (endTotalMinutes < startTotalMinutes) {
        return (24 * 60) - startTotalMinutes + endTotalMinutes;
      }

      return endTotalMinutes - startTotalMinutes;
    } catch (e) {
      return 0;
    }
  }

  /// Get day name in English
  String get dayName {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[dayOfWeek.clamp(0, 6)];
  }

  /// Get short day name in English
  String get dayNameShort {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[dayOfWeek.clamp(0, 6)];
  }

  /// Get day name in Arabic
  String get dayNameAr {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return days[dayOfWeek.clamp(0, 6)];
  }

  /// Get localized day name
  String localizedDayName(String locale) =>
      locale == 'ar' ? dayNameAr : dayName;

  /// Get display name (e.g., "Monday: 09:00 - 12:00")
  String get displayName => '$dayName: $formattedRange';

  // Capacity helper methods
  /// Check if slot has available capacity
  bool get hasCapacity => (availableMinutes ?? 0) > 0;

  /// Check if slot can fit a job of given duration
  bool canFit(int durationMinutes) {
    return (availableMinutes ?? durationMinutes) >= durationMinutes;
  }

  /// Get capacity display string (e.g., "180 min available of 240 min")
  String get capacityDisplay {
    if (availableMinutes == null || totalMinutes == null) {
      return 'No capacity info';
    }
    return '$availableMinutes min available of $totalMinutes min';
  }

  /// Get next available time range (e.g., "Next: 09:00 - 10:00")
  String? get nextAvailableRange {
    if (nextAvailableStart == null || nextAvailableEnd == null) return null;
    return 'Next: $nextAvailableStart - $nextAvailableEnd';
  }

  /// Get blocked time ranges (inverse of available gaps)
  /// Returns list of {start, end} maps representing blocked times
  List<Map<String, String>> get blockedRanges {
    if (availableGaps == null || availableGaps!.isEmpty) {
      // If no gaps, assume entire slot is booked (except if 100% available)
      if ((utilizationPercent ?? 0) == 0) {
        return []; // Fully available
      }
      return []; // No gap data available
    }

    final blocked = <Map<String, String>>[];
    final gaps = availableGaps!;

    // Check if there's a blocked range before the first gap
    if (gaps.first.start != startTime) {
      blocked.add({'start': startTime, 'end': gaps.first.start});
    }

    // Check blocked ranges between gaps
    for (int i = 0; i < gaps.length - 1; i++) {
      blocked.add({'start': gaps[i].end, 'end': gaps[i + 1].start});
    }

    // Check if there's a blocked range after the last gap
    if (gaps.last.end != endTime) {
      blocked.add({'start': gaps.last.end, 'end': endTime});
    }

    return blocked;
  }

  /// Check if a given time range would overlap with blocked times
  /// startTime and endTime in "HH:mm" format
  bool wouldOverlap(String checkStart, String checkEnd) {
    if (availableGaps == null || availableGaps!.isEmpty) {
      // No gap data - assume safe if there's capacity
      return (utilizationPercent ?? 0) >= 100;
    }

    // Convert times to minutes for easier comparison
    final checkStartMins = _timeToMinutes(checkStart);
    final checkEndMins = _timeToMinutes(checkEnd);

    // Check if the range falls entirely within any available gap
    for (final gap in availableGaps!) {
      final gapStartMins = _timeToMinutes(gap.start);
      final gapEndMins = _timeToMinutes(gap.end);

      if (checkStartMins >= gapStartMins && checkEndMins <= gapEndMins) {
        return false; // Fits entirely in this gap - no overlap
      }
    }

    return true; // Doesn't fit in any gap - would overlap
  }

  /// Convert "HH:mm" time to minutes since midnight
  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final mins = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + mins;
  }

  TimeSlotModel copyWith({
    int? id,
    int? serviceProviderId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalMinutes,
    int? bookedMinutes,
    int? availableMinutes,
    int? utilizationPercent,
    String? nextAvailableStart,
    String? nextAvailableEnd,
    List<TimeGap>? availableGaps,
  }) {
    return TimeSlotModel(
      id: id ?? this.id,
      serviceProviderId: serviceProviderId ?? this.serviceProviderId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      bookedMinutes: bookedMinutes ?? this.bookedMinutes,
      availableMinutes: availableMinutes ?? this.availableMinutes,
      utilizationPercent: utilizationPercent ?? this.utilizationPercent,
      nextAvailableStart: nextAvailableStart ?? this.nextAvailableStart,
      nextAvailableEnd: nextAvailableEnd ?? this.nextAvailableEnd,
      availableGaps: availableGaps ?? this.availableGaps,
    );
  }

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      id: _parseInt(json['id']) ?? 0,
      serviceProviderId: _parseInt(json['service_provider_id']),
      dayOfWeek: _parseInt(json['day_of_week']) ?? 0,
      startTime: _parseString(json['start_time'], '00:00'),
      endTime: _parseString(json['end_time'], '00:00'),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // Capacity fields from enhanced availability API
      totalMinutes: _parseInt(json['total_minutes']),
      bookedMinutes: _parseInt(json['booked_minutes']),
      availableMinutes: _parseInt(json['available_minutes']),
      utilizationPercent: _parseInt(json['utilization_percent']),
      nextAvailableStart: json['next_available_start']?.toString(),
      nextAvailableEnd: json['next_available_end']?.toString(),
      availableGaps: json['available_gaps'] != null
          ? (json['available_gaps'] as List)
              .map((gap) => TimeGap.fromJson(gap as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  /// Helper to safely parse int from dynamic value (handles both int and String)
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  /// Helper to safely parse string from dynamic value with default
  static String _parseString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_provider_id': serviceProviderId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'total_minutes': totalMinutes,
      'booked_minutes': bookedMinutes,
      'available_minutes': availableMinutes,
      'utilization_percent': utilizationPercent,
      'next_available_start': nextAvailableStart,
      'next_available_end': nextAvailableEnd,
      'available_gaps': availableGaps?.map((gap) => gap.toJson()).toList(),
    };
  }
}
