<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

/*
|--------------------------------------------------------------------------
| Admin API Test Helpers
|--------------------------------------------------------------------------
| These helper functions are specific to Admin API tests and complement
| the global helpers defined in tests/Pest.php
*/

/**
 * Create a tenant with associated user for testing.
 */
function createTestTenant(array $userAttributes = [], array $tenantAttributes = []): Tenant
{
    $user = User::factory()->create(array_merge([
        'is_active' => true,
        'locale' => 'en',
    ], $userAttributes));

    return Tenant::factory()->create(array_merge([
        'user_id' => $user->id,
    ], $tenantAttributes));
}

/**
 * Create a service provider with associated user for testing.
 */
function createTestServiceProvider(array $userAttributes = [], array $providerAttributes = []): ServiceProvider
{
    $user = User::factory()->create(array_merge([
        'is_active' => true,
        'locale' => 'en',
    ], $userAttributes));

    $category = $providerAttributes['category_id'] ?? null;
    if (!$category) {
        $category = Category::factory()->create()->id;
    }

    return ServiceProvider::factory()->create(array_merge([
        'user_id' => $user->id,
        'category_id' => $category,
    ], $providerAttributes));
}

/**
 * Create an issue with a tenant for testing.
 */
function createTestIssue(array $attributes = []): Issue
{
    if (!isset($attributes['tenant_id'])) {
        $tenant = createTestTenant();
        $attributes['tenant_id'] = $tenant->id;
    }

    return Issue::factory()->create(array_merge([
        'status' => IssueStatus::PENDING,
        'priority' => IssuePriority::MEDIUM,
    ], $attributes));
}

/**
 * Create a time slot for a service provider.
 */
function createTestTimeSlot(ServiceProvider $provider, int $dayOfWeek = null): TimeSlot
{
    return TimeSlot::factory()->create([
        'service_provider_id' => $provider->id,
        'day_of_week' => $dayOfWeek ?? now()->dayOfWeek,
        'start_time' => '09:00:00',
        'end_time' => '10:00:00',
        'is_active' => true,
    ]);
}

/*
|--------------------------------------------------------------------------
| Role-Based Access Tests
|--------------------------------------------------------------------------
*/

describe('Role-Based Access Control', function () {

    it('allows super_admin to access all admin endpoints', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues');

        expect($response->status())->not->toBe(403);
    });

    it('allows manager to access most admin endpoints', function () {
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues');

        expect($response->status())->not->toBe(403);
    });

    it('allows viewer to access view-only endpoints', function () {
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues');

        expect($response->status())->not->toBe(403);
    });

    it('denies non-admin users access to admin endpoints', function () {
        ensureRolesExist();

        $user = User::factory()->create(['is_active' => true]);
        $token = getAuthToken($user);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues');

        expect($response->status())->toBe(403);
    });

    it('denies viewer from modifying resources', function () {
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/admin/tenants', [
                'name' => 'Test Tenant',
                'email' => 'test@example.com',
                'password' => 'password123',
                'unit_number' => 'A101',
            ]);

        expect($response->status())->toBe(403);
    });

    it('denies manager from deleting tenants', function () {
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);
        $tenant = createTestTenant();

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/tenants/{$tenant->id}");

        expect($response->status())->toBe(403);
    });

    it('allows super_admin to delete tenants', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);
        $tenant = createTestTenant();

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/tenants/{$tenant->id}");

        expect($response->status())->toBe(200);
    });

    it('denies manager from deleting service providers', function () {
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);
        $provider = createTestServiceProvider();

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/service-providers/{$provider->id}");

        expect($response->status())->toBe(403);
    });

    it('allows super_admin to delete service providers', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);
        $provider = createTestServiceProvider();

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/service-providers/{$provider->id}");

        expect($response->status())->toBe(200);
    });

    it('returns 401 for unauthenticated requests', function () {
        $response = $this->getJson('/api/v1/admin/issues');

        expect($response->status())->toBe(401);
    });

});

/*
|--------------------------------------------------------------------------
| Admin Issue Management Tests
|--------------------------------------------------------------------------
*/

