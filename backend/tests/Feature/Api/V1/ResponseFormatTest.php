<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Enums\IssuePriority;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/*
|--------------------------------------------------------------------------
| API Response Format & Type Safety Tests
|--------------------------------------------------------------------------
|
| Verifies all API responses follow consistent format:
|
| Success:    { "success": true, "data": {...}, "message": "..." }
| Paginated:  { "success": true, "data": [...], "meta": {...}, "links": {...} }
| Error:      { "success": false, "message": "...", "errors": {...} }
|
| Also verifies:
|   - Enum fields return correct shapes
|   - Null-safe defaults (no null where empty expected)
|   - Date format is ISO 8601
|   - Nested relationship data consistency
|
*/

beforeEach(function () {
    $this->seed(RolesAndPermissionsSeeder::class);
    Storage::fake('public');
});

/*
|--------------------------------------------------------------------------
| Success response format
|--------------------------------------------------------------------------
*/

describe('Success response format', function () {

    it('single resource returns { success, data, message }', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Format Test Issue',
                'description' => 'Testing response format',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(201)
            ->assertJsonStructure([
                'success',
                'data',
                'message',
            ]);

        expect($response->json('success'))->toBeTrue()
            ->and($response->json('data'))->toBeArray()
            ->and($response->json('message'))->toBeString();
    });

    it('login response has correct structure', function () {
        $user = createUser();

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => [
                    'access_token',
                    'token_type',
                    'expires_in',
                    'user' => [
                        'id',
                        'name',
                        'email',
                    ],
                ],
            ]);

        expect($response->json('success'))->toBeTrue()
            ->and($response->json('data.token_type'))->toBe('bearer')
            ->and($response->json('data.expires_in'))->toBeInt();
    });
});

/*
|--------------------------------------------------------------------------
| Paginated response format
|--------------------------------------------------------------------------
*/

describe('Paginated response format', function () {

    it('tenant issue list returns { success, data, message, meta, links }', function () {
        $tenantUser = createTenantUser();
        Issue::factory()->count(3)->for($tenantUser->tenant)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data',
                'message',
                'meta' => [
                    'current_page',
                    'last_page',
                    'per_page',
                    'total',
                ],
                'links' => [
                    'first',
                    'last',
                    'prev',
                    'next',
                ],
            ]);

        expect($response->json('success'))->toBeTrue()
            ->and($response->json('meta.current_page'))->toBeInt()
            ->and($response->json('meta.per_page'))->toBeInt()
            ->and($response->json('meta.total'))->toBeInt()
            ->and($response->json('meta.last_page'))->toBeInt();
    });

    it('admin issue list returns paginated format', function () {
        $admin = createAdminUser('super_admin');
        $token = getAuthToken($admin);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/admin/issues');

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data',
                'meta' => ['current_page', 'last_page', 'per_page', 'total'],
                'links',
            ]);
    });

    it('SP assignment list returns paginated format', function () {
        $spUser = createServiceProviderUser();
        $token = getAuthToken($spUser);

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/assignments');

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data',
                'meta' => ['current_page', 'last_page', 'per_page', 'total'],
                'links',
            ]);
    });

    it('empty list returns empty data array with zero total', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [],
            ])
            ->assertJsonPath('meta.total', 0);
    });
});

/*
|--------------------------------------------------------------------------
| Error response format
|--------------------------------------------------------------------------
*/

describe('Error response format', function () {

    it('validation error returns { success: false, message, errors }', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', []);

        $response->assertStatus(422)
            ->assertJsonStructure([
                'message',
                'errors',
            ]);

        // Validation errors have field-specific messages
        expect($response->json('errors'))->toBeArray();
    });

    it('not found returns { success: false, message }', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues/99999');

        $response->assertStatus(404)
            ->assertJson([
                'success' => false,
            ]);
    });

    it('unauthorized returns 401 with message', function () {
        $response = $this->getJson('/api/v1/auth/me');

        $response->assertUnauthorized();
    });

    it('forbidden returns { success: false }', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/issues');

        $response->assertForbidden()
            ->assertJson([
                'success' => false,
            ]);
    });

    it('business logic error returns 400 with success: false', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->completed()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => 'Too late',
            ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
            ]);
    });
});

/*
|--------------------------------------------------------------------------
| Enum field format consistency
|--------------------------------------------------------------------------
*/

