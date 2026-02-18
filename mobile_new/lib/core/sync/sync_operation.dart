import 'package:hive/hive.dart';

/// Types of sync operations
enum SyncOperationType {
  create,
  update,
  delete,
}

/// Entity types that can be synced
enum SyncEntityType {
  issue,
  assignment,
  proof,
  timeExtension,
  // Admin entity types
  category,
  consumable,
  tenant,
  serviceProvider,
  // Location geocoding
  locationGeocode,
}

/// Represents a queued sync operation
@HiveType(typeId: 10)
class SyncOperation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String operationType; // create, update, delete

  @HiveField(2)
  final String entityType; // issue, assignment, proof

  @HiveField(3)
  final String localId;

  @HiveField(4)
  final String dataJson; // Serialized operation data

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  int retryCount;

  @HiveField(7)
  DateTime? lastAttempt;

  @HiveField(8)
  String? lastError;

  /// User ID who created this operation (for multi-user support)
  @HiveField(9)
  final int? userId;

  SyncOperation({
    required this.id,
    required this.operationType,
    required this.entityType,
    required this.localId,
    required this.dataJson,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttempt,
    this.lastError,
    this.userId,
  });

  /// Create from enum types
  factory SyncOperation.create({
    required String id,
    required SyncOperationType type,
    required SyncEntityType entity,
    required String localId,
    required String dataJson,
    int? userId,
  }) {
    return SyncOperation(
      id: id,
      operationType: type.name,
      entityType: entity.name,
      localId: localId,
      dataJson: dataJson,
      createdAt: DateTime.now(),
      userId: userId,
    );
  }

  /// Get operation type as enum
  SyncOperationType get type =>
      SyncOperationType.values.firstWhere((e) => e.name == operationType);

  /// Get entity type as enum
  SyncEntityType get entity =>
      SyncEntityType.values.firstWhere((e) => e.name == entityType);

  /// Check if should retry (max 5 retries)
  bool get shouldRetry => retryCount < 5;

  /// Calculate backoff delay based on retry count
  Duration get backoffDelay {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final seconds = 1 << retryCount;
    return Duration(seconds: seconds.clamp(1, 60));
  }

  /// Mark as attempted with optional error
  void markAttempted({String? error}) {
    retryCount++;
    lastAttempt = DateTime.now();
    lastError = error;
  }

  /// Reset retry count (used when coming back online)
  void resetRetryCount() {
    retryCount = 0;
    lastError = null;
  }

  @override
  String toString() =>
      'SyncOperation($operationType $entityType:$localId, retries:$retryCount)';
}
