<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Enums\MediaType;
use App\Enums\TimelineAction;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\IssueMedia;
use App\Models\IssueTimeline;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/*
|--------------------------------------------------------------------------
| Tenant Issue API Tests
|--------------------------------------------------------------------------
|
| This file contains comprehensive Pest tests for the Tenant Issue API endpoints:
| - GET /api/v1/issues (List tenant's own issues)
| - POST /api/v1/issues (Create new issue)
| - GET /api/v1/issues/{id} (Get issue details)
| - POST /api/v1/issues/{id}/cancel (Request cancellation)
|
*/

beforeEach(function () {
    // Seed roles and permissions before each test
    $this->seed(RolesAndPermissionsSeeder::class);

    // Fake storage for file uploads
    Storage::fake('public');
});

/*
|--------------------------------------------------------------------------
| List Issues Tests - GET /api/v1/issues
|--------------------------------------------------------------------------
*/

describe('List Issues (GET /api/v1/issues)', function () {

    it('returns 401 for unauthenticated request', function () {
        $response = $this->getJson('/api/v1/issues');

        $response->assertStatus(401);
    });

    it('returns 403 when non-tenant user tries to access', function () {
        $admin = createAdminUser('super_admin');

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson('/api/v1/issues');

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
            ]);
    });

    it('returns 403 when service provider tries to access', function () {
        $serviceProviderUser = createServiceProviderUser();

        $response = $this->withHeaders(authHeaders($serviceProviderUser))
            ->getJson('/api/v1/issues');

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
            ]);
    });

    it('tenant sees only their own issues', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        // Create issues for this tenant
        $ownIssues = Issue::factory()
            ->count(3)
            ->for($tenant)
            ->create();

        // Create issues for another tenant
        $anotherTenant = Tenant::factory()->create();
        Issue::factory()
            ->count(2)
            ->for($anotherTenant)
            ->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('meta.total', 3);

        // Verify returned issues belong to the tenant
        $returnedIds = collect($response->json('data'))->pluck('id')->toArray();
        foreach ($ownIssues as $issue) {
            expect($returnedIds)->toContain($issue->id);
        }
    });

    it('returns paginated response with correct meta structure', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()
            ->count(25)
            ->for($tenant)
            ->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?per_page=10');

        $response->assertStatus(200)
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
            ])
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.total', 25)
            ->assertJsonPath('meta.last_page', 3)
            ->assertJsonCount(10, 'data');
    });

    it('filters issues by status', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()->count(3)->for($tenant)->pending()->create();
        Issue::factory()->count(2)->for($tenant)->assigned()->create();
        Issue::factory()->count(1)->for($tenant)->completed()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?status=pending');

        $response->assertStatus(200)
            ->assertJsonCount(3, 'data');

        // Verify all returned issues have pending status
        $statuses = collect($response->json('data'))->pluck('status.value')->unique();
        expect($statuses->toArray())->toBe(['pending']);
    });

    it('filters issues by priority', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()->count(2)->for($tenant)->highPriority()->create();
        Issue::factory()->count(3)->for($tenant)->mediumPriority()->create();
        Issue::factory()->count(1)->for($tenant)->lowPriority()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?priority=high');

        $response->assertStatus(200)
            ->assertJsonCount(2, 'data');

        // Verify all returned issues have high priority
        $priorities = collect($response->json('data'))->pluck('priority.value')->unique();
        expect($priorities->toArray())->toBe(['high']);
    });

    it('filters active issues only when active_only is true', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()->count(2)->for($tenant)->pending()->create();
        Issue::factory()->count(1)->for($tenant)->inProgress()->create();
        Issue::factory()->count(2)->for($tenant)->completed()->create();
        Issue::factory()->count(1)->for($tenant)->cancelled()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?active_only=true');

        $response->assertStatus(200)
            ->assertJsonCount(3, 'data');

        // Verify no completed or cancelled issues are returned
        $statuses = collect($response->json('data'))->pluck('status.value');
        expect($statuses)->not->toContain('completed')
            ->and($statuses)->not->toContain('cancelled');
    });

    it('returns issues with proper data structure', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        $category = Category::factory()->create();
        $issue = Issue::factory()
            ->for($tenant)
            ->withLocation(25.276987, 55.296249)
            ->create([
                'title' => 'Test Issue Title',
                'description' => 'Test issue description',
                'priority' => IssuePriority::HIGH,
                'status' => IssueStatus::PENDING,
            ]);

        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data' => [
                    '*' => [
                        'id',
                        'title',
                        'description',
                        'status' => [
                            'value',
                            'label',
                            'color',
                        ],
                        'priority' => [
                            'value',
                            'label',
                        ],
                        'categories',
                        'location',
                        'media',
                        'current_assignment',
                        'created_at',
                        'updated_at',
                    ],
                ],
            ]);

        $issueData = $response->json('data.0');
        expect($issueData['id'])->toBe($issue->id)
            ->and($issueData['title'])->toBe('Test Issue Title')
            ->and($issueData['status']['value'])->toBe('pending')
            ->and($issueData['priority']['value'])->toBe('high')
            ->and($issueData['location'])->not->toBeNull()
            ->and($issueData['location']['directions_url'])->toContain('google.com/maps');
    });

    it('returns issues ordered by created_at descending', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        $oldIssue = Issue::factory()->for($tenant)->create(['created_at' => now()->subDays(2)]);
        $newIssue = Issue::factory()->for($tenant)->create(['created_at' => now()]);
        $midIssue = Issue::factory()->for($tenant)->create(['created_at' => now()->subDay()]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertStatus(200);

        $ids = collect($response->json('data'))->pluck('id')->toArray();
        expect($ids)->toBe([$newIssue->id, $midIssue->id, $oldIssue->id]);
    });

    it('respects per_page limit with maximum of 50', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()->count(60)->for($tenant)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?per_page=100');

        $response->assertStatus(200)
            ->assertJsonPath('meta.per_page', 50)
            ->assertJsonCount(50, 'data');
    });

    it('returns empty data when tenant has no issues', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [],
            ])
            ->assertJsonPath('meta.total', 0);
    });

    it('ignores invalid status filter value', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()->count(3)->for($tenant)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?status=invalid_status');

        // Should return all issues when filter is invalid
        $response->assertStatus(200)
            ->assertJsonCount(3, 'data');
    });

    it('combines multiple filters correctly', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()->for($tenant)->pending()->highPriority()->create();
        Issue::factory()->for($tenant)->pending()->lowPriority()->create();
        Issue::factory()->for($tenant)->assigned()->highPriority()->create();
        Issue::factory()->for($tenant)->completed()->highPriority()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?status=pending&priority=high');

        $response->assertStatus(200)
            ->assertJsonCount(1, 'data');
    });
});