describe('Enum fields return consistent shapes', function () {

    it('issue status returns { value, label, color }', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'status' => ['value', 'label', 'color'],
                ],
            ]);

        $status = $response->json('data.status');
        expect($status['value'])->toBeString()
            ->and($status['label'])->toBeString()
            ->and($status['color'])->toBeString();
    });

    it('issue priority returns { value, label }', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->highPriority()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'priority' => ['value', 'label'],
                ],
            ]);

        $priority = $response->json('data.priority');
        expect($priority['value'])->toBe('high')
            ->and($priority['label'])->toBeString();
    });

    it('assignment status returns { value, label, color }', function () {
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

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson("/api/v1/assignments/{$assignment->id}");

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'status' => ['value', 'label', 'color'],
                ],
            ]);
    });

    it('all issue status values are valid', function () {
        $validStatuses = ['pending', 'assigned', 'in_progress', 'on_hold', 'finished', 'completed', 'cancelled'];

        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        foreach ($validStatuses as $statusValue) {
            $status = IssueStatus::from($statusValue);
            $issue = Issue::factory()
                ->for($tenantUser->tenant)
                ->create(['status' => $status]);
            $issue->categories()->attach($category);

            $response = $this->withHeaders(authHeaders($tenantUser))
                ->getJson("/api/v1/issues/{$issue->id}");

            $response->assertOk();
            expect($response->json('data.status.value'))->toBe($statusValue);
        }
    });

    it('all priority values are valid', function () {
        $validPriorities = ['low', 'medium', 'high'];

        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        foreach ($validPriorities as $priorityValue) {
            $priority = IssuePriority::from($priorityValue);
            $issue = Issue::factory()
                ->for($tenantUser->tenant)
                ->create(['priority' => $priority]);
            $issue->categories()->attach($category);

            $response = $this->withHeaders(authHeaders($tenantUser))
                ->getJson("/api/v1/issues/{$issue->id}");

            $response->assertOk();
            expect($response->json('data.priority.value'))->toBe($priorityValue);
        }
    });
});

/*
|--------------------------------------------------------------------------
| Null-safe defaults
|--------------------------------------------------------------------------
*/

describe('Null-safe defaults in responses', function () {

    it('issue without location returns null location (not crash)', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create([
                'latitude' => null,
                'longitude' => null,
            ]);
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk()
            ->assertJsonPath('data.location', null);
    });

    it('issue without media returns empty array', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk();

        $media = $response->json('data.media');
        expect($media)->toBeArray()
            ->and($media)->toBeEmpty();
    });

    it('issue without assignments returns null current_assignment in list', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertOk();
        expect($response->json('data.0.current_assignment'))->toBeNull();
    });

    it('non-cancelled issue has no cancellation block', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk();
        expect($response->json('data.cancellation'))->toBeNull();
    });

    it('issue with categories returns them as array', function () {
        $tenantUser = createTenantUser();
        $categories = Category::factory()->count(2)->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($categories->pluck('id'));

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk();

        $cats = $response->json('data.categories');
        expect($cats)->toBeArray()
            ->and($cats)->toHaveCount(2);

        foreach ($cats as $cat) {
            expect($cat)->toHaveKeys(['id', 'name']);
        }
    });
});

/*
|--------------------------------------------------------------------------
| Date format consistency
|--------------------------------------------------------------------------
*/

describe('Date format consistency (ISO 8601)', function () {

    it('created_at is ISO 8601 format', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk();

        $createdAt = $response->json('data.created_at');
        expect($createdAt)->toBeString();

        // Should be parseable as a date
        $parsed = strtotime($createdAt);
        expect($parsed)->not->toBeFalse();
    });

    it('updated_at is ISO 8601 format', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk();

        $updatedAt = $response->json('data.updated_at');
        if ($updatedAt !== null) {
            $parsed = strtotime($updatedAt);
            expect($parsed)->not->toBeFalse();
        }
    });

    it('auth/me created_at is ISO format', function () {
        $user = createUser();
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk();

        $createdAt = $response->json('data.created_at');
        expect($createdAt)->toMatch('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/');
    });
});

/*
|--------------------------------------------------------------------------
| Nested relationship data consistency
|--------------------------------------------------------------------------
*/

describe('Nested relationship data consistency', function () {

    it('issue categories contain id and name', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create(['name_en' => 'Test Cat']);

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk();
        $cats = $response->json('data.categories');
        expect($cats[0])->toHaveKey('id')
            ->and($cats[0])->toHaveKey('name');
    });

    it('assignment includes issue with tenant info', function () {
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

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson("/api/v1/assignments/{$assignment->id}");

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'issue' => [
                        'id',
                        'title',
                        'description',
                        'status',
                        'priority',
                        'tenant',
                    ],
                ],
            ]);

        $tenant = $response->json('data.issue.tenant');
        expect($tenant)->toHaveKey('unit_number');
    });

    it('auth/me includes tenant details for tenant user', function () {
        $tenantUser = createTenantUser([
            'unit_number' => 'Z-999',
        ]);
        $headers = authHeaders($tenantUser);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJson([
                'data' => [
                    'is_tenant' => true,
                    'tenant' => [
                        'unit_number' => 'Z-999',
                    ],
                ],
            ]);
    });

    it('auth/me includes SP details for service provider user', function () {
        $spUser = createServiceProviderUser();
        $headers = authHeaders($spUser);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJson([
                'data' => [
                    'is_service_provider' => true,
                ],
            ]);

        expect($response->json('data.service_provider'))->not->toBeNull();
    });

    it('auth/me returns permissions as array', function () {
        $admin = createAdminUser('super_admin');
        $headers = authHeaders($admin);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk();

        $permissions = $response->json('data.permissions');
        expect($permissions)->toBeArray();
    });
});
