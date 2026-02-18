<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;

/*
|--------------------------------------------------------------------------
| Permission Boundary Tests
|--------------------------------------------------------------------------
|
| Systematic verification of EVERY role against EVERY endpoint group.
| Uses a matrix approach: [role] x [endpoint] = expected HTTP status.
|
| Roles tested:
|   - super_admin: full access
|   - manager: manage issues/users/settings, NO delete, NO Shield config
|   - viewer: read-only access
|   - tenant: only /api/v1/issues endpoints
|   - service_provider: only /api/v1/assignments endpoints
|   - unauthenticated: 401 on all protected endpoints
|
*/

beforeEach(function () {
    $this->seed(RolesAndPermissionsSeeder::class);
});

/*
|--------------------------------------------------------------------------
| Helper: seed test fixtures
|--------------------------------------------------------------------------
*/

function seedFixtures(): array
{
    $category = Category::factory()->create();

    $tenantUser = createTenantUser();
    $tenant = $tenantUser->tenant;

    $issue = Issue::factory()
        ->for($tenant)
        ->pending()
        ->create();
    $issue->categories()->attach($category);

    $finishedIssue = Issue::factory()
        ->for($tenant)
        ->create(['status' => IssueStatus::FINISHED]);
    $finishedIssue->categories()->attach($category);

    $spUser = createServiceProviderUser();
    $sp = $spUser->serviceProvider;
    $sp->categories()->attach([$category->id]);

    $timeSlot = TimeSlot::factory()->create([
        'service_provider_id' => $sp->id,
        'day_of_week' => now()->dayOfWeek,
        'start_time' => '09:00:00',
        'end_time' => '17:00:00',
        'is_active' => true,
    ]);

    $assignment = IssueAssignment::create([
        'issue_id' => $issue->id,
        'service_provider_id' => $sp->id,
        'category_id' => $category->id,
        'status' => AssignmentStatus::ASSIGNED,
        'scheduled_date' => now()->addDay()->toDateString(),
        'proof_required' => false,
    ]);

    $finishedAssignment = IssueAssignment::create([
        'issue_id' => $finishedIssue->id,
        'service_provider_id' => $sp->id,
        'category_id' => $category->id,
        'status' => AssignmentStatus::FINISHED,
        'scheduled_date' => now()->toDateString(),
        'proof_required' => false,
    ]);

    return compact(
        'category',
        'tenantUser',
        'tenant',
        'issue',
        'finishedIssue',
        'spUser',
        'sp',
        'timeSlot',
        'assignment',
        'finishedAssignment',
    );
}

/*
|--------------------------------------------------------------------------
| 1. Unauthenticated Access (401 on everything)
|--------------------------------------------------------------------------
*/

describe('Unauthenticated: 401 on all protected endpoints', function () {

    it('returns 401 on admin endpoints', function () {
        $this->getJson('/api/v1/admin/issues')->assertUnauthorized();
        $this->getJson('/api/v1/admin/tenants')->assertUnauthorized();
        $this->getJson('/api/v1/admin/service-providers')->assertUnauthorized();
        $this->getJson('/api/v1/admin/dashboard/stats')->assertUnauthorized();
        $this->postJson('/api/v1/admin/tenants', [])->assertUnauthorized();
    });

    it('returns 401 on tenant endpoints', function () {
        $this->getJson('/api/v1/issues')->assertUnauthorized();
        $this->postJson('/api/v1/issues', [])->assertUnauthorized();
        $this->getJson('/api/v1/issues/1')->assertUnauthorized();
        $this->postJson('/api/v1/issues/1/cancel', [])->assertUnauthorized();
    });

    it('returns 401 on SP assignment endpoints', function () {
        $this->getJson('/api/v1/assignments')->assertUnauthorized();
        $this->getJson('/api/v1/assignments/1')->assertUnauthorized();
        $this->postJson('/api/v1/assignments/1/start')->assertUnauthorized();
        $this->postJson('/api/v1/assignments/1/hold')->assertUnauthorized();
        $this->postJson('/api/v1/assignments/1/resume')->assertUnauthorized();
        $this->postJson('/api/v1/assignments/1/finish')->assertUnauthorized();
    });

    it('returns 401 on auth/me and auth/refresh without token', function () {
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->postJson('/api/v1/auth/refresh')->assertUnauthorized();
    });
});