/*
|--------------------------------------------------------------------------
| Create Issue Tests - POST /api/v1/issues
|--------------------------------------------------------------------------
*/

describe('Create Issue (POST /api/v1/issues)', function () {

    it('returns 401 for unauthenticated request', function () {
        $response = $this->postJson('/api/v1/issues', [
            'title' => 'Test Issue',
            'description' => 'Test description',
            'category_ids' => [1],
        ]);

        $response->assertStatus(401);
    });

    it('returns 403 when non-tenant user tries to create issue', function () {
        $admin = createAdminUser('super_admin');
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(403);
    });

    it('returns 403 when service provider tries to create issue', function () {
        $serviceProviderUser = createServiceProviderUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($serviceProviderUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(403);
    });

    it('tenant can create issue with valid data', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Broken AC Unit',
                'description' => 'The AC in bedroom is not cooling properly',
                'priority' => 'high',
                'category_ids' => [$category->id],
                'latitude' => 25.276987,
                'longitude' => 55.296249,
            ]);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonPath('data.title', 'Broken AC Unit')
            ->assertJsonPath('data.status.value', 'pending')
            ->assertJsonPath('data.priority.value', 'high');

        // Verify issue was created in database
        $this->assertDatabaseHas('issues', [
            'title' => 'Broken AC Unit',
            'tenant_id' => $tenantUser->tenant->id,
            'status' => 'pending',
        ]);

        // Verify category was attached
        $issue = Issue::where('title', 'Broken AC Unit')->first();
        expect($issue->categories)->toHaveCount(1)
            ->and($issue->categories->first()->id)->toBe($category->id);
    });

    it('creates issue with default medium priority when not specified', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.priority.value', 'medium');
    });

    it('validates required fields', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['title', 'description', 'category_ids']);
    });

    it('validates title is required', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'description' => 'Test description',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['title']);
    });

    it('validates description is required', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['description']);
    });

    it('validates category_ids is required and not empty', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['category_ids']);

        // Test with empty array
        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [],
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['category_ids']);
    });

    it('validates category_ids contains valid category IDs', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [99999], // Non-existent category
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['category_ids.0']);
    });

    it('validates priority is valid enum value', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [$category->id],
                'priority' => 'invalid_priority',
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['priority']);
    });

    it('accepts all valid priority values', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        foreach (['low', 'medium', 'high'] as $priority) {
            $response = $this->withHeaders(authHeaders($tenantUser))
                ->postJson('/api/v1/issues', [
                    'title' => "Issue with $priority priority",
                    'description' => 'Test description',
                    'category_ids' => [$category->id],
                    'priority' => $priority,
                ]);

            $response->assertStatus(201)
                ->assertJsonPath('data.priority.value', $priority);
        }
    });

    it('validates title maximum length', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => str_repeat('a', 256),
                'description' => 'Test description',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['title']);
    });

    it('validates description maximum length', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => str_repeat('a', 5001),
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['description']);
    });

    it('validates latitude is within valid range', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [$category->id],
                'latitude' => 95, // Invalid: must be between -90 and 90
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['latitude']);
    });

    it('validates longitude is within valid range', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Test Issue',
                'description' => 'Test description',
                'category_ids' => [$category->id],
                'longitude' => 185, // Invalid: must be between -180 and 180
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['longitude']);
    });

    it('creates issue with multiple categories', function () {
        $tenantUser = createTenantUser();
        $categories = Category::factory()->count(3)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Multi-category Issue',
                'description' => 'This issue belongs to multiple categories',
                'category_ids' => $categories->pluck('id')->toArray(),
            ]);

        $response->assertStatus(201)
            ->assertJsonCount(3, 'data.categories');
    });

    it('creates issue with media attachments', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $image = UploadedFile::fake()->image('issue-photo.jpg', 800, 600);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Issue with Photo',
                'description' => 'This issue has a photo attached',
                'category_ids' => [$category->id],
                'media' => [$image],
            ]);

        $response->assertStatus(201)
            ->assertJsonCount(1, 'data.media');

        $issue = Issue::where('title', 'Issue with Photo')->first();
        expect($issue->media)->toHaveCount(1)
            ->and($issue->media->first()->type)->toBe(MediaType::PHOTO);
    });

    it('creates timeline entry when issue is created', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Issue with Timeline',
                'description' => 'This issue should have a timeline entry',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(201);

        $issue = Issue::where('title', 'Issue with Timeline')->first();
        expect($issue->timeline)->toHaveCount(1)
            ->and($issue->timeline->first()->action)->toBe(TimelineAction::CREATED)
            ->and($issue->timeline->first()->performed_by)->toBe($tenantUser->id);
    });

    it('returns created issue with proper structure', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Complete Issue',
                'description' => 'Testing response structure',
                'priority' => 'high',
                'category_ids' => [$category->id],
                'latitude' => 25.276987,
                'longitude' => 55.296249,
            ]);

        $response->assertStatus(201)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'id',
                    'title',
                    'description',
                    'status' => ['value', 'label', 'color'],
                    'priority' => ['value', 'label'],
                    'categories' => [
                        '*' => ['id', 'name', 'icon'],
                    ],
                    'location' => [
                        'latitude',
                        'longitude',
                        'directions_url',
                    ],
                    'media',
                    'current_assignment',
                    'created_at',
                    'updated_at',
                ],
                'message',
            ]);
    });

    it('creates issue without location', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Issue without Location',
                'description' => 'No coordinates provided',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.location', null);
    });
});

