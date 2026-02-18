# Backend End-to-End (E2E) Tests

## Overview

This directory contains comprehensive E2E tests that simulate real-world API workflows from HTTP request to database persistence. These tests verify complete feature integration including authentication, authorization, business logic, database transactions, and side effects.

## Test Structure

### BaseE2ETest.php

Base class providing:
- **setupApp()**: Seeds roles and permissions before each test
- **createFullWorkflowContext()**: Creates complete test environment with all user roles and 3-level category hierarchy
- **createMinimalContext()**: Creates simplified test environment for basic scenarios
- **assertTimelineEntryExists()**: Verifies audit trail entries
- **createMultipleServiceProviders()**: Factory for testing SP selection

### Test Files

#### 1. IssueLifecycleE2ETest.php

**Purpose**: Tests complete issue workflow from creation to archival

**Scenarios**:
- ✅ Complete lifecycle: create → assign → accept → check-in → progress → finish → approve → archive
- ✅ Reassignment after rejection
- ✅ On-hold and resume workflow
- ✅ Multiple issues with different statuses

**Key Validations**:
- Timeline audit trail at each step
- Status transitions
- Assignment state management
- Media/proof uploads
- Consumables tracking
- Notification events

**Example**:
```php
// Tenant creates issue
$issueId = $this->withHeaders(authHeaders($tenant))
    ->postJson('/api/v1/issues', [...])
    ->json('data.id');

// Admin assigns to SP
$this->withHeaders(authHeaders($admin))
    ->postJson("/api/v1/admin/issues/{$issueId}/assign", [...]);

// SP accepts and completes
$this->withHeaders(authHeaders($sp))
    ->postJson("/api/v1/assignments/{$assignmentId}/accept");
```

#### 2. OfflineSyncE2ETest.php

**Purpose**: Tests offline-first mobile sync patterns

**Scenarios**:
- ✅ Offline issue creation with negative ID
- ✅ ID migration (negative → positive server ID)
- ✅ Multiple offline issues sync in FIFO order
- ✅ Duplicate sync request handling (idempotency)
- ✅ Sync failure and retry
- ✅ Category relationship preservation
- ✅ User-isolated sync operations

**Key Validations**:
- `local_id` field handling
- Server ID assignment
- Cross-tenant isolation
- Sync queue processing order

**Example**:
```php
// Simulate offline creation
$syncResponse = $this->withHeaders(authHeaders($tenant))
    ->postJson('/api/v1/issues', [
        'local_id' => $localId,
        'title' => 'Offline Created Issue',
        ...
    ]);

// Verify positive server ID returned
expect($syncResponse->json('data.id'))->toBeGreaterThan(0);
```

#### 3. MultiUserConcurrencyE2ETest.php

**Purpose**: Tests concurrent operations by multiple users

**Scenarios**:
- ✅ Two tenants create issues simultaneously
- ✅ Same SP handles multiple assignments
- ✅ Concurrent status updates
- ✅ Multiple admins manage same issue
- ✅ SP cannot access another SP's assignment
- ✅ Rapid issue creation maintains integrity

**Key Validations**:
- Data isolation between users
- Assignment locking
- Race condition handling
- Permission boundaries

**Example**:
```php
// Create issues concurrently
$response1 = $this->withHeaders(authHeaders($tenant1))
    ->postJson('/api/v1/issues', [...]);
$response2 = $this->withHeaders(authHeaders($tenant2))
    ->postJson('/api/v1/issues', [...]);

// Verify isolation
$tenant1List = $this->withHeaders(authHeaders($tenant1))
    ->getJson('/api/v1/issues');
// Should only see own issue
```

#### 4. PermissionEscalationE2ETest.php

**Purpose**: Tests permission enforcement at every layer

**Scenarios**:
- ✅ Viewer cannot modify
- ✅ Tenant cannot assign or manage
- ✅ SP cannot access admin functions
- ✅ SP cannot create issues
- ✅ Manager cannot modify Shield
- ✅ Cross-tenant data isolation
- ✅ Unauthenticated requests rejected
- ✅ Super admin bypass verification

**Key Validations**:
- HTTP 403 for unauthorized actions
- HTTP 404 for cross-tenant access (hides existence)
- HTTP 401 for unauthenticated requests
- Permission gate enforcement
- Role-based access control

**Example**:
```php
// Viewer attempts to assign
$assignAttempt = $this->withHeaders(authHeaders($viewer))
    ->postJson("/api/v1/admin/issues/{$issue}/assign", [...]);
$assignAttempt->assertStatus(403);

// Tenant attempts to view another tenant's issue
$forbiddenAccess = $this->withHeaders(authHeaders($tenant1))
    ->getJson("/api/v1/issues/{$tenant2IssueId}");
$forbiddenAccess->assertStatus(404); // Hides existence
```

#### 5. CategoryAssignmentE2ETest.php

**Purpose**: Tests category hierarchy and SP selection using materialized paths

