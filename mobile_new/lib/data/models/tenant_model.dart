/// Tenant model matching Laravel backend Tenant entity
class TenantModel {
  final int id;
  final int? userId;
  final String? unitNumber;
  final String? buildingName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // User information (from nested user object)
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final bool userIsActive;
  final String? userLocale;
  final String? profilePhotoUrl;

  // Stats
  final int? issuesCount;

  const TenantModel({
    required this.id,
    this.userId,
    this.unitNumber,
    this.buildingName,
    this.createdAt,
    this.updatedAt,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userIsActive = true,
    this.userLocale,
    this.profilePhotoUrl,
    this.issuesCount,
  });

  /// Get full address (unit + building)
  String get fullAddress {
    final parts = <String>[];
    if (unitNumber != null && unitNumber!.isNotEmpty) {
      parts.add('Unit $unitNumber');
    }
    if (buildingName != null && buildingName!.isNotEmpty) {
      parts.add(buildingName!);
    }
    return parts.join(', ');
  }

  /// Get short address for display
  String get shortAddress {
    if (unitNumber != null && unitNumber!.isNotEmpty) {
      return unitNumber!;
    }
    if (buildingName != null && buildingName!.isNotEmpty) {
      return buildingName!;
    }
    return 'N/A';
  }

  /// Check if has complete address info
  bool get hasCompleteAddress =>
      unitNumber != null &&
      unitNumber!.isNotEmpty &&
      buildingName != null &&
      buildingName!.isNotEmpty;

  TenantModel copyWith({
    int? id,
    int? userId,
    String? unitNumber,
    String? buildingName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userEmail,
    String? userPhone,
    bool? userIsActive,
    String? userLocale,
    String? profilePhotoUrl,
    int? issuesCount,
  }) {
    return TenantModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      unitNumber: unitNumber ?? this.unitNumber,
      buildingName: buildingName ?? this.buildingName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      userIsActive: userIsActive ?? this.userIsActive,
      userLocale: userLocale ?? this.userLocale,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      issuesCount: issuesCount ?? this.issuesCount,
    );
  }

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    // Extract user info from nested user object if present
    final user = json['user'] as Map<String, dynamic>?;

    // Handle building - can be string name or nested object with 'name' field
    String? buildingName;
    if (json['building_name'] is String) {
      buildingName = json['building_name'] as String?;
    } else if (json['building'] is String) {
      buildingName = json['building'] as String?;
    } else if (json['building'] is Map) {
      buildingName = (json['building'] as Map)['name'] as String?;
    }

    return TenantModel(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']),
      unitNumber: json['unit_number'] as String?,
      buildingName: buildingName,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // User info from nested user object
      userName: user?['name'] as String?,
      userEmail: user?['email'] as String?,
      userPhone: user?['phone'] as String?,
      userIsActive: user?['is_active'] as bool? ?? true,
      userLocale: user?['locale'] as String?,
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      // Stats
      issuesCount: _parseInt(json['issues_count']),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'unit_number': unitNumber,
      'building_name': buildingName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
      'issues_count': issuesCount,
      // Include user info if present
      if (userName != null || userEmail != null || userPhone != null)
        'user': {
          if (userName != null) 'name': userName,
          if (userEmail != null) 'email': userEmail,
          if (userPhone != null) 'phone': userPhone,
          'is_active': userIsActive,
          if (userLocale != null) 'locale': userLocale,
        },
    };
  }

  /// Convert to JSON for API create/update requests
  Map<String, dynamic> toCreateJson({String? password}) {
    return {
      'name': userName,
      'email': userEmail,
      if (password != null) 'password': password,
      if (userPhone != null) 'phone': userPhone,
      'unit_number': unitNumber,
      'building_name': buildingName,
      'is_active': userIsActive,
    };
  }
}