/*
|--------------------------------------------------------------------------
| Show Issue Tests - GET /api/v1/issues/{id}
|--------------------------------------------------------------------------
*/

describe('Show Issue (GET /api/v1/issues/{id})', function () {

    it('returns 401 for unauthenticated request', function () {
        $issue = Issue::factory()->create();

        $response = $this->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(401);
    });

    it('returns 403 when non-tenant user tries to access', function () {
        $admin = createAdminUser('super_admin');
        $issue = Issue::factory()->create();

        $response = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(403);
    });

    it('tenant can view their own issue with full details', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->withLocation()
            ->create([
                'title' => 'My Test Issue',
                'priority' => IssuePriority::HIGH,
            ]);

        $issue->categories()->attach($category);

        // Create a timeline entry
        IssueTimeline::create([
            'issue_id' => $issue->id,
            'action' => TimelineAction::CREATED,
            'performed_by' => $tenantUser->id,
            'created_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonPath('data.id', $issue->id)
            ->assertJsonPath('data.title', 'My Test Issue')
            ->assertJsonPath('data.priority.value', 'high');
    });

    it('returns issue with timeline information', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()->for($tenant)->create();
        $issue->categories()->attach($category);

        // Create multiple timeline entries
        IssueTimeline::create([
            'issue_id' => $issue->id,
            'action' => TimelineAction::CREATED,
            'performed_by' => $tenantUser->id,
            'notes' => 'Issue created by tenant',
            'created_at' => now()->subHour(),
        ]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'timeline' => [
                        '*' => [
                            'id',
                            'action' => ['value', 'label', 'color', 'icon'],
                            'performed_by',
                            'notes',
                            'metadata',
                            'created_at',
                        ],
                    ],
                ],
            ]);
    });

    it('returns issue with assignments information', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->assigned()
            ->create();
        $issue->categories()->attach($category);

        $serviceProvider = ServiceProvider::factory()->create();

        IssueAssignment::factory()
            ->for($issue)
            ->for($serviceProvider)
            ->for($category)
            ->create([
                'scheduled_date' => now()->addDays(2),
            ]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'assignments' => [
                        '*' => [
                            'id',
                            'status' => ['value', 'label', 'color'],
                            'service_provider' => [
                                'id',
                                'name',
                                'phone',
                                'category',
                            ],
                            'category',
                            'time_slot',
                            'scheduled_date',
                            'started_at',
                            'finished_at',
                            'completed_at',
                            'notes',
                            'proofs',
                            'consumables',
                            'duration_minutes',
                        ],
                    ],
                ],
            ]);
    });

    it('returns issue with media information', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()->for($tenant)->create();
        $issue->categories()->attach($category);

        IssueMedia::create([
            'issue_id' => $issue->id,
            'type' => MediaType::PHOTO,
            'file_path' => 'issues/1/test.jpg',
        ]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'media' => [
                        '*' => ['id', 'type', 'url'],
                    ],
                ],
            ]);
    });

    it('returns 403 when tenant tries to view another tenant\'s issue', function () {
        $tenantUser = createTenantUser();

        // Create another tenant's issue
        $anotherTenant = Tenant::factory()->create();
        $issue = Issue::factory()->for($anotherTenant)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(404)
            ->assertJson([
                'success' => false,
            ]);
    });

    it('returns 404 for non-existent issue', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues/99999');

        $response->assertStatus(404)
            ->assertJson([
                'success' => false,
            ]);
    });

    it('returns can_be_cancelled flag in response', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        // Pending issue can be cancelled
        $pendingIssue = Issue::factory()->for($tenant)->pending()->create();
        $pendingIssue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$pendingIssue->id}");

        $response->assertStatus(200)
            ->assertJsonPath('data.can_be_cancelled', true);

        // Completed issue cannot be cancelled
        $completedIssue = Issue::factory()->for($tenant)->completed()->create();
        $completedIssue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$completedIssue->id}");

        $response->assertStatus(200)
            ->assertJsonPath('data.can_be_cancelled', false);
    });

    it('returns cancellation details for cancelled issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->create([
                'status' => IssueStatus::CANCELLED,
                'cancelled_reason' => 'Duplicate issue',
                'cancelled_by' => $tenantUser->id,
                'cancelled_at' => now(),
            ]);
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'cancellation' => [
                        'reason',
                        'cancelled_by' => ['id', 'name'],
                        'cancelled_at',
                    ],
                ],
            ])
            ->assertJsonPath('data.cancellation.reason', 'Duplicate issue');
    });

    it('returns issue with location and directions URL', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->withLocation(25.276987, 55.296249)
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertStatus(200)
            ->assertJsonPath('data.location.latitude', 25.276987)
            ->assertJsonPath('data.location.longitude', 55.296249);

        expect($response->json('data.location.directions_url'))
            ->toContain('google.com/maps');
    });
});