describe('Admin Issue Management', function () {

    describe('GET /api/v1/admin/issues', function () {

        it('lists all issues with pagination', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            // Create multiple issues from different tenants
            createTestIssue();
            createTestIssue();
            createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/issues');

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data'))->toHaveCount(3)
                ->and($response->json('meta'))->toHaveKeys(['current_page', 'last_page', 'per_page', 'total']);
        });

        it('filters issues by status', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestIssue(['status' => IssueStatus::PENDING]);
            createTestIssue(['status' => IssueStatus::ASSIGNED]);
            createTestIssue(['status' => IssueStatus::PENDING]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/issues?status=pending');

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

        it('filters issues by priority', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestIssue(['priority' => IssuePriority::HIGH]);
            createTestIssue(['priority' => IssuePriority::LOW]);
            createTestIssue(['priority' => IssuePriority::HIGH]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/issues?priority=high');

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

        it('searches issues by title', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestIssue(['title' => 'Broken AC unit']);
            createTestIssue(['title' => 'Water leak in bathroom']);
            createTestIssue(['title' => 'AC not cooling']);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/issues?search=AC');

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

        it('filters issues by tenant', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $tenant = createTestTenant();
            createTestIssue(['tenant_id' => $tenant->id]);
            createTestIssue(['tenant_id' => $tenant->id]);
            createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/issues?tenant_id={$tenant->id}");

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

        it('supports custom pagination', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            for ($i = 0; $i < 10; $i++) {
                createTestIssue();
            }

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/issues?per_page=5');

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(5)
                ->and($response->json('meta.per_page'))->toBe(5)
                ->and($response->json('meta.total'))->toBe(10);
        });

        it('supports sorting', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestIssue(['priority' => IssuePriority::LOW]);
            createTestIssue(['priority' => IssuePriority::HIGH]);
            createTestIssue(['priority' => IssuePriority::MEDIUM]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/issues?sort_by=priority&sort_order=asc');

            expect($response->status())->toBe(200);
        });

    });

    describe('GET /api/v1/admin/issues/{id}', function () {

        it('returns issue details with relationships', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/issues/{$issue->id}");

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.id'))->toBe($issue->id)
                ->and($response->json('data'))->toHaveKeys([
                    'id', 'title', 'description', 'status', 'priority',
                    'tenant', 'categories', 'timeline', 'created_at',
                ]);
        });

        it('returns 404 for non-existent issue', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/issues/99999');

            expect($response->status())->toBe(404)
                ->and($response->json('success'))->toBeFalse();
        });

    });

    describe('POST /api/v1/admin/issues/{id}/assign', function () {

        it('assigns a service provider to an issue', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::PENDING]);
            $provider = createTestServiceProvider();
            $timeSlot = createTestTimeSlot($provider);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/assign", [
                    'service_provider_id' => $provider->id,
                    'scheduled_date' => now()->toDateString(),
                    'time_slot_id' => $timeSlot->id,
                    'notes' => 'Please check the AC unit',
                ]);

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.assignment.service_provider_id'))->toBe($provider->id);

            $issue->refresh();
            expect($issue->status)->toBe(IssueStatus::ASSIGNED);
        });

        it('validates required fields for assignment', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/assign", []);

            expect($response->status())->toBe(422)
                ->and($response->json('success'))->toBeFalse()
                ->and($response->json('errors'))->toHaveKeys([
                    'service_provider_id',
                    'scheduled_date',
                    'time_slot_id',
                ]);
        });

        it('prevents assigning already assigned issues', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::ASSIGNED]);
            $provider = createTestServiceProvider();
            $timeSlot = createTestTimeSlot($provider);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/assign", [
                    'service_provider_id' => $provider->id,
                    'scheduled_date' => now()->toDateString(),
                    'time_slot_id' => $timeSlot->id,
                ]);

            expect($response->status())->toBe(422)
                ->and($response->json('success'))->toBeFalse();
        });

        it('validates time slot belongs to service provider', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::PENDING]);
            $provider1 = createTestServiceProvider();
            $provider2 = createTestServiceProvider();
            $timeSlot = createTestTimeSlot($provider2);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/assign", [
                    'service_provider_id' => $provider1->id,
                    'scheduled_date' => now()->toDateString(),
                    'time_slot_id' => $timeSlot->id,
                ]);

            expect($response->status())->toBe(422)
                ->and($response->json('success'))->toBeFalse();
        });

        it('denies viewer from assigning issues', function () {
            $viewer = createAdminUser('viewer');
            $token = getAuthToken($viewer);
            $issue = createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/assign", []);

            expect($response->status())->toBe(403);
        });

        it('allows manager to assign issues', function () {
            $manager = createAdminUser('manager');
            $token = getAuthToken($manager);
            $issue = createTestIssue(['status' => IssueStatus::PENDING]);
            $provider = createTestServiceProvider();
            $timeSlot = createTestTimeSlot($provider);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/assign", [
                    'service_provider_id' => $provider->id,
                    'scheduled_date' => now()->toDateString(),
                    'time_slot_id' => $timeSlot->id,
                ]);

            expect($response->status())->toBe(200);
        });

    });

    describe('POST /api/v1/admin/issues/{id}/approve', function () {

        it('approves finished work and marks issue as completed', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::FINISHED]);
            $provider = createTestServiceProvider();

            // Create the assignment
            IssueAssignment::factory()->create([
                'issue_id' => $issue->id,
                'service_provider_id' => $provider->id,
                'status' => AssignmentStatus::FINISHED,
            ]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/approve");

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.status'))->toBe('completed');

            $issue->refresh();
            expect($issue->status)->toBe(IssueStatus::COMPLETED);
        });

        it('prevents approving non-finished issues', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::IN_PROGRESS]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/approve");

            expect($response->status())->toBe(422)
                ->and($response->json('success'))->toBeFalse();
        });

        it('denies viewer from approving issues', function () {
            $viewer = createAdminUser('viewer');
            $token = getAuthToken($viewer);
            $issue = createTestIssue(['status' => IssueStatus::FINISHED]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/approve");

            expect($response->status())->toBe(403);
        });

        it('allows manager to approve issues', function () {
            $manager = createAdminUser('manager');
            $token = getAuthToken($manager);
            $issue = createTestIssue(['status' => IssueStatus::FINISHED]);
            $provider = createTestServiceProvider();

            IssueAssignment::factory()->create([
                'issue_id' => $issue->id,
                'service_provider_id' => $provider->id,
                'status' => AssignmentStatus::FINISHED,
            ]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/approve");

            expect($response->status())->toBe(200);
        });

    });

    describe('POST /api/v1/admin/issues/{id}/cancel', function () {

        it('cancels an issue with reason', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::PENDING]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/cancel", [
                    'reason' => 'Duplicate issue reported by tenant',
                ]);

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.status'))->toBe('cancelled');

            $issue->refresh();
            expect($issue->status)->toBe(IssueStatus::CANCELLED)
                ->and($issue->cancelled_reason)->toBe('Duplicate issue reported by tenant')
                ->and($issue->cancelled_by)->toBe($admin->id);
        });

        it('requires a reason for cancellation', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/cancel", []);

            expect($response->status())->toBe(422)
                ->and($response->json('errors'))->toHaveKey('reason');
        });

        it('requires minimum length for cancellation reason', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/cancel", [
                    'reason' => 'short',
                ]);

            expect($response->status())->toBe(422)
                ->and($response->json('errors'))->toHaveKey('reason');
        });

        it('prevents cancelling already completed issues', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::COMPLETED]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/cancel", [
                    'reason' => 'This issue should be cancelled',
                ]);

            expect($response->status())->toBe(422)
                ->and($response->json('success'))->toBeFalse();
        });

        it('prevents cancelling already cancelled issues', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $issue = createTestIssue(['status' => IssueStatus::CANCELLED]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/cancel", [
                    'reason' => 'This issue should be cancelled again',
                ]);

            expect($response->status())->toBe(422);
        });

        it('denies viewer from cancelling issues', function () {
            $viewer = createAdminUser('viewer');
            $token = getAuthToken($viewer);
            $issue = createTestIssue();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson("/api/v1/admin/issues/{$issue->id}/cancel", [
                    'reason' => 'This issue should be cancelled',
                ]);

            expect($response->status())->toBe(403);
        });

    });

});

