import 'package:hive/hive.dart';

/// Hive model for storing user's last known location
/// Used for map picker default location when offline
@HiveType(typeId: 12)
class LastLocationHiveModel extends HiveObject {
  /// Location latitude
  @HiveField(0)
  double latitude;

  /// Location longitude
  @HiveField(1)
  double longitude;

  /// Address (from reverse geocoding, may be null if captured offline)
  @HiveField(2)
  String? address;

  /// Timestamp when location was captured
  @HiveField(3)
  DateTime capturedAt;

  /// User ID who captured this location
  @HiveField(4)
  int? userId;

  LastLocationHiveModel({
    required this.latitude,
    required this.longitude,
    this.address,
    required this.capturedAt,
    this.userId,
  });

  /// Check if location is recent (within last 24 hours)
  bool get isRecent {
    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(hours: 24));
    return capturedAt.isAfter(dayAgo);
  }

  /// Get age of location in hours
  int get ageInHours {
    final now = DateTime.now();
    return now.difference(capturedAt).inHours;
  }

  /// Get display text (address or coordinates)
  String get displayText {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Create from location data
  factory LastLocationHiveModel.create({
    required double latitude,
    required double longitude,
    String? address,
    int? userId,
  }) {
    return LastLocationHiveModel(
      latitude: latitude,
      longitude: longitude,
      address: address,
      capturedAt: DateTime.now(),
      userId: userId,
    );
  }

  /// Update location
  void updateLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) {
    this.latitude = latitude;
    this.longitude = longitude;
    this.address = address;
    capturedAt = DateTime.now();
  }

  /// Update address only (when geocoding completes later)
  void updateAddress(String address) {
    this.address = address;
  }
}