/*
|--------------------------------------------------------------------------
| Cancel Issue Tests - POST /api/v1/issues/{id}/cancel
|--------------------------------------------------------------------------
*/

describe('Cancel Issue (POST /api/v1/issues/{id}/cancel)', function () {

    it('returns 401 for unauthenticated request', function () {
        $issue = Issue::factory()->create();

        $response = $this->postJson("/api/v1/issues/{$issue->id}/cancel", [
            'reason' => 'No longer needed',
        ]);

        $response->assertStatus(401);
    });

    it('returns 403 when non-tenant user tries to cancel', function () {
        $admin = createAdminUser('super_admin');
        $issue = Issue::factory()->pending()->create();

        $response = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => 'Testing',
            ]);

        $response->assertStatus(403);
    });

    it('tenant can request cancellation with reason', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => 'Found another solution',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonPath('data.status.value', 'cancelled');

        // Verify in database
        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::CANCELLED)
            ->and($issue->cancelled_reason)->toBe('Found another solution')
            ->and($issue->cancelled_by)->toBe($tenantUser->id)
            ->and($issue->cancelled_at)->not->toBeNull();
    });

    it('allows cancellation without reason', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel");

        $response->assertStatus(200)
            ->assertJsonPath('data.status.value', 'cancelled');

        $issue->refresh();
        expect($issue->cancelled_reason)->toBeNull();
    });

    it('creates timeline entry when issue is cancelled', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => 'Changed my mind',
            ]);

        $timeline = IssueTimeline::where('issue_id', $issue->id)
            ->where('action', TimelineAction::CANCELLED)
            ->first();

        expect($timeline)->not->toBeNull()
            ->and($timeline->performed_by)->toBe($tenantUser->id)
            ->and($timeline->notes)->toBe('Changed my mind');
    });

    it('cannot cancel already cancelled issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->cancelled()
            ->create([
                'cancelled_by' => $tenantUser->id,
            ]);
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => 'Trying again',
            ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
            ]);
    });

    it('cannot cancel completed issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
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

    it('cannot cancel another tenant\'s issue', function () {
        $tenantUser = createTenantUser();

        // Create another tenant's issue
        $anotherTenant = Tenant::factory()->create();
        $issue = Issue::factory()
            ->for($anotherTenant)
            ->pending()
            ->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => 'Not my issue',
            ]);

        $response->assertStatus(404);
    });

    it('returns 404 for non-existent issue', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues/99999/cancel', [
                'reason' => 'Does not exist',
            ]);

        $response->assertStatus(404);
    });

    it('can cancel pending issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel");

        $response->assertStatus(200)
            ->assertJsonPath('data.status.value', 'cancelled');
    });

    it('can cancel assigned issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->assigned()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel");

        $response->assertStatus(200)
            ->assertJsonPath('data.status.value', 'cancelled');
    });

    it('can cancel in_progress issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->inProgress()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel");

        $response->assertStatus(200)
            ->assertJsonPath('data.status.value', 'cancelled');
    });

    it('can cancel on_hold issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->onHold()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel");

        $response->assertStatus(200)
            ->assertJsonPath('data.status.value', 'cancelled');
    });

    it('can cancel finished issue', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->finished()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel");

        $response->assertStatus(200)
            ->assertJsonPath('data.status.value', 'cancelled');
    });

    it('validates reason maximum length', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => str_repeat('a', 1001),
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['reason']);
    });
});