/*
|--------------------------------------------------------------------------
| Admin Tenant Management Tests
|--------------------------------------------------------------------------
*/

describe('Admin Tenant Management', function () {

    describe('GET /api/v1/admin/tenants', function () {

        it('lists all tenants with pagination', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestTenant();
            createTestTenant();
            createTestTenant();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/tenants');

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data'))->toHaveCount(3)
                ->and($response->json('meta'))->toHaveKeys(['current_page', 'total']);
        });

        it('searches tenants by name', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestTenant(['name' => 'John Smith']);
            createTestTenant(['name' => 'Jane Doe']);
            createTestTenant(['name' => 'John Doe']);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/tenants?search=John');

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

        it('filters tenants by active status', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestTenant(['is_active' => true]);
            createTestTenant(['is_active' => true]);
            createTestTenant(['is_active' => false]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/tenants?is_active=1');

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

        it('denies viewer access to tenant list', function () {
            $viewer = createAdminUser('viewer');
            $token = getAuthToken($viewer);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/tenants');

            expect($response->status())->toBe(403);
        });

    });

    describe('POST /api/v1/admin/tenants', function () {

        it('creates a new tenant', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/tenants', [
                    'name' => 'New Tenant',
                    'email' => 'newtenant@example.com',
                    'phone' => '+1234567890',
                    'password' => 'securepassword123',
                    'unit_number' => 'A101',
                    'building_name' => 'Tower A',
                    'locale' => 'en',
                ]);

            expect($response->status())->toBe(201)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.unit_number'))->toBe('A101');

            $this->assertDatabaseHas('users', [
                'email' => 'newtenant@example.com',
            ]);

            $this->assertDatabaseHas('tenants', [
                'unit_number' => 'A101',
            ]);
        });

        it('validates required fields', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/tenants', []);

            expect($response->status())->toBe(422);
        });

        it('validates unique email', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestTenant(['email' => 'existing@example.com']);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/tenants', [
                    'name' => 'New Tenant',
                    'email' => 'existing@example.com',
                    'password' => 'password123',
                    'unit_number' => 'A102',
                ]);

            expect($response->status())->toBe(422);
        });

        it('hashes the password when creating', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/tenants', [
                    'name' => 'New Tenant',
                    'email' => 'newtenant@example.com',
                    'password' => 'plainpassword',
                    'unit_number' => 'A101',
                ]);

            expect($response->status())->toBe(201);

            $user = User::where('email', 'newtenant@example.com')->first();
            expect($user->password)->not->toBe('plainpassword')
                ->and(Hash::check('plainpassword', $user->password))->toBeTrue();
        });

        it('validates locale options', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/tenants', [
                    'name' => 'New Tenant',
                    'email' => 'newtenant@example.com',
                    'password' => 'password123',
                    'unit_number' => 'A101',
                    'locale' => 'invalid',
                ]);

            expect($response->status())->toBe(422);
        });

    });

    describe('GET /api/v1/admin/tenants/{id}', function () {

        it('returns tenant details', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $tenant = createTestTenant();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/tenants/{$tenant->id}");

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.id'))->toBe($tenant->id);
        });

        it('returns 404 for non-existent tenant', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/tenants/99999');

            expect($response->status())->toBe(404);
        });

    });

    describe('PUT /api/v1/admin/tenants/{id}', function () {

        it('updates tenant details', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $tenant = createTestTenant();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->putJson("/api/v1/admin/tenants/{$tenant->id}", [
                    'name' => 'Updated Name',
                    'unit_number' => 'B202',
                ]);

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue();

            $tenant->refresh();
            expect($tenant->unit_number)->toBe('B202');
        });

        it('allows partial updates', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $tenant = createTestTenant([], ['unit_number' => 'A101']);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->putJson("/api/v1/admin/tenants/{$tenant->id}", [
                    'building_name' => 'New Building',
                ]);

            expect($response->status())->toBe(200);

            $tenant->refresh();
            expect($tenant->unit_number)->toBe('A101')
                ->and($tenant->building_name)->toBe('New Building');
        });

        it('validates unique email on update', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestTenant(['email' => 'existing@example.com']);
            $tenant = createTestTenant(['email' => 'original@example.com']);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->putJson("/api/v1/admin/tenants/{$tenant->id}", [
                    'email' => 'existing@example.com',
                ]);

            expect($response->status())->toBe(422);
        });

        it('allows same email for same tenant', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $tenant = createTestTenant(['email' => 'same@example.com']);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->putJson("/api/v1/admin/tenants/{$tenant->id}", [
                    'email' => 'same@example.com',
                    'name' => 'Updated Name',
                ]);

            expect($response->status())->toBe(200);
        });

    });

    describe('DELETE /api/v1/admin/tenants/{id}', function () {

        it('deletes a tenant (super_admin only)', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $tenant = createTestTenant();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->deleteJson("/api/v1/admin/tenants/{$tenant->id}");

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue();

            $this->assertDatabaseMissing('tenants', ['id' => $tenant->id]);
        });

        it('denies manager from deleting', function () {
            $manager = createAdminUser('manager');
            $token = getAuthToken($manager);
            $tenant = createTestTenant();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->deleteJson("/api/v1/admin/tenants/{$tenant->id}");

            expect($response->status())->toBe(403);
        });

        it('returns 404 for non-existent tenant', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->deleteJson('/api/v1/admin/tenants/99999');

            expect($response->status())->toBe(404);
        });

    });

});

