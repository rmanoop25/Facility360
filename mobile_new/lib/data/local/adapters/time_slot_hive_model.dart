import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/time_slot_model.dart';

/// Hive model for storing time slots locally
/// Used for caching service provider availability
@HiveType(typeId: 9)
class TimeSlotHiveModel extends HiveObject {
  /// Server ID
  @HiveField(0)
  int serverId;

  /// Service provider ID
  @HiveField(1)
  int? serviceProviderId;

  /// Day of week (0=Sunday, 6=Saturday)
  @HiveField(2)
  int dayOfWeek;

  /// Start time (HH:mm format)
  @HiveField(3)
  String startTime;

  /// End time (HH:mm format)
  @HiveField(4)
  String endTime;

  /// Active status
  @HiveField(5)
  bool isActive;

  /// Last synced timestamp
  @HiveField(6)
  DateTime syncedAt;

  /// Full JSON data for complete model restoration
  @HiveField(7)
  String? fullDataJson;

  TimeSlotHiveModel({
    required this.serverId,
    this.serviceProviderId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.syncedAt,
    this.fullDataJson,
  });

  /// Get formatted time range
  String get formattedRange => '$startTime - $endTime';

  /// Get day name in English
  String get dayName {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return days[dayOfWeek % 7];
  }

  /// Get short day name
  String get dayNameShort {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[dayOfWeek % 7];
  }

  /// Create from TimeSlotModel
  factory TimeSlotHiveModel.fromModel(TimeSlotModel model) {
    return TimeSlotHiveModel(
      serverId: model.id,
      serviceProviderId: model.serviceProviderId,
      dayOfWeek: model.dayOfWeek,
      startTime: model.startTime,
      endTime: model.endTime,
      isActive: model.isActive,
      syncedAt: DateTime.now(),
      fullDataJson: jsonEncode(model.toJson()),
    );
  }

  /// Convert to TimeSlotModel
  TimeSlotModel toModel() {
    // If we have full data, restore from it
    if (fullDataJson != null) {
      try {
        final json = jsonDecode(fullDataJson!) as Map<String, dynamic>;
        return TimeSlotModel.fromJson(json);
      } catch (_) {
        // Fall through to basic conversion
      }
    }

    // Basic conversion
    return TimeSlotModel(
      id: serverId,
      serviceProviderId: serviceProviderId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      isActive: isActive,
    );
  }

  /// Update from server (server-wins strategy)
  void updateFromServer(TimeSlotModel model) {
    serviceProviderId = model.serviceProviderId;
    dayOfWeek = model.dayOfWeek;
    startTime = model.startTime;
    endTime = model.endTime;
    isActive = model.isActive;
    syncedAt = DateTime.now();
    fullDataJson = jsonEncode(model.toJson());
  }
}
