<?php

declare(strict_types=1);

use App\Models\Category;
use App\Models\Consumable;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use App\Models\User;
use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

/*
|--------------------------------------------------------------------------
| Admin CRUD Coverage Gap Tests
|--------------------------------------------------------------------------
|
| Tests for admin API endpoints that are NOT covered by AdminTest.php:
|   - Category CRUD (create, show, update, delete, move, restore, tree)
|   - Consumable CRUD (create, update, delete)
|   - Admin User Management (list, create, show, update, delete, etc.)
|   - Calendar events
|   - Admin issue creation
|   - Assignment update (reschedule)
|
*/

beforeEach(function () {
    $this->seed(RolesAndPermissionsSeeder::class);
    Storage::fake('public');
});

/*
|--------------------------------------------------------------------------
| Admin Category Management
|--------------------------------------------------------------------------
*/

describe('Admin Category CRUD', function () {

    it('lists categories with pagination', function () {
        $admin = createAdminUser('super_admin');
        Category::factory()->count(3)->create();

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/admin/categories');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'name_en', 'name_ar', 'is_active'],
                ],
            ]);
    });

    it('returns category tree structure', function () {
        $admin = createAdminUser('super_admin');
        $root = Category::create([
            'name_en' => 'Root',
            'name_ar' => 'جذر',
            'is_active' => true,
        ]);
        Category::create([
            'parent_id' => $root->id,
            'name_en' => 'Child',
            'name_ar' => 'طفل',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/admin/categories/tree');

        $response->assertOk();
    });

    it('creates a category with valid data', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/categories', [
                'name_en' => 'Electrical',
                'name_ar' => 'كهربائي',
                'is_active' => true,
            ]);

        $response->assertCreated();

        $this->assertDatabaseHas('categories', [
            'name_en' => 'Electrical',
            'name_ar' => 'كهربائي',
            'is_active' => true,
        ]);
    });

    it('creates a child category with parent_id', function () {
        $admin = createAdminUser('super_admin');
        $parent = Category::create([
            'name_en' => 'Parent',
            'name_ar' => 'أب',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/categories', [
                'name_en' => 'Child',
                'name_ar' => 'طفل',
                'parent_id' => $parent->id,
                'is_active' => true,
            ]);

        $response->assertCreated();

        $child = Category::where('name_en', 'Child')->first();
        expect($child->parent_id)->toBe($parent->id)
            ->and($child->depth)->toBe(1);
    });

    it('rejects category creation without required fields', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/categories', []);

        $response->assertUnprocessable();
    });

    it('shows a single category', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::create([
            'name_en' => 'Test Cat',
            'name_ar' => 'فئة اختبار',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$category->id}");

        $response->assertOk()
            ->assertJsonPath('data.id', $category->id);
    });

    it('returns children of a category', function () {
        $admin = createAdminUser('super_admin');
        $parent = Category::create([
            'name_en' => 'Parent',
            'name_ar' => 'أب',
            'is_active' => true,
        ]);
        Category::create([
            'parent_id' => $parent->id,
            'name_en' => 'Child 1',
            'name_ar' => 'طفل 1',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$parent->id}/children");

        $response->assertOk();
    });

    it('updates a category', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::create([
            'name_en' => 'Old Name',
            'name_ar' => 'اسم قديم',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->putJson("/api/v1/admin/categories/{$category->id}", [
                'name_en' => 'Updated Name',
                'name_ar' => 'اسم محدث',
            ]);

        $response->assertOk();

        expect($category->fresh()->name_en)->toBe('Updated Name');
    });

    it('deletes a category (super_admin only)', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::create([
            'name_en' => 'Delete Me',
            'name_ar' => 'احذفني',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->deleteJson("/api/v1/admin/categories/{$category->id}");

        $response->assertOk();

        // Should be soft deleted
        expect(Category::find($category->id))->toBeNull()
            ->and(Category::withTrashed()->find($category->id))->not->toBeNull();
    });

    it('manager cannot delete a category', function () {
        $manager = createAdminUser('manager');
        $category = Category::create([
            'name_en' => 'Protected',
            'name_ar' => 'محمي',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($manager))
            ->deleteJson("/api/v1/admin/categories/{$category->id}");

        $response->assertForbidden();
    });

    it('moves a category to a new parent', function () {
        $admin = createAdminUser('super_admin');
        $root1 = Category::create(['name_en' => 'Root1', 'name_ar' => 'جذر1', 'is_active' => true]);
        $root2 = Category::create(['name_en' => 'Root2', 'name_ar' => 'جذر2', 'is_active' => true]);
        $child = Category::create([
            'parent_id' => $root1->id,
            'name_en' => 'Movable',
            'name_ar' => 'متحرك',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/categories/{$child->id}/move", [
                'parent_id' => $root2->id,
            ]);

        $response->assertOk();

        expect($child->fresh()->parent_id)->toBe($root2->id);
    });

    it('restores a soft-deleted category', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::create([
            'name_en' => 'Restorable',
            'name_ar' => 'قابل للاستعادة',
            'is_active' => true,
        ]);

        $category->delete(); // soft delete
        expect(Category::find($category->id))->toBeNull();

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/categories/{$category->id}/restore");

        $response->assertOk();

        expect(Category::find($category->id))->not->toBeNull();
    });
});

/*
|--------------------------------------------------------------------------
| Admin Consumable Management
|--------------------------------------------------------------------------
*/

describe('Admin Consumable CRUD', function () {

    it('lists consumables', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::factory()->create();
        Consumable::factory()->count(3)->create(['category_id' => $category->id]);

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/admin/consumables');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'name_en', 'name_ar'],
                ],
            ]);
    });

    it('creates a consumable with valid data', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/consumables', [
                'name_en' => 'Pipe Wrench',
                'name_ar' => 'مفتاح ربط الأنابيب',
                'category_id' => $category->id,
                'is_active' => true,
            ]);

        $response->assertCreated();

        $this->assertDatabaseHas('consumables', [
            'name_en' => 'Pipe Wrench',
            'category_id' => $category->id,
        ]);
    });

    it('rejects consumable creation without required fields', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/consumables', []);

        $response->assertUnprocessable();
    });

    it('updates a consumable', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::factory()->create();
        $consumable = Consumable::factory()->create([
            'category_id' => $category->id,
            'name_en' => 'Old Consumable',
        ]);

        $response = $this->withHeaders(authHeaders($admin))
            ->putJson("/api/v1/admin/consumables/{$consumable->id}", [
                'name_en' => 'Updated Consumable',
                'name_ar' => 'مستهلك محدث',
            ]);

        $response->assertOk();

        expect($consumable->fresh()->name_en)->toBe('Updated Consumable');
    });

    it('deletes a consumable (super_admin only)', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::factory()->create();
        $consumable = Consumable::factory()->create(['category_id' => $category->id]);

        $response = $this->withHeaders(authHeaders($admin))
            ->deleteJson("/api/v1/admin/consumables/{$consumable->id}");

        $response->assertOk();
    });

    it('manager cannot delete a consumable', function () {
        $manager = createAdminUser('manager');
        $category = Category::factory()->create();
        $consumable = Consumable::factory()->create(['category_id' => $category->id]);

        $response = $this->withHeaders(authHeaders($manager))
            ->deleteJson("/api/v1/admin/consumables/{$consumable->id}");

        $response->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| Admin User Management (super_admin only)
|--------------------------------------------------------------------------
*/

describe('Admin User Management', function () {

    it('lists admin users (super_admin only)', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/admin/users');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'name', 'email'],
                ],
            ]);
    });

    it('manager cannot access admin user management', function () {
        $manager = createAdminUser('manager');

        $response = $this->withHeaders(authHeaders($manager))
            ->getJson('/api/v1/admin/users');

        $response->assertForbidden();
    });

    it('viewer cannot access admin user management', function () {
        $viewer = createAdminUser('viewer');

        $response = $this->withHeaders(authHeaders($viewer))
            ->getJson('/api/v1/admin/users');

        $response->assertForbidden();
    });

    it('creates an admin user', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/users', [
                'name' => 'New Manager',
                'email' => 'newmanager@test.com',
                'password' => 'SecurePass123!',
                'password_confirmation' => 'SecurePass123!',
                'role' => 'manager',
            ]);

        $response->assertCreated();

        $this->assertDatabaseHas('users', [
            'email' => 'newmanager@test.com',
        ]);
    });

    it('rejects duplicate email', function () {
        $admin = createAdminUser('super_admin');
        $existing = createUser(['email' => 'taken@test.com']);

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/users', [
                'name' => 'Duplicate',
                'email' => 'taken@test.com',
                'password' => 'SecurePass123!',
                'password_confirmation' => 'SecurePass123!',
                'role' => 'manager',
            ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    });

    it('shows a specific admin user', function () {
        $admin = createAdminUser('super_admin');
        $targetUser = createAdminUser('manager');

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/users/{$targetUser->id}");

        $response->assertOk()
            ->assertJsonPath('data.id', $targetUser->id);
    });

    it('updates an admin user', function () {
        $admin = createAdminUser('super_admin');
        $targetUser = createAdminUser('manager');

        $response = $this->withHeaders(authHeaders($admin))
            ->putJson("/api/v1/admin/users/{$targetUser->id}", [
                'name' => 'Updated Manager Name',
            ]);

        $response->assertOk();

        expect($targetUser->fresh()->name)->toBe('Updated Manager Name');
    });

    it('deletes an admin user', function () {
        $admin = createAdminUser('super_admin');
        $targetUser = createAdminUser('viewer');

        $response = $this->withHeaders(authHeaders($admin))
            ->deleteJson("/api/v1/admin/users/{$targetUser->id}");

        $response->assertOk();
    });

    it('resets password for an admin user', function () {
        $admin = createAdminUser('super_admin');
        $targetUser = createAdminUser('manager');

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/users/{$targetUser->id}/reset-password", [
                'password' => 'NewPassword123!',
                'password_confirmation' => 'NewPassword123!',
            ]);

        $response->assertOk();
    });

    it('toggles active status for an admin user', function () {
        $admin = createAdminUser('super_admin');
        $targetUser = createAdminUser('manager');

        $originalActive = $targetUser->is_active;

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/users/{$targetUser->id}/toggle-active");

        $response->assertOk();

        expect($targetUser->fresh()->is_active)->not->toBe($originalActive);
    });
});

