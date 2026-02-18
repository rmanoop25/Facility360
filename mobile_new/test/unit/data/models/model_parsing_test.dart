import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/data/models/issue_model.dart';
import '../../../../lib/data/models/user_model.dart';
import '../../../../lib/domain/enums/issue_priority.dart';
import '../../../../lib/domain/enums/issue_status.dart';
import '../../../../lib/domain/enums/sync_status.dart';
import '../../../../lib/domain/enums/user_role.dart';

/// Tests for defensive JSON parsing in Flutter models.
///
/// These tests verify that models handle malformed, incomplete, and
/// unexpected JSON payloads without crashing. This is essential for
/// API type safety between the Laravel backend and Flutter frontend.
void main() {
  group('IssueModel.fromJson()', () {
    test('parses minimal valid JSON', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'description': 'Desc',
        'status': 'pending',
        'priority': 'medium',
      };

      final model = IssueModel.fromJson(json);

      expect(model.id, equals(1));
      expect(model.title, equals('Test'));
      expect(model.status, equals(IssueStatus.pending));
      expect(model.priority, equals(IssuePriority.medium));
    });

    test('defaults id to 0 when null', () {
      final json = {'id': null, 'title': 'No ID'};

      final model = IssueModel.fromJson(json);
      expect(model.id, equals(0));
    });

    test('parses String id using _parseInt helper', () {
      final json = {'id': '42', 'title': 'String ID'};

      final model = IssueModel.fromJson(json);
      expect(model.id, equals(42));
    });

    test('defaults title to Untitled when null', () {
      final json = {'id': 1, 'title': null};

      final model = IssueModel.fromJson(json);
      expect(model.title, equals('Untitled'));
    });

    test('defaults description to null when missing', () {
      final json = {'id': 1, 'title': 'Test'};

      final model = IssueModel.fromJson(json);
      expect(model.description, isNull);
    });

    test('handles status as string', () {
      final json = {'id': 1, 'title': 'Test', 'status': 'in_progress'};

      final model = IssueModel.fromJson(json);
      expect(model.status, equals(IssueStatus.inProgress));
    });

    test('handles status as object with value field', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'status': {'value': 'assigned', 'label': 'Assigned', 'color': 'info'},
      };

      final model = IssueModel.fromJson(json);
      expect(model.status, equals(IssueStatus.assigned));
    });

    test('defaults status to pending for invalid value', () {
      final json = {'id': 1, 'title': 'Test', 'status': 'invalid_status'};

      final model = IssueModel.fromJson(json);
      expect(model.status, equals(IssueStatus.pending));
    });

    test('handles priority as string', () {
      final json = {'id': 1, 'title': 'Test', 'priority': 'high'};

      final model = IssueModel.fromJson(json);
      expect(model.priority, equals(IssuePriority.high));
    });

    test('handles priority as object with value field', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'priority': {'value': 'low', 'label': 'Low'},
      };

      final model = IssueModel.fromJson(json);
      expect(model.priority, equals(IssuePriority.low));
    });

    test('defaults priority to medium for invalid value', () {
      final json = {'id': 1, 'title': 'Test', 'priority': 'ultra'};

      final model = IssueModel.fromJson(json);
      expect(model.priority, equals(IssuePriority.medium));
    });

    test('handles null categories as empty list', () {
      final json = {'id': 1, 'title': 'Test', 'categories': null};

      final model = IssueModel.fromJson(json);
      expect(model.categories, isEmpty);
    });

    test('handles missing categories key as empty list', () {
      final json = {'id': 1, 'title': 'Test'};

      final model = IssueModel.fromJson(json);
      expect(model.categories, isEmpty);
    });

    test('handles null media as empty list', () {
      final json = {'id': 1, 'title': 'Test', 'media': null};

      final model = IssueModel.fromJson(json);
      expect(model.media, isEmpty);
    });

    test('handles null tenant as null', () {
      final json = {'id': 1, 'title': 'Test', 'tenant': null};

      final model = IssueModel.fromJson(json);
      expect(model.tenant, isNull);
    });

    test('handles location as nested object', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'location': {
          'latitude': 24.7136,
          'longitude': 46.6753,
          'address': 'Riyadh',
        },
      };

      final model = IssueModel.fromJson(json);
      expect(model.latitude, equals(24.7136));
      expect(model.longitude, equals(46.6753));
      expect(model.address, equals('Riyadh'));
    });

    test('handles location as root-level fields', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'latitude': 25.0,
        'longitude': 55.0,
      };

      final model = IssueModel.fromJson(json);
      expect(model.latitude, equals(25.0));
      expect(model.longitude, equals(55.0));
    });

    test('handles completely empty JSON', () {
      final json = <String, dynamic>{};

      final model = IssueModel.fromJson(json);
      expect(model.id, equals(0));
      expect(model.title, equals('Untitled'));
      expect(model.status, equals(IssueStatus.pending));
      expect(model.priority, equals(IssuePriority.medium));
      expect(model.categories, isEmpty);
      expect(model.media, isEmpty);
      expect(model.assignments, isEmpty);
      expect(model.timeline, isEmpty);
    });

    test('toJson roundtrips correctly with fromJson', () {
      final original = IssueModel(
        id: 50,
        tenantId: 3,
        title: 'Roundtrip Test',
        description: 'Testing roundtrip',
        status: IssueStatus.inProgress,
        priority: IssuePriority.high,
        latitude: 24.5,
        longitude: 46.5,
        proofRequired: true,
        createdAt: DateTime(2025, 6, 15, 10, 30),
        syncStatus: SyncStatus.synced,
      );

      final json = original.toJson();
      final restored = IssueModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.tenantId, equals(original.tenantId));
      expect(restored.title, equals(original.title));
      expect(restored.description, equals(original.description));
      expect(restored.status, equals(original.status));
      expect(restored.priority, equals(original.priority));
      expect(restored.latitude, equals(original.latitude));
      expect(restored.longitude, equals(original.longitude));
      expect(restored.proofRequired, equals(original.proofRequired));
    });

    test('parses date strings correctly', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'created_at': '2025-06-15T10:30:00.000Z',
        'updated_at': '2025-06-16T14:00:00.000Z',
      };

      final model = IssueModel.fromJson(json);
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
      expect(model.createdAt!.year, equals(2025));
      expect(model.createdAt!.month, equals(6));
    });

    test('handles null dates gracefully', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'created_at': null,
        'updated_at': null,
        'cancelled_at': null,
      };

      final model = IssueModel.fromJson(json);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
      expect(model.cancelledAt, isNull);
    });

    test('parses latitude/longitude from String type', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'latitude': '24.7136',
        'longitude': '46.6753',
      };

      final model = IssueModel.fromJson(json);
      expect(model.latitude, closeTo(24.7136, 0.001));
      expect(model.longitude, closeTo(46.6753, 0.001));
    });

    test('handles current_assignment as single object', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'current_assignment': {
          'id': 10,
          'issue_id': 1,
          'service_provider_id': 5,
          'category_id': 3,
          'status': 'assigned',
          'scheduled_date': '2025-06-20',
        },
      };

      final model = IssueModel.fromJson(json);
      expect(model.assignments, hasLength(1));
      expect(model.assignments.first.id, equals(10));
    });

    test('handles current_assignment as null', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'current_assignment': null,
      };

      final model = IssueModel.fromJson(json);
      expect(model.assignments, isEmpty);
    });
  });

  group('UserModel.fromJson()', () {
    test('parses full user response', () {
      final json = {
        'id': 1,
        'name': 'Admin User',
        'email': 'admin@test.com',
        'phone': '+966500000001',
        'locale': 'en',
        'is_active': true,
        'roles': ['super_admin'],
        'permissions': ['view_issues', 'assign_issues'],
        'is_tenant': false,
        'is_service_provider': false,
        'is_admin': true,
        'tenant': null,
        'service_provider': null,
        'created_at': '2025-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals(1));
      expect(user.name, equals('Admin User'));
      expect(user.email, equals('admin@test.com'));
      expect(user.role, equals(UserRole.superAdmin));
      expect(user.isAdmin, isTrue);
      expect(user.isTenant, isFalse);
      expect(user.permissions, contains('view_issues'));
    });

    test('handles null id as 0', () {
      final json = {
        'id': null,
        'name': 'Test',
        'email': 'test@test.com',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, equals(0));
    });

    test('handles String id', () {
      final json = {
        'id': '42',
        'name': 'Test',
        'email': 'test@test.com',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, equals(42));
    });

    test('defaults name to empty string when null', () {
      final json = {
        'id': 1,
        'name': null,
        'email': 'test@test.com',
      };

      final user = UserModel.fromJson(json);
      expect(user.name, equals(''));
    });

    test('defaults locale to en when null', () {
      final json = {
        'id': 1,
        'name': 'Test',
        'email': 'test@test.com',
        'locale': null,
      };

      final user = UserModel.fromJson(json);
      expect(user.locale, equals('en'));
    });

    test('handles empty roles array', () {
      final json = {
        'id': 1,
        'name': 'Test',
        'email': 'test@test.com',
        'roles': <dynamic>[],
        'permissions': <dynamic>[],
      };

      final user = UserModel.fromJson(json);
      expect(user.roles, isEmpty);
    });

    test('handles null roles as empty', () {
      final json = {
        'id': 1,
        'name': 'Test',
        'email': 'test@test.com',
        'roles': null,
      };

      final user = UserModel.fromJson(json);
      expect(user.roles, isEmpty);
    });

    test('completely empty JSON creates valid model', () {
      final json = <String, dynamic>{};

      final user = UserModel.fromJson(json);
      expect(user.id, equals(0));
      expect(user.name, equals(''));
      expect(user.email, equals(''));
    });
  });

  group('UserModel permissions', () {
    test('super_admin bypasses all permission checks', () {
      final user = UserModel(
        id: 1,
        name: 'Admin',
        email: 'admin@test.com',
        roles: ['super_admin'],
        permissions: [], // no explicit permissions
      );

      expect(user.hasPermission('view_issues'), isTrue);
      expect(user.hasPermission('delete_tenants'), isTrue);
      expect(user.hasPermission('nonexistent_permission'), isTrue);
    });

    test('non-super_admin checks permission list', () {
      final user = UserModel(
        id: 2,
        name: 'Manager',
        email: 'manager@test.com',
        roles: ['manager'],
        permissions: ['view_issues', 'assign_issues'],
      );

      expect(user.hasPermission('view_issues'), isTrue);
      expect(user.hasPermission('assign_issues'), isTrue);
      expect(user.hasPermission('delete_tenants'), isFalse);
    });

    test('hasAnyPermission returns true if any match', () {
      final user = UserModel(
        id: 3,
        name: 'Test',
        email: 'test@test.com',
        roles: ['manager'],
        permissions: ['view_issues'],
      );

      expect(
        user.hasAnyPermission(['view_issues', 'delete_issues']),
        isTrue,
      );
      expect(
        user.hasAnyPermission(['delete_tenants', 'delete_issues']),
        isFalse,
      );
    });

    test('hasAllPermissions returns true only if all match', () {
      final user = UserModel(
        id: 4,
        name: 'Test',
        email: 'test@test.com',
        roles: ['manager'],
        permissions: ['view_issues', 'assign_issues'],
      );

      expect(
        user.hasAllPermissions(['view_issues', 'assign_issues']),
        isTrue,
      );
      expect(
        user.hasAllPermissions(['view_issues', 'delete_tenants']),
        isFalse,
      );
    });
  });

  group('UserModel.fromLoginResponse()', () {
    test('parses login response with role flags', () {
      final json = {
        'id': 5,
        'name': 'Tenant User',
        'email': 'tenant@test.com',
        'locale': 'ar',
        'roles': ['tenant'],
        'is_tenant': true,
        'is_service_provider': false,
        'is_admin': false,
      };

      final user = UserModel.fromLoginResponse(json);

      expect(user.id, equals(5));
      expect(user.name, equals('Tenant User'));
      expect(user.locale, equals('ar'));
      expect(user.isTenant, isTrue);
      expect(user.isServiceProvider, isFalse);
      expect(user.role, equals(UserRole.tenant));
      // Login response does not include permissions
      expect(user.permissions, isEmpty);
    });
  });

  group('UserModel role detection', () {
    test('detects tenant from is_tenant flag', () {
      final user = UserModel(
        id: 1,
        name: 'T',
        email: 't@t.com',
        roles: ['tenant'],
        isTenantFlag: true,
        isServiceProviderFlag: false,
        isAdminFlag: false,
      );

      expect(user.role, equals(UserRole.tenant));
    });

    test('detects service_provider from is_service_provider flag', () {
      final user = UserModel(
        id: 2,
        name: 'SP',
        email: 'sp@sp.com',
        roles: ['service_provider'],
        isTenantFlag: false,
        isServiceProviderFlag: true,
        isAdminFlag: false,
      );

      expect(user.role, equals(UserRole.serviceProvider));
    });

    test('detects manager from roles array when isAdmin', () {
      final user = UserModel(
        id: 3,
        name: 'M',
        email: 'm@m.com',
        roles: ['manager'],
        isTenantFlag: false,
        isServiceProviderFlag: false,
        isAdminFlag: true,
      );

      expect(user.role, equals(UserRole.manager));
    });

    test('detects viewer from roles array when isAdmin', () {
      final user = UserModel(
        id: 4,
        name: 'V',
        email: 'v@v.com',
        roles: ['viewer'],
        isTenantFlag: false,
        isServiceProviderFlag: false,
        isAdminFlag: true,
      );

      expect(user.role, equals(UserRole.viewer));
    });
  });

  group('UserModel.copyWith()', () {
    test('creates copy with overridden fields', () {
      final original = UserModel(
        id: 1,
        name: 'Original',
        email: 'original@test.com',
        locale: 'en',
        roles: ['tenant'],
        permissions: ['view_issues'],
      );

      final copy = original.copyWith(
        name: 'Updated',
        locale: 'ar',
      );

      expect(copy.id, equals(1));
      expect(copy.name, equals('Updated'));
      expect(copy.email, equals('original@test.com'));
      expect(copy.locale, equals('ar'));
      expect(copy.roles, equals(['tenant']));
    });
  });

  group('UserModel.toJson() roundtrip', () {
    test('toJson produces JSON that fromJson can parse back', () {
      final original = UserModel(
        id: 10,
        name: 'Roundtrip',
        email: 'roundtrip@test.com',
        phone: '+123',
        locale: 'en',
        isActive: true,
        roles: ['manager'],
        permissions: ['view_issues', 'assign_issues'],
        isTenantFlag: false,
        isServiceProviderFlag: false,
        isAdminFlag: true,
      );

      final json = original.toJson();
      final restored = UserModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.email, equals(original.email));
      expect(restored.phone, equals(original.phone));
      expect(restored.locale, equals(original.locale));
      expect(restored.roles, equals(original.roles));
      expect(restored.permissions, equals(original.permissions));
    });
  });
}
