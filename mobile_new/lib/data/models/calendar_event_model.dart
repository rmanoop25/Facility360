/// Calendar event model matching Laravel backend calendar API response
///
/// Represents both assignment events (scheduled work) and pending issue events
class CalendarEventModel {
  final String id;
  final String type; // 'assignment' or 'pending_issue'
  final int issueId;
  final String title;
  final DateTime scheduledDate;
  final String? startTime;
  final String? endTime;
  final bool allDay;
  final EventStatusInfo status;
  final ServiceProviderInfo? serviceProvider;
  final CategoryInfo? category;
  final List<CategoryInfo>? categories; // For pending issues
  final TenantInfo tenant;
  final PriorityInfo priority;
  final TimeSlotInfo? timeSlot;
  final DateTime? createdAt;

  const CalendarEventModel({
    required this.id,
    required this.type,
    required this.issueId,
    required this.title,
    required this.scheduledDate,
    this.startTime,
    this.endTime,
    this.allDay = false,
    required this.status,
    this.serviceProvider,
    this.category,
    this.categories,
    required this.tenant,
    required this.priority,
    this.timeSlot,
    this.createdAt,
  });

  /// Check if this is an assignment event
  bool get isAssignment => type == 'assignment';

  /// Check if this is a pending issue event
  bool get isPendingIssue => type == 'pending_issue';

  /// Get display time (formatted time range or "All Day")
  String get displayTime {
    if (allDay || startTime == null || endTime == null) {
      return 'All Day';
    }
    return '$startTime - $endTime';
  }

  /// Get category names (for pending issues with multiple categories)
  String getCategoryNames() {
    if (categories != null && categories!.isNotEmpty) {
      return categories!.map((c) => c.name).join(', ');
    }
    return category?.name ?? '';
  }

  CalendarEventModel copyWith({
    String? id,
    String? type,
    int? issueId,
    String? title,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
    bool? allDay,
    EventStatusInfo? status,
    ServiceProviderInfo? serviceProvider,
    CategoryInfo? category,
    List<CategoryInfo>? categories,
    TenantInfo? tenant,
    PriorityInfo? priority,
    TimeSlotInfo? timeSlot,
    DateTime? createdAt,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      type: type ?? this.type,
      issueId: issueId ?? this.issueId,
      title: title ?? this.title,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      allDay: allDay ?? this.allDay,
      status: status ?? this.status,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      tenant: tenant ?? this.tenant,
      priority: priority ?? this.priority,
      timeSlot: timeSlot ?? this.timeSlot,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'].toString(),
      type: json['type'] as String,
      issueId: _parseInt(json['issue_id']) ?? 0,
      title: json['title'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      allDay: json['all_day'] as bool? ?? false,
      status: EventStatusInfo.fromJson(json['status'] as Map<String, dynamic>),
      serviceProvider: json['service_provider'] != null
          ? ServiceProviderInfo.fromJson(
              json['service_provider'] as Map<String, dynamic>)
          : null,
      category: json['category'] != null
          ? CategoryInfo.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      categories: json['categories'] != null
          ? (json['categories'] as List<dynamic>)
              .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      tenant: TenantInfo.fromJson(json['tenant'] as Map<String, dynamic>),
      priority: PriorityInfo.fromJson(json['priority'] as Map<String, dynamic>),
      timeSlot: json['time_slot'] != null
          ? TimeSlotInfo.fromJson(json['time_slot'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Helper to safely parse int from dynamic value
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'issue_id': issueId,
      'title': title,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'all_day': allDay,
      'status': status.toJson(),
      'service_provider': serviceProvider?.toJson(),
      'category': category?.toJson(),
      'categories': categories?.map((e) => e.toJson()).toList(),
      'tenant': tenant.toJson(),
      'priority': priority.toJson(),
      'time_slot': timeSlot?.toJson(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Event status information
class EventStatusInfo {
  final String value;
  final String label;
  final String color;
  final String? icon;

  const EventStatusInfo({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  factory EventStatusInfo.fromJson(Map<String, dynamic> json) {
    return EventStatusInfo(
      value: json['value'] as String,
      label: json['label'] as String,
      color: json['color'] as String,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
      'color': color,
      'icon': icon,
    };
  }
}

/// Service provider information
class ServiceProviderInfo {
  final int id;
  final String name;

  const ServiceProviderInfo({
    required this.id,
    required this.name,
  });

  factory ServiceProviderInfo.fromJson(Map<String, dynamic> json) {
    return ServiceProviderInfo(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Category information
class CategoryInfo {
  final int id;
  final String name;

  const CategoryInfo({
    required this.id,
    required this.name,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Tenant information
class TenantInfo {
  final int id;
  final String name;
  final String? unit;

  const TenantInfo({
    required this.id,
    required this.name,
    this.unit,
  });

  factory TenantInfo.fromJson(Map<String, dynamic> json) {
    return TenantInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
    };
  }
}

/// Priority information
class PriorityInfo {
  final String value;
  final String label;
  final String color;

  const PriorityInfo({
    required this.value,
    required this.label,
    required this.color,
  });

  factory PriorityInfo.fromJson(Map<String, dynamic> json) {
    return PriorityInfo(
      value: json['value'] as String,
      label: json['label'] as String,
      color: json['color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
      'color': color,
    };
  }
}

/// Time slot information
class TimeSlotInfo {
  final int id;
  final int dayOfWeek;
  final String dayName;
  final String startTime;
  final String endTime;
  final String displayName;

  const TimeSlotInfo({
    required this.id,
    required this.dayOfWeek,
    required this.dayName,
    required this.startTime,
    required this.endTime,
    required this.displayName,
  });

  factory TimeSlotInfo.fromJson(Map<String, dynamic> json) {
    return TimeSlotInfo(
      id: json['id'] as int,
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      dayName: json['day_name'] as String? ?? '',
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      displayName: json['display_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_of_week': dayOfWeek,
      'day_name': dayName,
      'start_time': startTime,
      'end_time': endTime,
      'display_name': displayName,
    };
  }
}