/*
|--------------------------------------------------------------------------
| 2. Super Admin: Full Access
|--------------------------------------------------------------------------
*/

describe('Super Admin: full access to all endpoints', function () {

    it('can access all admin read endpoints', function () {
        $fixtures = seedFixtures();
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues')
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson("/api/v1/admin/issues/{$fixtures['issue']->id}")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/tenants')
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson("/api/v1/admin/tenants/{$fixtures['tenant']->id}")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/service-providers')
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson("/api/v1/admin/service-providers/{$fixtures['sp']->id}")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk();
    });

    it('can create tenants and service providers', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);
        $category = Category::factory()->create();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/admin/tenants', [
                'name' => 'New Tenant',
                'email' => 'new-tenant-sa@test.com',
                'password' => 'password123',
                'unit_number' => 'SA-001',
            ])
            ->assertStatus(201);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/admin/service-providers', [
                'name' => 'New SP',
                'email' => 'new-sp-sa@test.com',
                'password' => 'password123',
                'category_id' => $category->id,
            ])
            ->assertStatus(201);
    });

    it('can delete tenants and service providers', function () {
        $fixtures = seedFixtures();
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        // Create separate entities to delete (not the fixture ones)
        $tenantToDelete = Tenant::factory()->create();
        $spToDelete = ServiceProvider::factory()->create();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/tenants/{$tenantToDelete->id}")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/service-providers/{$spToDelete->id}")
            ->assertOk();
    });

    it('can assign, approve, and cancel issues', function () {
        $fixtures = seedFixtures();
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        // Approve finished issue
        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/admin/issues/{$fixtures['finishedIssue']->id}/approve")
            ->assertOk();

        // Cancel pending issue
        $pendingIssue = Issue::factory()
            ->for($fixtures['tenant'])
            ->pending()
            ->create();
        $pendingIssue->categories()->attach($fixtures['category']);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/admin/issues/{$pendingIssue->id}/cancel", [
                'reason' => 'Duplicate issue, already resolved.',
            ])
            ->assertOk();
    });

    it('is denied access to tenant-only issue endpoints', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/issues')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/issues', [])
            ->assertForbidden();
    });

    it('is denied access to SP-only assignment endpoints', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/assignments')
            ->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| 3. Manager: Limited Write Access
|--------------------------------------------------------------------------
*/

describe('Manager: manage but no delete, no Shield config', function () {

    it('can access all admin read endpoints', function () {
        seedFixtures();
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues')
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk();
    });

    it('can assign issues', function () {
        $fixtures = seedFixtures();
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);

        $newIssue = Issue::factory()
            ->for($fixtures['tenant'])
            ->pending()
            ->create();
        $newIssue->categories()->attach($fixtures['category']);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/admin/issues/{$newIssue->id}/assign", [
                'service_provider_id' => $fixtures['sp']->id,
                'scheduled_date' => now()->toDateString(),
                'time_slot_id' => $fixtures['timeSlot']->id,
            ])
            ->assertOk();
    });

    it('can approve issues', function () {
        $fixtures = seedFixtures();
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/admin/issues/{$fixtures['finishedIssue']->id}/approve")
            ->assertOk();
    });

    it('CANNOT delete tenants', function () {
        $fixtures = seedFixtures();
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/tenants/{$fixtures['tenant']->id}")
            ->assertForbidden();
    });

    it('CANNOT delete service providers', function () {
        $fixtures = seedFixtures();
        $manager = createAdminUser('manager');
        $token = getAuthToken($manager);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/service-providers/{$fixtures['sp']->id}")
            ->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| 4. Viewer: Read-Only Access
|--------------------------------------------------------------------------
*/

describe('Viewer: read-only on admin, denied write/delete/assign/approve', function () {

    it('can access admin read endpoints (issues, dashboard)', function () {
        seedFixtures();
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues')
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk();
    });

    it('CANNOT access tenant management', function () {
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/tenants')
            ->assertForbidden();
    });

    it('CANNOT create tenants', function () {
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/admin/tenants', [
                'name' => 'Test',
                'email' => 'viewer-test@test.com',
                'password' => 'password123',
                'unit_number' => 'V-001',
            ])
            ->assertForbidden();
    });

    it('CANNOT assign issues', function () {
        $fixtures = seedFixtures();
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/admin/issues/{$fixtures['issue']->id}/assign", [])
            ->assertForbidden();
    });

    it('CANNOT approve issues', function () {
        $fixtures = seedFixtures();
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/admin/issues/{$fixtures['finishedIssue']->id}/approve")
            ->assertForbidden();
    });

    it('CANNOT cancel issues via admin endpoint', function () {
        $fixtures = seedFixtures();
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/admin/issues/{$fixtures['issue']->id}/cancel", [
                'reason' => 'Viewer trying to cancel',
            ])
            ->assertForbidden();
    });

    it('CANNOT delete tenants', function () {
        $fixtures = seedFixtures();
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/tenants/{$fixtures['tenant']->id}")
            ->assertForbidden();
    });

    it('CANNOT delete service providers', function () {
        $fixtures = seedFixtures();
        $viewer = createAdminUser('viewer');
        $token = getAuthToken($viewer);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/admin/service-providers/{$fixtures['sp']->id}")
            ->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| 5. Tenant: Only Issue Endpoints
|--------------------------------------------------------------------------
*/

describe('Tenant: only /api/v1/issues endpoints', function () {

    it('can access own issues', function () {
        $tenantUser = createTenantUser();
        $token = getAuthToken($tenantUser);
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($category);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/issues')
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson("/api/v1/issues/{$issue->id}")
            ->assertOk();
    });

    it('can create issues', function () {
        $tenantUser = createTenantUser();
        $token = getAuthToken($tenantUser);
        $category = Category::factory()->create();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/issues', [
                'title' => 'Tenant Issue',
                'description' => 'Description here',
                'category_ids' => [$category->id],
            ])
            ->assertStatus(201);
    });

    it('can cancel own pending issues', function () {
        $tenantUser = createTenantUser();
        $token = getAuthToken($tenantUser);
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/issues/{$issue->id}/cancel")
            ->assertOk();
    });

    it('CANNOT access admin endpoints', function () {
        $tenantUser = createTenantUser();
        $token = getAuthToken($tenantUser);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/tenants')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/service-providers')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/dashboard/stats')
            ->assertForbidden();
    });

    it('CANNOT access assignment endpoints', function () {
        $tenantUser = createTenantUser();
        $token = getAuthToken($tenantUser);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/assignments')
            ->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| 6. Service Provider: Only Assignment Endpoints
|--------------------------------------------------------------------------
*/

describe('Service Provider: only /api/v1/assignments endpoints', function () {

    it('can access own assignments', function () {
        $fixtures = seedFixtures();
        $token = getAuthToken($fixtures['spUser']);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/assignments')
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson("/api/v1/assignments/{$fixtures['assignment']->id}")
            ->assertOk();
    });

    it('can perform assignment workflow actions', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create(['status' => IssueStatus::ASSIGNED]);

        $assignment = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUser->serviceProvider->id,
            'category_id' => $spUser->serviceProvider->category_id,
            'status' => AssignmentStatus::ASSIGNED,
            'scheduled_date' => now()->addDay()->toDateString(),
            'proof_required' => false,
        ]);

        $token = getAuthToken($spUser);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/assignments/{$assignment->id}/start")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/assignments/{$assignment->id}/hold")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/assignments/{$assignment->id}/resume")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/v1/assignments/{$assignment->id}/finish")
            ->assertOk();
    });

    it('CANNOT access admin endpoints', function () {
        $spUser = createServiceProviderUser();
        $token = getAuthToken($spUser);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/tenants')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/dashboard/stats')
            ->assertForbidden();
    });

    it('CANNOT access tenant issue endpoints', function () {
        $spUser = createServiceProviderUser();
        $token = getAuthToken($spUser);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/issues')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/issues', [
                'title' => 'SP trying to create issue',
                'description' => 'Should be denied',
                'category_ids' => [1],
            ])
            ->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| 7. Non-role User (no role assigned)
|--------------------------------------------------------------------------
*/

describe('User with no role assigned', function () {

    it('is denied access to all protected endpoints', function () {
        ensureRolesExist();

        $user = User::factory()->create(['is_active' => true]);
        $token = getAuthToken($user);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/issues')
            ->assertForbidden();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/assignments')
            ->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| 8. Inactive User
|--------------------------------------------------------------------------
*/

describe('Inactive user account', function () {

    it('cannot login', function () {
        $user = createUser(['is_active' => false]);

        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ])->assertUnprocessable();
    });
});