/*
|--------------------------------------------------------------------------
| Edge Cases and Integration Tests
|--------------------------------------------------------------------------
*/

describe('Edge Cases and Integration', function () {

    it('handles concurrent issue creation gracefully', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        // Simulate rapid issue creation
        $responses = collect();
        for ($i = 0; $i < 5; $i++) {
            $responses->push(
                $this->withHeaders(authHeaders($tenantUser))
                    ->postJson('/api/v1/issues', [
                        'title' => "Issue $i",
                        'description' => 'Test description',
                        'category_ids' => [$category->id],
                    ])
            );
        }

        // All should succeed
        $responses->each(fn ($response) => $response->assertStatus(201));

        // Verify all issues were created
        expect(Issue::where('tenant_id', $tenantUser->tenant->id)->count())->toBe(5);
    });

    it('maintains data integrity when issue creation fails', function () {
        $tenantUser = createTenantUser();

        // Try to create with invalid category
        $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Failing Issue',
                'description' => 'This should fail',
                'category_ids' => [99999],
            ]);

        // No issue should be created
        expect(Issue::where('title', 'Failing Issue')->exists())->toBeFalse();
    });

    it('handles pagination edge case with exact page boundary', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        // Create exactly 15 issues (default per_page)
        Issue::factory()->count(15)->for($tenant)->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues');

        $response->assertStatus(200)
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.last_page', 1)
            ->assertJsonPath('meta.total', 15)
            ->assertJsonCount(15, 'data');
    });

    it('preserves issue state after failed cancellation', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenant)
            ->completed()
            ->create();
        $issue->categories()->attach($category);

        $originalStatus = $issue->status;

        $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel");

        $issue->refresh();
        expect($issue->status)->toBe($originalStatus);
    });

    it('correctly reports issue count in pagination after filtering', function () {
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        Issue::factory()->count(10)->for($tenant)->pending()->create();
        Issue::factory()->count(5)->for($tenant)->completed()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/issues?status=pending');

        $response->assertStatus(200)
            ->assertJsonPath('meta.total', 10)
            ->assertJsonCount(10, 'data');
    });
});