/*
|--------------------------------------------------------------------------
| Admin Issue Creation
|--------------------------------------------------------------------------
*/

describe('Admin Issue Creation', function () {

    it('admin can create an issue on behalf of a tenant', function () {
        $admin = createAdminUser('super_admin');
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/issues', [
                'title' => 'Admin-created Issue',
                'description' => 'Created by admin on behalf of tenant',
                'category_ids' => [$category->id],
                'tenant_id' => $tenantUser->tenant->id,
                'priority' => 'high',
            ]);

        $response->assertCreated();

        $issueId = $response->json('data.id');
        $issue = Issue::find($issueId);

        expect($issue)->not->toBeNull()
            ->and($issue->tenant_id)->toBe($tenantUser->tenant->id)
            ->and($issue->title)->toBe('Admin-created Issue');
    });

    it('rejects admin issue creation without tenant_id', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/admin/issues', [
                'title' => 'Missing Tenant',
                'description' => 'No tenant specified',
                'category_ids' => [$category->id],
            ]);

        $response->assertUnprocessable();
    });
});

/*
|--------------------------------------------------------------------------
| Admin Assignment Update (Reschedule)
|--------------------------------------------------------------------------
*/

describe('Admin Assignment Update', function () {

    it('admin can update/reschedule an assignment', function () {
        $admin = createAdminUser('super_admin');
        $tenantUser = createTenantUser();
        $spUser = createServiceProviderUser();
        $category = Category::factory()->create();
        $spUser->serviceProvider->categories()->attach([$category->id]);

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create(['status' => IssueStatus::ASSIGNED]);
        $issue->categories()->attach($category);

        $assignment = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUser->serviceProvider->id,
            'category_id' => $category->id,
            'status' => AssignmentStatus::ASSIGNED,
            'scheduled_date' => now()->addDay()->toDateString(),
            'proof_required' => false,
        ]);

        $newDate = now()->addDays(3)->toDateString();

        $response = $this->withHeaders(authHeaders($admin))
            ->putJson("/api/v1/admin/issues/{$issue->id}/assignments/{$assignment->id}", [
                'scheduled_date' => $newDate,
                'notes' => 'Rescheduled to later date',
            ]);

        $response->assertOk();
    });

    it('viewer cannot update an assignment', function () {
        $viewer = createAdminUser('viewer');
        $tenantUser = createTenantUser();
        $spUser = createServiceProviderUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create(['status' => IssueStatus::ASSIGNED]);

        $assignment = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUser->serviceProvider->id,
            'category_id' => $category->id,
            'status' => AssignmentStatus::ASSIGNED,
            'scheduled_date' => now()->addDay()->toDateString(),
            'proof_required' => false,
        ]);

        $response = $this->withHeaders(authHeaders($viewer))
            ->putJson("/api/v1/admin/issues/{$issue->id}/assignments/{$assignment->id}", [
                'scheduled_date' => now()->addDays(5)->toDateString(),
            ]);

        $response->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| Admin Calendar Events