/*
|--------------------------------------------------------------------------
| Admin Service Provider Management Tests
|--------------------------------------------------------------------------
*/

describe('Admin Service Provider Management', function () {

    describe('GET /api/v1/admin/service-providers', function () {

        it('lists all service providers with pagination', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestServiceProvider();
            createTestServiceProvider();
            createTestServiceProvider();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/service-providers');

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data'))->toHaveCount(3);
        });

        it('filters by category', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $category = Category::factory()->create();
            createTestServiceProvider([], ['category_id' => $category->id]);
            createTestServiceProvider([], ['category_id' => $category->id]);
            createTestServiceProvider();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/service-providers?category_id={$category->id}");

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

        it('searches by name', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestServiceProvider(['name' => 'John Plumber']);
            createTestServiceProvider(['name' => 'Jane Electrician']);
            createTestServiceProvider(['name' => 'John HVAC']);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/service-providers?search=John');

            expect($response->status())->toBe(200)
                ->and($response->json('data'))->toHaveCount(2);
        });

    });

    describe('POST /api/v1/admin/service-providers', function () {

        it('creates a new service provider', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $category = Category::factory()->create();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/service-providers', [
                    'name' => 'New Provider',
                    'email' => 'provider@example.com',
                    'phone' => '+1234567890',
                    'password' => 'securepassword123',
                    'category_id' => $category->id,
                    'company_name' => 'Pro Services LLC',
                ]);

            expect($response->status())->toBe(201)
                ->and($response->json('success'))->toBeTrue();

            $this->assertDatabaseHas('users', [
                'email' => 'provider@example.com',
            ]);

            $this->assertDatabaseHas('service_providers', [
                'category_id' => $category->id,
            ]);
        });

        it('validates required fields', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/service-providers', []);

            expect($response->status())->toBe(422);
        });

        it('validates category exists', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/service-providers', [
                    'name' => 'New Provider',
                    'email' => 'provider@example.com',
                    'password' => 'password123',
                    'category_id' => 99999,
                ]);

            expect($response->status())->toBe(422);
        });

        it('hashes the password when creating', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $category = Category::factory()->create();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->postJson('/api/v1/admin/service-providers', [
                    'name' => 'New Provider',
                    'email' => 'provider@example.com',
                    'password' => 'plainpassword',
                    'category_id' => $category->id,
                ]);

            expect($response->status())->toBe(201);

            $user = User::where('email', 'provider@example.com')->first();
            expect(Hash::check('plainpassword', $user->password))->toBeTrue();
        });

    });

    describe('GET /api/v1/admin/service-providers/{id}', function () {

        it('returns service provider details with time slots', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $provider = createTestServiceProvider();
            createTestTimeSlot($provider, 1);
            createTestTimeSlot($provider, 2);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/service-providers/{$provider->id}");

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.id'))->toBe($provider->id)
                ->and($response->json('data.time_slots'))->toHaveCount(2);
        });

        it('returns 404 for non-existent provider', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/service-providers/99999');

            expect($response->status())->toBe(404);
        });

    });

    describe('PUT /api/v1/admin/service-providers/{id}', function () {

        it('updates service provider details', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $provider = createTestServiceProvider();
            $newCategory = Category::factory()->create();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->putJson("/api/v1/admin/service-providers/{$provider->id}", [
                    'name' => 'Updated Name',
                    'category_id' => $newCategory->id,
                ]);

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue();

            $provider->refresh();
            expect($provider->category_id)->toBe($newCategory->id);
        });

        it('allows partial updates', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $provider = createTestServiceProvider();
            $originalCategoryId = $provider->category_id;

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->putJson("/api/v1/admin/service-providers/{$provider->id}", [
                    'company_name' => 'Updated Company',
                ]);

            expect($response->status())->toBe(200);

            $provider->refresh();
            expect($provider->category_id)->toBe($originalCategoryId);
        });

    });

    describe('DELETE /api/v1/admin/service-providers/{id}', function () {

        it('deletes a service provider (super_admin only)', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $provider = createTestServiceProvider();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->deleteJson("/api/v1/admin/service-providers/{$provider->id}");

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue();

            $this->assertDatabaseMissing('service_providers', ['id' => $provider->id]);
        });

        it('denies manager from deleting', function () {
            $manager = createAdminUser('manager');
            $token = getAuthToken($manager);
            $provider = createTestServiceProvider();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->deleteJson("/api/v1/admin/service-providers/{$provider->id}");

            expect($response->status())->toBe(403);
        });

    });

    describe('GET /api/v1/admin/service-providers/{id}/availability', function () {

        it('returns availability for date range', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $provider = createTestServiceProvider();

            // Create time slots for different days
            createTestTimeSlot($provider, 1); // Monday
            createTestTimeSlot($provider, 2); // Tuesday

            $startDate = now()->startOfWeek()->addDay()->toDateString();
            $endDate = now()->startOfWeek()->addDays(3)->toDateString();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/service-providers/{$provider->id}/availability?start_date={$startDate}&end_date={$endDate}");

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data.availability'))->toBeArray();
        });

        it('validates required date parameters', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $provider = createTestServiceProvider();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/service-providers/{$provider->id}/availability");

            expect($response->status())->toBe(422);
        });

        it('validates date order', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);
            $provider = createTestServiceProvider();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/service-providers/{$provider->id}/availability?start_date=2025-12-31&end_date=2025-12-01");

            expect($response->status())->toBe(422);
        });

        it('returns 404 for non-existent provider', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            $startDate = now()->addDay()->toDateString();
            $endDate = now()->addWeek()->toDateString();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson("/api/v1/admin/service-providers/99999/availability?start_date={$startDate}&end_date={$endDate}");

            expect($response->status())->toBe(404);
        });

    });

});

