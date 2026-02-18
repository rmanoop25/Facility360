import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/data/local/adapters/issue_hive_model.dart';
import '../../../../../lib/data/models/issue_model.dart';
import '../../../../../lib/domain/enums/issue_priority.dart';
import '../../../../../lib/domain/enums/issue_status.dart';
import '../../../../../lib/domain/enums/sync_status.dart';

/// Tests for the CRITICAL toModel() overlay pattern in Hive models.
///
/// The core issue: when [fullDataJson] exists, toModel() must OVERLAY
/// local fields (status, priority, syncStatus, localId) on top of the
/// deserialized server JSON. This ensures offline-modified data is not
/// lost when restoring from cache.
void main() {
  group('IssueHiveModel.toModel()', () {
    group('with fullDataJson', () {
      test('overlays local status on top of server data', () {
        // Server data says status is "pending"
        final serverJson = _createServerIssueJson(
          id: 42,
          title: 'Server Title',
          status: 'pending',
          priority: 'low',
        );

        // But locally the user cancelled it (status changed offline)
        final hive = IssueHiveModel(
          serverId: 42,
          localId: 'local-abc',
          title: 'Server Title',
          description: 'desc',
          status: 'cancelled', // <-- changed offline
          priority: 'low',
          categoryIds: [1],
          syncStatus: 'pending', // <-- needs sync
          createdAt: DateTime(2025, 1, 1),
          fullDataJson: jsonEncode(serverJson),
        );

        final model = hive.toModel();

        // CRITICAL: status should be the LOCAL value, not the server value
        expect(model.status, equals(IssueStatus.cancelled));
        expect(model.syncStatus, equals(SyncStatus.pending));
        expect(model.localId, equals('local-abc'));
        // Title comes from fullDataJson
        expect(model.title, equals('Server Title'));
      });

      test('overlays local priority on top of server data', () {
        final serverJson = _createServerIssueJson(
          id: 10,
          title: 'Test',
          status: 'pending',
          priority: 'low', // server says low
        );

        final hive = IssueHiveModel(
          serverId: 10,
          localId: 'local-xyz',
          title: 'Test',
          status: 'pending',
          priority: 'high', // locally changed to high
          categoryIds: [],
          syncStatus: 'pending',
          createdAt: DateTime.now(),
          fullDataJson: jsonEncode(serverJson),
        );

        final model = hive.toModel();
        expect(model.priority, equals(IssuePriority.high));
      });

      test('preserves syncStatus from local field, not fullDataJson', () {
        final serverJson = _createServerIssueJson(
          id: 5,
          title: 'Sync Test',
          status: 'pending',
          priority: 'medium',
        );
        // Add sync_status to server JSON to verify it's overridden
        serverJson['sync_status'] = 'synced';

        final hive = IssueHiveModel(
          serverId: 5,
          localId: 'loc-1',
          title: 'Sync Test',
          status: 'pending',
          priority: 'medium',
          categoryIds: [],
          syncStatus: 'failed', // local says failed
          createdAt: DateTime.now(),
          fullDataJson: jsonEncode(serverJson),
        );

        final model = hive.toModel();
        expect(model.syncStatus, equals(SyncStatus.failed));
      });

      test('preserves localId from local field', () {
        final serverJson = _createServerIssueJson(
          id: 100,
          title: 'LocalId Test',
        );

        final hive = IssueHiveModel(
          serverId: 100,
          localId: 'my-unique-local-id',
          title: 'LocalId Test',
          status: 'pending',
          priority: 'medium',
          categoryIds: [],
          syncStatus: 'synced',
          createdAt: DateTime.now(),
          fullDataJson: jsonEncode(serverJson),
        );

        final model = hive.toModel();
        expect(model.localId, equals('my-unique-local-id'));
      });
    });

    group('with corrupted fullDataJson', () {
      test('falls back to basic conversion on invalid JSON', () {
        final hive = IssueHiveModel(
          serverId: 7,
          localId: 'loc-bad',
          title: 'Fallback Test',
          description: 'Should use basic fields',
          status: 'in_progress',
          priority: 'high',
          categoryIds: [1, 2],
          syncStatus: 'pending',
          createdAt: DateTime(2025, 6, 15),
          fullDataJson: 'THIS_IS_NOT_JSON',
        );

        final model = hive.toModel();

        expect(model.title, equals('Fallback Test'));
        expect(model.status, equals(IssueStatus.inProgress));
        expect(model.priority, equals(IssuePriority.high));
        expect(model.syncStatus, equals(SyncStatus.pending));
        expect(model.localId, equals('loc-bad'));
      });
    });

    group('with null fullDataJson', () {
      test('creates basic model from local fields', () {
        final hive = IssueHiveModel(
          localId: 'loc-new',
          title: 'Local Issue',
          description: 'Created offline',
          status: 'pending',
          priority: 'medium',
          categoryIds: [3],
          latitude: 24.7136,
          longitude: 46.6753,
          syncStatus: 'pending',
          createdAt: DateTime(2025, 3, 1),
          fullDataJson: null,
        );

        final model = hive.toModel();

        expect(model.title, equals('Local Issue'));
        expect(model.description, equals('Created offline'));
        expect(model.status, equals(IssueStatus.pending));
        expect(model.priority, equals(IssuePriority.medium));
        expect(model.latitude, equals(24.7136));
        expect(model.longitude, equals(46.6753));
        expect(model.syncStatus, equals(SyncStatus.pending));
        expect(model.localId, equals('loc-new'));
        // No serverId -> negative effective ID
        expect(model.id, isNegative);
      });
    });
  });

  group('IssueHiveModel.effectiveId', () {
    test('returns serverId when present', () {
      final hive = IssueHiveModel(
        serverId: 42,
        localId: 'loc-1',
        title: 'test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      expect(hive.effectiveId, equals(42));
    });

    test('returns negative hash of localId when no serverId', () {
      final hive = IssueHiveModel(
        serverId: null,
        localId: 'my-local-id',
        title: 'test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'pending',
        createdAt: DateTime.now(),
      );

      expect(hive.effectiveId, isNegative);
      expect(hive.effectiveId, equals(-'my-local-id'.hashCode.abs()));
    });
  });

  group('IssueHiveModel.fromModel()', () {
    test('correctly serializes a synced server issue', () {
      final model = IssueModel(
        id: 99,
        tenantId: 5,
        title: 'Server Issue',
        description: 'From API',
        status: IssueStatus.assigned,
        priority: IssuePriority.high,
        latitude: 25.0,
        longitude: 55.0,
        createdAt: DateTime(2025, 1, 15),
        syncStatus: SyncStatus.synced,
      );

      final hive = IssueHiveModel.fromModel(model, localId: 'roundtrip-id');

      expect(hive.serverId, equals(99));
      expect(hive.title, equals('Server Issue'));
      expect(hive.status, equals('assigned'));
      expect(hive.priority, equals('high'));
      expect(hive.syncStatus, equals('synced'));
      expect(hive.localId, equals('roundtrip-id'));
      expect(hive.fullDataJson, isNotNull);
    });

    test('roundtrips correctly: fromModel -> toModel', () {
      final original = IssueModel(
        id: 50,
        tenantId: 3,
        title: 'Roundtrip',
        description: 'Testing roundtrip',
        status: IssueStatus.inProgress,
        priority: IssuePriority.low,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime(2025, 5, 10),
      );

      final hive = IssueHiveModel.fromModel(original, localId: 'rt-id');
      final restored = hive.toModel();

      expect(restored.id, equals(50));
      expect(restored.title, equals('Roundtrip'));
      expect(restored.status, equals(IssueStatus.inProgress));
      expect(restored.priority, equals(IssuePriority.low));
      expect(restored.localId, equals('rt-id'));
    });
  });

  group('IssueHiveModel.createLocal()', () {
    test('sets correct defaults for offline-created issue', () {
      final hive = IssueHiveModel.createLocal(
        localId: 'new-offline',
        title: 'Offline Issue',
        description: 'No internet',
        categoryIds: [1, 2],
        priority: IssuePriority.high,
        latitude: 24.5,
        longitude: 46.5,
        tenantId: 10,
      );

      expect(hive.serverId, isNull);
      expect(hive.localId, equals('new-offline'));
      expect(hive.title, equals('Offline Issue'));
      expect(hive.status, equals('pending'));
      expect(hive.priority, equals('high'));
      expect(hive.syncStatus, equals('pending'));
      expect(hive.fullDataJson, isNull);
      expect(hive.categoryIds, equals([1, 2]));
      expect(hive.tenantId, equals(10));
    });

    test('defaults to medium priority', () {
      final hive = IssueHiveModel.createLocal(
        localId: 'default-priority',
        title: 'Default Priority',
        categoryIds: [1],
      );

      expect(hive.priority, equals('medium'));
    });
  });

  group('IssueHiveModel sync state methods', () {
    test('markAsSynced sets serverId, status, and timestamp', () {
      final hive = IssueHiveModel.createLocal(
        localId: 'sync-test',
        title: 'Will Sync',
        categoryIds: [1],
      );

      expect(hive.serverId, isNull);
      expect(hive.syncStatus, equals('pending'));

      hive.markAsSynced(999);

      expect(hive.serverId, equals(999));
      expect(hive.syncStatus, equals('synced'));
      expect(hive.syncedAt, isNotNull);
    });

    test('markAsFailed sets sync status to failed', () {
      final hive = IssueHiveModel.createLocal(
        localId: 'fail-test',
        title: 'Will Fail',
        categoryIds: [1],
      );

      hive.markAsFailed();

      expect(hive.syncStatus, equals('failed'));
    });

    test('markAsSyncing sets sync status to syncing', () {
      final hive = IssueHiveModel.createLocal(
        localId: 'syncing-test',
        title: 'Syncing',
        categoryIds: [1],
      );

      hive.markAsSyncing();

      expect(hive.syncStatus, equals('syncing'));
    });
  });

  group('IssueHiveModel.updateFromServer()', () {
    test('overwrites all fields from server model', () {
      final hive = IssueHiveModel.createLocal(
        localId: 'update-test',
        title: 'Old Title',
        description: 'Old desc',
        categoryIds: [1],
      );

      final serverModel = IssueModel(
        id: 777,
        tenantId: 5,
        title: 'Server Updated Title',
        description: 'Server updated desc',
        status: IssueStatus.assigned,
        priority: IssuePriority.high,
        latitude: 25.5,
        longitude: 55.5,
        syncStatus: SyncStatus.synced,
      );

      hive.updateFromServer(serverModel);

      expect(hive.serverId, equals(777));
      expect(hive.title, equals('Server Updated Title'));
      expect(hive.description, equals('Server updated desc'));
      expect(hive.status, equals('assigned'));
      expect(hive.priority, equals('high'));
      expect(hive.syncStatus, equals('synced'));
      expect(hive.syncedAt, isNotNull);
      expect(hive.fullDataJson, isNotNull);
    });
  });

  group('IssueHiveModel convenience getters', () {
    test('statusEnum parses correctly', () {
      final hive = IssueHiveModel(
        localId: 'e-1',
        title: 'test',
        status: 'in_progress',
        priority: 'high',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      expect(hive.statusEnum, equals(IssueStatus.inProgress));
    });

    test('priorityEnum parses correctly', () {
      final hive = IssueHiveModel(
        localId: 'e-2',
        title: 'test',
        status: 'pending',
        priority: 'high',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      expect(hive.priorityEnum, equals(IssuePriority.high));
    });

    test('syncStatusEnum parses correctly', () {
      final hive = IssueHiveModel(
        localId: 'e-3',
        title: 'test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'failed',
        createdAt: DateTime.now(),
      );

      expect(hive.syncStatusEnum, equals(SyncStatus.failed));
    });

    test('needsSync is true for pending and failed', () {
      final pending = IssueHiveModel(
        localId: 'ns-1',
        title: 'test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final failed = IssueHiveModel(
        localId: 'ns-2',
        title: 'test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'failed',
        createdAt: DateTime.now(),
      );

      final synced = IssueHiveModel(
        localId: 'ns-3',
        title: 'test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      expect(pending.needsSync, isTrue);
      expect(failed.needsSync, isTrue);
      expect(synced.needsSync, isFalse);
    });

    test('isSynced is true only for synced status', () {
      final synced = IssueHiveModel(
        localId: 'is-1',
        title: 'test',
        status: 'pending',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      expect(synced.isSynced, isTrue);
    });

    test('statusEnum defaults to pending for unknown value', () {
      final hive = IssueHiveModel(
        localId: 'default-1',
        title: 'test',
        status: 'unknown_garbage',
        priority: 'medium',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      expect(hive.statusEnum, equals(IssueStatus.pending));
    });

    test('priorityEnum defaults to medium for unknown value', () {
      final hive = IssueHiveModel(
        localId: 'default-2',
        title: 'test',
        status: 'pending',
        priority: 'unknown_garbage',
        categoryIds: [],
        syncStatus: 'synced',
        createdAt: DateTime.now(),
      );

      expect(hive.priorityEnum, equals(IssuePriority.medium));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _createServerIssueJson({
  int id = 1,
  String title = 'Test Issue',
  String? description = 'Test description',
  String status = 'pending',
  String priority = 'medium',
}) {
  return {
    'id': id,
    'tenant_id': 1,
    'title': title,
    'description': description,
    'status': status,
    'priority': priority,
    'latitude': null,
    'longitude': null,
    'address': null,
    'proof_required': false,
    'cancelled_reason': null,
    'cancelled_by': null,
    'cancelled_at': null,
    'created_at': '2025-01-01T00:00:00.000Z',
    'updated_at': '2025-01-01T00:00:00.000Z',
    'tenant': null,
    'categories': <Map<String, dynamic>>[],
    'assignments': <Map<String, dynamic>>[],
    'media': <Map<String, dynamic>>[],
    'timeline': <Map<String, dynamic>>[],
    'local_id': null,
    'sync_status': 'synced',
  };
}