|--------------------------------------------------------------------------
*/

describe('Admin Calendar Events', function () {

    it('returns calendar events', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/admin/calendar/events');

        $response->assertOk();
    });

    it('filters calendar events by date range', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/admin/calendar/events?' . http_build_query([
                'start_date' => now()->startOfMonth()->toDateString(),
                'end_date' => now()->endOfMonth()->toDateString(),
            ]));

        $response->assertOk();
    });

    it('non-admin cannot access calendar', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/admin/calendar/events');

        $response->assertForbidden();
    });
});

/*
|--------------------------------------------------------------------------
| Master Data Routes (accessible by all authenticated users)
|--------------------------------------------------------------------------
*/

describe('Master Data Routes', function () {

    it('lists categories for any authenticated user', function () {
        $tenantUser = createTenantUser();
        Category::factory()->count(2)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/categories');

        $response->assertOk();
    });

    it('returns category tree for any authenticated user', function () {
        $spUser = createServiceProviderUser();

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/categories/tree');

        $response->assertOk();
    });

    it('returns children of a category', function () {
        $tenantUser = createTenantUser();
        $parent = Category::create([
            'name_en' => 'Parent',
            'name_ar' => 'أب',
            'is_active' => true,
        ]);
        Category::create([
            'parent_id' => $parent->id,
            'name_en' => 'Child',
            'name_ar' => 'طفل',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/categories/{$parent->id}/children");

        $response->assertOk();
    });

    it('lists consumables for any authenticated user', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();
        Consumable::factory()->count(2)->create(['category_id' => $category->id]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/consumables');

        $response->assertOk();
    });

    it('unauthenticated user cannot access master data', function () {
        $response = $this->getJson('/api/v1/categories');
        $response->assertUnauthorized();
    });
});

/*
|--------------------------------------------------------------------------
| Sync Routes
|--------------------------------------------------------------------------
*/

describe('Sync Routes', function () {

    it('returns master data for sync', function () {
        $tenantUser = createTenantUser();
        Category::factory()->count(2)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/sync/master-data');

        $response->assertOk();
    });

    it('unauthenticated user cannot access sync', function () {
        $response = $this->getJson('/api/v1/sync/master-data');
        $response->assertUnauthorized();
    });
});

/*
|--------------------------------------------------------------------------
| Profile Routes
|--------------------------------------------------------------------------
*/

describe('Profile Routes', function () {

    it('shows current user profile', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/profile');

        $response->assertOk()
            ->assertJsonPath('data.id', $tenantUser->id);
    });

    it('updates profile name', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->putJson('/api/v1/profile', [
                'name' => 'Updated Name',
            ]);

        $response->assertOk();

        expect($tenantUser->fresh()->name)->toBe('Updated Name');
    });

    it('updates locale', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->putJson('/api/v1/profile/locale', [
                'locale' => 'ar',
            ]);

        $response->assertOk();

        expect($tenantUser->fresh()->locale)->toBe('ar');
    });
});

/*
|--------------------------------------------------------------------------
| Dashboard (coverage for edge cases)
|--------------------------------------------------------------------------
*/

describe('Dashboard edge cases', function () {

    it('returns stats when no data exists', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/admin/dashboard/stats');

        $response->assertOk()
            ->assertJsonStructure(['data']);
    });

    it('viewer can access dashboard stats (read-only)', function () {
        $viewer = createAdminUser('viewer');

        $response = $this->withHeaders(authHeaders($viewer))
            ->getJson('/api/v1/admin/dashboard/stats');

        $response->assertOk();
    });

    it('tenant cannot access dashboard', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/admin/dashboard/stats');

        $response->assertForbidden();
    });
});