/*
|--------------------------------------------------------------------------
| Admin Dashboard Tests
|--------------------------------------------------------------------------
*/

describe('Admin Dashboard', function () {

    describe('GET /api/v1/admin/dashboard/stats', function () {

        it('returns dashboard statistics', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            // Create test data
            createTestIssue(['status' => IssueStatus::PENDING]);
            createTestIssue(['status' => IssueStatus::ASSIGNED]);
            createTestIssue(['status' => IssueStatus::IN_PROGRESS]);
            createTestIssue(['status' => IssueStatus::FINISHED]);
            createTestIssue(['status' => IssueStatus::COMPLETED]);

            createTestTenant();
            createTestTenant();
            createTestServiceProvider();

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200)
                ->and($response->json('success'))->toBeTrue()
                ->and($response->json('data'))->toHaveKeys([
                    'issues',
                    'tenants',
                    'service_providers',
                    'recent_issues',
                ]);
        });

        it('returns correct issue counts by status', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestIssue(['status' => IssueStatus::PENDING]);
            createTestIssue(['status' => IssueStatus::PENDING]);
            createTestIssue(['status' => IssueStatus::ASSIGNED]);
            createTestIssue(['status' => IssueStatus::COMPLETED]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200)
                ->and($response->json('data.issues.pending'))->toBe(2)
                ->and($response->json('data.issues.assigned'))->toBe(1)
                ->and($response->json('data.issues.completed'))->toBe(1)
                ->and($response->json('data.issues.total'))->toBe(4);
        });

        it('returns correct tenant counts', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestTenant(['is_active' => true]);
            createTestTenant(['is_active' => true]);
            createTestTenant(['is_active' => false]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200)
                ->and($response->json('data.tenants.total'))->toBe(3)
                ->and($response->json('data.tenants.active'))->toBe(2);
        });

        it('returns correct service provider counts', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestServiceProvider(['is_active' => true]);
            createTestServiceProvider(['is_active' => true]);
            createTestServiceProvider(['is_active' => false]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200)
                ->and($response->json('data.service_providers.total'))->toBe(3)
                ->and($response->json('data.service_providers.active'))->toBe(2);
        });

        it('returns recent issues', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            for ($i = 0; $i < 10; $i++) {
                createTestIssue();
            }

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200)
                ->and($response->json('data.recent_issues'))->toHaveCount(5);
        });

        it('returns issues awaiting approval count', function () {
            $admin = createAdminUser('super_admin');
            $token = getAuthToken($admin);

            createTestIssue(['status' => IssueStatus::FINISHED]);
            createTestIssue(['status' => IssueStatus::FINISHED]);
            createTestIssue(['status' => IssueStatus::PENDING]);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200)
                ->and($response->json('data.issues.awaiting_approval'))->toBe(2);
        });

        it('allows viewer to access dashboard stats', function () {
            $viewer = createAdminUser('viewer');
            $token = getAuthToken($viewer);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200);
        });

        it('allows manager to access dashboard stats', function () {
            $manager = createAdminUser('manager');
            $token = getAuthToken($manager);

            $response = $this->withHeader('Authorization', "Bearer {$token}")
                ->getJson('/api/v1/admin/dashboard/stats');

            expect($response->status())->toBe(200);
        });

    });

});

