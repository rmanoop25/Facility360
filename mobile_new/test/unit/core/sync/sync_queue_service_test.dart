import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/sync/sync_operation.dart';

/// Unit tests for the sync queue service logic.
///
/// These tests focus on the SyncOperation model and the queue's logical
/// invariants (FIFO ordering, user isolation, retry/backoff, max retries)
/// without requiring Hive initialization or a real Ref.
void main() {
  group('SyncOperation', () {
    group('factory SyncOperation.create()', () {
      test('stores enum names as strings', () {
        final op = SyncOperation.create(
          id: 'op-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'local-abc',
          dataJson: '{}',
          userId: 42,
        );

        expect(op.operationType, equals('create'));
        expect(op.entityType, equals('issue'));
        expect(op.localId, equals('local-abc'));
        expect(op.userId, equals(42));
        expect(op.retryCount, equals(0));
        expect(op.lastAttempt, isNull);
        expect(op.lastError, isNull);
      });

      test('sets createdAt to approximately now', () {
        final before = DateTime.now();
        final op = SyncOperation.create(
          id: 'op-2',
          type: SyncOperationType.update,
          entity: SyncEntityType.assignment,
          localId: 'local-xyz',
          dataJson: '{}',
        );
        final after = DateTime.now();

        expect(op.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
            isTrue);
        expect(op.createdAt.isBefore(after.add(const Duration(seconds: 1))),
            isTrue);
      });

      test('userId is null when not provided', () {
        final op = SyncOperation.create(
          id: 'op-3',
          type: SyncOperationType.delete,
          entity: SyncEntityType.tenant,
          localId: 'local-t1',
          dataJson: '{}',
        );

        expect(op.userId, isNull);
      });
    });

    group('type and entity getters', () {
      test('type getter returns correct SyncOperationType', () {
        final op = SyncOperation.create(
          id: 'op-t1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-1',
          dataJson: '{}',
        );

        expect(op.type, equals(SyncOperationType.create));
      });

      test('entity getter returns correct SyncEntityType', () {
        final op = SyncOperation.create(
          id: 'op-t2',
          type: SyncOperationType.update,
          entity: SyncEntityType.assignment,
          localId: 'l-2',
          dataJson: '{}',
        );

        expect(op.entity, equals(SyncEntityType.assignment));
      });

      test('all entity types are parseable', () {
        for (final entityType in SyncEntityType.values) {
          final op = SyncOperation.create(
            id: 'op-all-${entityType.name}',
            type: SyncOperationType.create,
            entity: entityType,
            localId: 'l-all',
            dataJson: '{}',
          );

          expect(op.entity, equals(entityType));
          expect(op.entityType, equals(entityType.name));
        }
      });

      test('all operation types are parseable', () {
        for (final opType in SyncOperationType.values) {
          final op = SyncOperation.create(
            id: 'op-type-${opType.name}',
            type: opType,
            entity: SyncEntityType.issue,
            localId: 'l-type',
            dataJson: '{}',
          );

          expect(op.type, equals(opType));
          expect(op.operationType, equals(opType.name));
        }
      });
    });

    group('shouldRetry', () {
      test('returns true when retryCount < 5', () {
        final op = SyncOperation.create(
          id: 'retry-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-r1',
          dataJson: '{}',
        );

        expect(op.shouldRetry, isTrue); // 0 retries
        op.markAttempted(error: 'fail');
        expect(op.shouldRetry, isTrue); // 1 retry
        op.markAttempted(error: 'fail');
        expect(op.shouldRetry, isTrue); // 2 retries
        op.markAttempted(error: 'fail');
        expect(op.shouldRetry, isTrue); // 3 retries
        op.markAttempted(error: 'fail');
        expect(op.shouldRetry, isTrue); // 4 retries
      });

      test('returns false when retryCount >= 5 (max retries reached)', () {
        final op = SyncOperation.create(
          id: 'retry-2',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-r2',
          dataJson: '{}',
        );

        // Exhaust all retries
        for (var i = 0; i < 5; i++) {
          op.markAttempted(error: 'fail $i');
        }

        expect(op.retryCount, equals(5));
        expect(op.shouldRetry, isFalse);
      });
    });

    group('markAttempted()', () {
      test('increments retryCount', () {
        final op = SyncOperation.create(
          id: 'mark-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-m1',
          dataJson: '{}',
        );

        expect(op.retryCount, equals(0));
        op.markAttempted();
        expect(op.retryCount, equals(1));
        op.markAttempted();
        expect(op.retryCount, equals(2));
      });

      test('sets lastAttempt timestamp', () {
        final op = SyncOperation.create(
          id: 'mark-2',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-m2',
          dataJson: '{}',
        );

        expect(op.lastAttempt, isNull);
        final before = DateTime.now();
        op.markAttempted();
        final after = DateTime.now();

        expect(op.lastAttempt, isNotNull);
        expect(op.lastAttempt!.isAfter(before.subtract(const Duration(seconds: 1))),
            isTrue);
        expect(op.lastAttempt!.isBefore(after.add(const Duration(seconds: 1))),
            isTrue);
      });

      test('records error message', () {
        final op = SyncOperation.create(
          id: 'mark-3',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-m3',
          dataJson: '{}',
        );

        op.markAttempted(error: 'Network timeout');
        expect(op.lastError, equals('Network timeout'));
      });

      test('error is null when not provided', () {
        final op = SyncOperation.create(
          id: 'mark-4',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-m4',
          dataJson: '{}',
        );

        op.markAttempted();
        expect(op.lastError, isNull);
      });

      test('overwrites previous error on subsequent attempts', () {
        final op = SyncOperation.create(
          id: 'mark-5',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-m5',
          dataJson: '{}',
        );

        op.markAttempted(error: 'First error');
        expect(op.lastError, equals('First error'));

        op.markAttempted(error: 'Second error');
        expect(op.lastError, equals('Second error'));
        expect(op.retryCount, equals(2));
      });
    });

    group('resetRetryCount()', () {
      test('resets retryCount to 0', () {
        final op = SyncOperation.create(
          id: 'reset-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-rs1',
          dataJson: '{}',
        );

        op.markAttempted(error: 'fail 1');
        op.markAttempted(error: 'fail 2');
        op.markAttempted(error: 'fail 3');
        expect(op.retryCount, equals(3));
        expect(op.lastError, equals('fail 3'));

        op.resetRetryCount();

        expect(op.retryCount, equals(0));
        expect(op.lastError, isNull);
      });

      test('makes shouldRetry true again after max retries were hit', () {
        final op = SyncOperation.create(
          id: 'reset-2',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-rs2',
          dataJson: '{}',
        );

        // Exhaust retries
        for (var i = 0; i < 5; i++) {
          op.markAttempted(error: 'fail');
        }
        expect(op.shouldRetry, isFalse);

        // Reset
        op.resetRetryCount();
        expect(op.shouldRetry, isTrue);
        expect(op.retryCount, equals(0));
      });
    });

    group('backoffDelay', () {
      test('uses exponential backoff: 1s, 2s, 4s, 8s, 16s', () {
        final op = SyncOperation.create(
          id: 'backoff-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-b1',
          dataJson: '{}',
        );

        // retryCount = 0 -> 1s (1 << 0 = 1)
        expect(op.backoffDelay, equals(const Duration(seconds: 1)));

        op.markAttempted();
        // retryCount = 1 -> 2s (1 << 1 = 2)
        expect(op.backoffDelay, equals(const Duration(seconds: 2)));

        op.markAttempted();
        // retryCount = 2 -> 4s (1 << 2 = 4)
        expect(op.backoffDelay, equals(const Duration(seconds: 4)));

        op.markAttempted();
        // retryCount = 3 -> 8s (1 << 3 = 8)
        expect(op.backoffDelay, equals(const Duration(seconds: 8)));

        op.markAttempted();
        // retryCount = 4 -> 16s (1 << 4 = 16)
        expect(op.backoffDelay, equals(const Duration(seconds: 16)));
      });

      test('clamps to 60 seconds maximum', () {
        final op = SyncOperation(
          id: 'backoff-2',
          operationType: 'create',
          entityType: 'issue',
          localId: 'l-b2',
          dataJson: '{}',
          createdAt: DateTime.now(),
          retryCount: 10, // 1 << 10 = 1024, should clamp to 60
        );

        expect(op.backoffDelay, equals(const Duration(seconds: 60)));
      });

      test('resets to 1s after resetRetryCount', () {
        final op = SyncOperation.create(
          id: 'backoff-3',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-b3',
          dataJson: '{}',
        );

        // Drive up to 4 retries
        for (var i = 0; i < 4; i++) {
          op.markAttempted();
        }
        expect(op.backoffDelay, equals(const Duration(seconds: 16)));

        op.resetRetryCount();
        expect(op.backoffDelay, equals(const Duration(seconds: 1)));
      });
    });

    group('dataJson serialization', () {
      test('preserves JSON data including nested structures', () {
        final data = {
          'title': 'Test Issue',
          'category_ids': [1, 2, 3],
          'priority': 'high',
          'latitude': 24.7136,
          'longitude': 46.6753,
          'nested': {'key': 'value'},
        };

        final op = SyncOperation.create(
          id: 'data-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-d1',
          dataJson: jsonEncode(data),
        );

        final decoded = jsonDecode(op.dataJson) as Map<String, dynamic>;
        expect(decoded['title'], equals('Test Issue'));
        expect(decoded['category_ids'], equals([1, 2, 3]));
        expect(decoded['priority'], equals('high'));
        expect(decoded['latitude'], equals(24.7136));
        expect(decoded['nested']['key'], equals('value'));
      });

      test('handles empty JSON object', () {
        final op = SyncOperation.create(
          id: 'data-2',
          type: SyncOperationType.delete,
          entity: SyncEntityType.category,
          localId: 'l-d2',
          dataJson: jsonEncode({}),
        );

        final decoded = jsonDecode(op.dataJson) as Map<String, dynamic>;
        expect(decoded, isEmpty);
      });
    });

    group('toString()', () {
      test('includes operation type, entity type, localId, and retryCount', () {
        final op = SyncOperation.create(
          id: 'str-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'my-local-id',
          dataJson: '{}',
        );

        final result = op.toString();
        expect(result, contains('create'));
        expect(result, contains('issue'));
        expect(result, contains('my-local-id'));
        expect(result, contains('retries:0'));
      });
    });
  });

  group('FIFO ordering (by createdAt)', () {
    test('operations sort chronologically by createdAt', () {
      final op1 = SyncOperation(
        id: 'fifo-1',
        operationType: 'create',
        entityType: 'issue',
        localId: 'first',
        dataJson: '{}',
        createdAt: DateTime(2025, 1, 1, 10, 0, 0),
      );

      final op2 = SyncOperation(
        id: 'fifo-2',
        operationType: 'update',
        entityType: 'assignment',
        localId: 'second',
        dataJson: '{}',
        createdAt: DateTime(2025, 1, 1, 10, 0, 1),
      );

      final op3 = SyncOperation(
        id: 'fifo-3',
        operationType: 'create',
        entityType: 'tenant',
        localId: 'third',
        dataJson: '{}',
        createdAt: DateTime(2025, 1, 1, 10, 0, 2),
      );

      // Shuffle and sort as processQueue does
      final operations = [op3, op1, op2];
      operations.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      expect(operations[0].localId, equals('first'));
      expect(operations[1].localId, equals('second'));
      expect(operations[2].localId, equals('third'));
    });
  });

  group('User isolation logic', () {
    test('operation with matching userId should be processed', () {
      final op = SyncOperation.create(
        id: 'user-1',
        type: SyncOperationType.create,
        entity: SyncEntityType.issue,
        localId: 'l-u1',
        dataJson: '{}',
        userId: 42,
      );

      const currentUserId = 42;

      // This replicates the skip logic in processQueue:
      // if (operation.userId != null && operation.userId != currentUserId) skip
      final shouldSkip =
          op.userId != null && op.userId != currentUserId;

      expect(shouldSkip, isFalse);
    });

    test('operation with different userId should be skipped', () {
      final op = SyncOperation.create(
        id: 'user-2',
        type: SyncOperationType.create,
        entity: SyncEntityType.issue,
        localId: 'l-u2',
        dataJson: '{}',
        userId: 42,
      );

      const currentUserId = 99; // Different user

      final shouldSkip =
          op.userId != null && op.userId != currentUserId;

      expect(shouldSkip, isTrue);
    });

    test('operation with null userId should be processed (legacy)', () {
      final op = SyncOperation.create(
        id: 'user-3',
        type: SyncOperationType.create,
        entity: SyncEntityType.issue,
        localId: 'l-u3',
        dataJson: '{}',
        userId: null,
      );

      const currentUserId = 42;

      // null userId means legacy operation - always attempt
      final shouldSkip =
          op.userId != null && op.userId != currentUserId;

      expect(shouldSkip, isFalse);
    });

    test('filtering operations for a specific user', () {
      final operations = [
        SyncOperation.create(
          id: 'filter-1',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-f1',
          dataJson: '{}',
          userId: 10,
        ),
        SyncOperation.create(
          id: 'filter-2',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-f2',
          dataJson: '{}',
          userId: 20,
        ),
        SyncOperation.create(
          id: 'filter-3',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-f3',
          dataJson: '{}',
          userId: 10,
        ),
        SyncOperation.create(
          id: 'filter-4',
          type: SyncOperationType.create,
          entity: SyncEntityType.issue,
          localId: 'l-f4',
          dataJson: '{}',
          userId: null, // legacy
        ),
      ];

      const currentUserId = 10;

      // Replicate the processQueue logic
      final processable = operations.where((op) {
        final shouldSkip =
            op.userId != null && op.userId != currentUserId;
        return !shouldSkip && op.shouldRetry;
      }).toList();

      // user 10 (2) + null userId legacy (1) = 3
      expect(processable.length, equals(3));
      expect(processable.map((op) => op.localId).toList(),
          containsAll(['l-f1', 'l-f3', 'l-f4']));
    });
  });

  group('Entity type coverage', () {
    test('all SyncEntityType values are distinct', () {
      final names = SyncEntityType.values.map((e) => e.name).toSet();
      expect(names.length, equals(SyncEntityType.values.length));
    });

    test('SyncEntityType includes all expected entities', () {
      final entityNames = SyncEntityType.values.map((e) => e.name).toList();
      expect(entityNames, contains('issue'));
      expect(entityNames, contains('assignment'));
      expect(entityNames, contains('proof'));
      expect(entityNames, contains('category'));
      expect(entityNames, contains('consumable'));
      expect(entityNames, contains('tenant'));
      expect(entityNames, contains('serviceProvider'));
      expect(entityNames, contains('locationGeocode'));
    });

    test('SyncOperationType includes create, update, delete', () {
      final opNames = SyncOperationType.values.map((e) => e.name).toList();
      expect(opNames, contains('create'));
      expect(opNames, contains('update'));
      expect(opNames, contains('delete'));
      expect(opNames.length, equals(3));
    });
  });

  group('Edge cases', () {
    test('operation with retryCount at exactly 5 is not retryable', () {
      final op = SyncOperation(
        id: 'edge-1',
        operationType: 'create',
        entityType: 'issue',
        localId: 'l-e1',
        dataJson: '{}',
        createdAt: DateTime.now(),
        retryCount: 5,
      );

      expect(op.shouldRetry, isFalse);
    });

    test('operation with retryCount at exactly 4 is still retryable', () {
      final op = SyncOperation(
        id: 'edge-2',
        operationType: 'create',
        entityType: 'issue',
        localId: 'l-e2',
        dataJson: '{}',
        createdAt: DateTime.now(),
        retryCount: 4,
      );

      expect(op.shouldRetry, isTrue);
    });

    test('backoff delay at retryCount 6 is clamped to 60s', () {
      final op = SyncOperation(
        id: 'edge-3',
        operationType: 'create',
        entityType: 'issue',
        localId: 'l-e3',
        dataJson: '{}',
        createdAt: DateTime.now(),
        retryCount: 6, // 1 << 6 = 64, should clamp to 60
      );

      expect(op.backoffDelay, equals(const Duration(seconds: 60)));
    });

    test('multiple resets and retries cycle correctly', () {
      final op = SyncOperation.create(
        id: 'edge-4',
        type: SyncOperationType.create,
        entity: SyncEntityType.issue,
        localId: 'l-e4',
        dataJson: '{}',
      );

      // First cycle
      for (var i = 0; i < 3; i++) {
        op.markAttempted(error: 'fail');
      }
      expect(op.retryCount, equals(3));
      expect(op.shouldRetry, isTrue);

      // Reset (simulates coming back online)
      op.resetRetryCount();
      expect(op.retryCount, equals(0));
      expect(op.shouldRetry, isTrue);
      expect(op.lastError, isNull);

      // Second cycle
      for (var i = 0; i < 5; i++) {
        op.markAttempted(error: 'fail again');
      }
      expect(op.retryCount, equals(5));
      expect(op.shouldRetry, isFalse);

      // Reset again
      op.resetRetryCount();
      expect(op.shouldRetry, isTrue);
    });
  });
}
