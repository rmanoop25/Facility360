import 'category_model.dart';
import 'time_slot_model.dart';

/// Service Provider model matching Laravel backend ServiceProvider entity
class ServiceProviderModel {
  final int id;
  final int? userId;
  final List<int> categoryIds;
  final double? latitude;
  final double? longitude;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<CategoryModel> categories;
  final List<TimeSlotModel> timeSlots;

  // User information (from nested user object)
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userProfilePhotoUrl;

  // Stats
  final int activeJobs;
  final double? rating;

  // User account status
  final bool? userIsActive;

  const ServiceProviderModel({
    required this.id,
    this.userId,
    this.categoryIds = const [],
    this.latitude,
    this.longitude,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
    this.categories = const [],
    this.timeSlots = const [],
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userProfilePhotoUrl,
    this.activeJobs = 0,
    this.rating,
    this.userIsActive,
  });

  /// Get display name (user name or fallback)
  String get displayName => userName ?? 'Service Provider #$id';

  /// Check if provider has location set
  bool get hasLocation => latitude != null && longitude != null;

  /// Get category name with fallback (first category or 'General')
  String getCategoryName(String locale) =>
      categories.isNotEmpty ? categories.first.localizedName(locale) : 'General';

  /// Get all category names
  List<String> getCategoryNames(String locale) =>
      categories.map((c) => c.localizedName(locale)).toList();

  /// Get active time slots
  List<TimeSlotModel> get activeTimeSlots =>
      timeSlots.where((slot) => slot.isActive).toList();

  /// Check if provider has time slots configured
  bool get hasTimeSlots => timeSlots.isNotEmpty;

  /// Get Google Maps URL for location
  String? get mapsUrl {
    if (!hasLocation) return null;
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  ServiceProviderModel copyWith({
    int? id,
    int? userId,
    List<int>? categoryIds,
    double? latitude,
    double? longitude,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CategoryModel>? categories,
    List<TimeSlotModel>? timeSlots,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userProfilePhotoUrl,
    int? activeJobs,
    double? rating,
    bool? userIsActive,
  }) {
    return ServiceProviderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryIds: categoryIds ?? this.categoryIds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categories: categories ?? this.categories,
      timeSlots: timeSlots ?? this.timeSlots,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      userProfilePhotoUrl: userProfilePhotoUrl ?? this.userProfilePhotoUrl,
      activeJobs: activeJobs ?? this.activeJobs,
      rating: rating ?? this.rating,
      userIsActive: userIsActive ?? this.userIsActive,
    );
  }

  factory ServiceProviderModel.fromJson(Map<String, dynamic> json) {
    // Extract user info from nested user object if present
    final user = json['user'] as Map<String, dynamic>?;

    // Parse category IDs with backward compatibility
    List<int> parsedCategoryIds;
    if (json['category_ids'] != null) {
      // New format: array of IDs
      parsedCategoryIds = (json['category_ids'] as List<dynamic>)
          .map((e) => _parseInt(e) ?? 0)
          .where((id) => id != 0)
          .toList();
    } else if (json['category_id'] != null) {
      // Old format: single ID
      final categoryId = _parseInt(json['category_id']);
      parsedCategoryIds = categoryId != null ? [categoryId] : [];
    } else {
      parsedCategoryIds = [];
    }

    // Parse categories with backward compatibility
    List<CategoryModel> parsedCategories;
    if (json['categories'] != null) {
      // New format: array of categories
      parsedCategories = (json['categories'] as List<dynamic>)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['category'] != null) {
      // Old format: single category
      parsedCategories = [
        CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
      ];
    } else {
      parsedCategories = [];
    }

    return ServiceProviderModel(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']),
      categoryIds: parsedCategoryIds,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      categories: parsedCategories,
      timeSlots: (json['time_slots'] as List<dynamic>?)
              ?.map((e) => TimeSlotModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      userName: user?['name'] as String? ?? json['user_name'] as String?,
      userEmail: user?['email'] as String? ?? json['user_email'] as String?,
      userPhone: user?['phone'] as String? ?? json['user_phone'] as String?,
      userProfilePhotoUrl: user?['profile_photo_url'] as String? ?? json['user_profile_photo_url'] as String?,
      activeJobs: _parseInt(json['active_jobs']) ?? 0,
      rating: _parseDouble(json['rating']),
      userIsActive: user?['is_active'] as bool? ?? json['user_is_active'] as bool?,
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

  /// Helper to safely parse double from dynamic value (handles both num and String)
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is num) return value.toDouble();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_ids': categoryIds,
      'latitude': latitude,
      'longitude': longitude,
      'is_available': isAvailable,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'time_slots': timeSlots.map((e) => e.toJson()).toList(),
      'user_name': userName,
      'user_email': userEmail,
      'user_phone': userPhone,
      'user_profile_photo_url': userProfilePhotoUrl,
      'active_jobs': activeJobs,
      'rating': rating,
      'user_is_active': userIsActive,
    };
  }

  /// Convert to JSON for API create/update requests
  Map<String, dynamic> toCreateJson({String? password}) {
    return {
      'name': userName,
      'email': userEmail,
      if (password != null) 'password': password,
      if (userPhone != null) 'phone': userPhone,
      'category_ids': categoryIds,
      'is_available': isAvailable,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}