/*
|--------------------------------------------------------------------------
| Edge Cases and Error Handling Tests
|--------------------------------------------------------------------------
*/

describe('Error Handling', function () {

    it('returns proper error format for validation errors', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/admin/tenants', [
                'email' => 'invalid-email',
            ]);

        expect($response->status())->toBe(422);
    });

    it('handles expired or invalid tokens', function () {
        $response = $this->withHeader('Authorization', 'Bearer invalid.token.here')
            ->getJson('/api/v1/admin/issues');

        expect($response->status())->toBe(401);
    });

});

/*
|--------------------------------------------------------------------------
| Data Integrity Tests
|--------------------------------------------------------------------------
*/

describe('Data Integrity', function () {

    it('maintains data consistency when creating tenant fails', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        // Count users before
        $userCountBefore = User::count();

        // Try to create tenant with invalid data that would pass user creation
        // but fail on tenant creation
        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/admin/tenants', [
                'name' => 'Test User',
                'email' => 'test@example.com',
                'password' => 'password123',
                // Missing required unit_number
            ]);

        expect($response->status())->toBe(422);

        // User count should be the same (transaction rolled back)
        expect(User::count())->toBe($userCountBefore);
    });

    it('maintains data consistency when creating service provider fails', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        $userCountBefore = User::count();

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/admin/service-providers', [
                'name' => 'Test Provider',
                'email' => 'provider@example.com',
                'password' => 'password123',
                // Missing required category_id
            ]);

        expect($response->status())->toBe(422);
        expect(User::count())->toBe($userCountBefore);
    });

});