**Scenarios**:
- ✅ SP linked to parent available for child
- ✅ SP linked to root available for all descendants
- ✅ Multiple SPs at different hierarchy levels
- ✅ SP not available for sibling categories
- ✅ Category move updates SP availability
- ✅ Inactive SP filtering
- ✅ SP with multiple category links
- ✅ Deep hierarchy path resolution (5+ levels)

**Key Validations**:
- Materialized path integrity
- Ancestor ID extraction
- SP pool calculation
- Category tree mutations

**Example**:
```php
// Create hierarchy: Root > Parent > Child
$child = Category::create([
    'parent_id' => $parent->id,
    ...
]);

// Link SP to parent
$sp->serviceProvider->categories()->attach($parent->id);

// Get SPs for child - should include SP from parent
$spList = $this->withHeaders(authHeaders($admin))
    ->getJson("/api/v1/admin/categories/{$child->id}/service-providers");

$spIds = collect($spList->json('data'))->pluck('id')->toArray();
expect($spIds)->toContain($sp->serviceProvider->id);
```

## Running E2E Tests

### Run All E2E Tests
```bash
cd backend
php artisan test tests/Feature/E2E --compact
```

### Run Specific Test File
```bash
php artisan test tests/Feature/E2E/IssueLifecycleE2ETest.php --compact
```

### Run Specific Test Method
```bash
php artisan test --filter=test_complete_issue_lifecycle_from_creation_to_archival
```

### With Coverage
```bash
php artisan test tests/Feature/E2E --coverage
```

## Test Helpers

### Authentication
```php
$user = createTenantUser();
$token = getAuthToken($user);
$headers = authHeaders($user); // Returns ['Authorization' => 'Bearer ...', 'Accept' => 'application/json']
```

### User Creation
```php
$tenant = createTenantUser();
$sp = createServiceProviderUser();
$admin = createAdminUser('super_admin'); // or 'manager', 'viewer'
```

### Database Assertions
```php
$this->assertDatabaseHas('issues', ['id' => $issueId, 'status' => 'completed']);
$this->assertTimelineEntryExists($issueId, TimelineAction::APPROVED->value, $adminId);
```

## Key Patterns

### Full Workflow Test Pattern
```php
public function test_feature_name(): void
{
    // 1. Setup context
    $context = $this->createFullWorkflowContext();
    extract($context);

    // 2. Execute workflow steps with real HTTP requests
    $response = $this->withHeaders(authHeaders($user))
        ->postJson('/api/v1/endpoint', [...]);

    // 3. Assert response
    $response->assertStatus(200)
        ->assertJsonPath('data.key', 'expected');

    // 4. Assert database state
    $this->assertDatabaseHas('table', [...]);

    // 5. Assert side effects (timeline, notifications, etc.)
    $this->assertTimelineEntryExists(...);
}
```

### Concurrency Test Pattern
```php
public function test_concurrent_operations(): void
{
    // Create users
    $user1 = createTenantUser();
    $user2 = createTenantUser();

    // Execute operations in parallel
    $response1 = $this->withHeaders(authHeaders($user1))->postJson(...);
    $response2 = $this->withHeaders(authHeaders($user2))->postJson(...);

    // Assert isolation
    $list1 = $this->withHeaders(authHeaders($user1))->getJson(...);
    $list2 = $this->withHeaders(authHeaders($user2))->getJson(...);

    // Verify no data leakage
    expect($list1->json('data'))->not->toContain(...);
}
```

### Permission Test Pattern
```php
public function test_unauthorized_action(): void
{
    $unauthorizedUser = createAdminUser('viewer');

    $response = $this->withHeaders(authHeaders($unauthorizedUser))
        ->postJson('/api/v1/admin/restricted-action', [...]);

    $response->assertStatus(403); // Forbidden
}
```

## Success Criteria

✅ All tests use real HTTP requests (no direct model manipulation)
✅ Tests verify complete data flow: request → controller → service → database
✅ Permission enforcement tested at API layer
✅ Tests are isolated (RefreshDatabase between tests)
✅ Tests cover happy paths AND error scenarios
✅ Cross-user data isolation verified
✅ Timeline audit trail verified
✅ All 5 user roles tested in realistic workflows

## CI/CD Integration

These tests are designed to run in CI pipelines:

```yaml
# .github/workflows/backend-tests.yml
- name: Run E2E Tests
  run: |
    cd backend
    php artisan test tests/Feature/E2E --parallel --processes=4
```

## Known Limitations

1. **SQLite Incompatibility**: Some migrations use MySQL-specific syntax (MODIFY COLUMN ENUM) that fails in SQLite test environment
2. **Idempotency**: Current implementation creates duplicates on retry (TODO: implement local_id deduplication)
3. **Image Upload**: Uses `UploadedFile::fake()` which doesn't test compression
4. **Notification Testing**: Not yet implemented (requires mocking notification service)

## Future Enhancements

- [ ] Add WebSocket/SSE tests for real-time notifications
- [ ] Add queue job execution tests
- [ ] Add email/SMS notification verification
- [ ] Add rate limiting tests
- [ ] Add API versioning tests
- [ ] Add GraphQL endpoint tests (if implemented)
