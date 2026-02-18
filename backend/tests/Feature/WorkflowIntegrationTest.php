<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Enums\TimelineAction;
use App\Models\Category;
use App\Models\Consumable;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\IssueTimeline;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/*
|--------------------------------------------------------------------------
| End-to-End Workflow Integration Test
|--------------------------------------------------------------------------
|
| This test walks through the FULL issue lifecycle across all 5 phases:
|
| Phase 1: Initial Setup
|   - Super Admin creates category hierarchy
|   - Super Admin onboards Service Provider with category assignments
|   - Super Admin creates Tenant account
|
| Phase 2: Issue Lifecycle
|   - Tenant creates issue via API with description, category, priority
|   - Issue stored as pending, timeline created
|
| Phase 3: Administrative Review
|   - Admin sees issue in dashboard
|   - Admin assigns SP using category hierarchy scoping
|   - Assignment record created
|
| Phase 4: Service Provider Execution
|   - SP receives assignment
|   - SP starts work (status -> in_progress)
|   - SP holds work (status -> on_hold)
|   - SP resumes work (status -> in_progress)
|   - SP finishes work with notes, proofs, consumables
|
| Phase 5: Completion & Audit
|   - Admin approves finished work (status -> completed)
|   - Tenant sees completed issue
|   - Timeline has full audit trail
|
*/

beforeEach(function () {
    $this->seed(RolesAndPermissionsSeeder::class);
    Storage::fake('public');
});

describe('Full Issue Lifecycle - Golden Path', function () {

    it('completes the entire workflow from setup to approval', function () {
        // =====================================================================
        // PHASE 1: Initial Setup
        // =====================================================================

        // 1a. Super Admin creates category hierarchy
        $admin = createAdminUser('super_admin');
        $adminToken = getAuthToken($admin);

        $rootCategory = Category::create([
            'name_en' => 'HVAC',
            'name_ar' => 'تكييف',
            'is_active' => true,
        ]);

        $childCategory = Category::create([
            'parent_id' => $rootCategory->id,
            'name_en' => 'Air Conditioning',
            'name_ar' => 'مكيفات',
            'is_active' => true,
        ]);

        // Verify materialized path
        $childCategory->refresh();
        expect($childCategory->getAncestorIds())->toContain($rootCategory->id);

        // 1b. Super Admin creates Service Provider with category assignment
        $spResponse = $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->postJson('/api/v1/admin/service-providers', [
                'name' => 'Ahmed HVAC Expert',
                'email' => 'ahmed-hvac@test.com',
                'phone' => '+966500000001',
                'password' => 'securepassword123',
                'category_id' => $rootCategory->id,
            ]);

        $spResponse->assertStatus(201);
        $spId = $spResponse->json('data.id');
        $sp = ServiceProvider::find($spId);

        // Attach SP to root category (many-to-many)
        $sp->categories()->attach([$rootCategory->id]);

        // Verify SP appears for child category queries (ancestor scoping)
        $spResults = ServiceProvider::available()
            ->forCategoryWithAncestors($childCategory->id)
            ->pluck('id')
            ->toArray();
        expect($spResults)->toContain($sp->id);

        // Create time slot for the SP
        $timeSlot = TimeSlot::factory()->create([
            'service_provider_id' => $sp->id,
            'day_of_week' => now()->dayOfWeek,
            'start_time' => '09:00:00',
            'end_time' => '17:00:00',
            'is_active' => true,
        ]);

        // 1c. Super Admin creates Tenant account
        $tenantResponse = $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->postJson('/api/v1/admin/tenants', [
                'name' => 'Fatima Resident',
                'email' => 'fatima@test.com',
                'phone' => '+966500000002',
                'password' => 'tenantpassword123',
                'unit_number' => 'A-101',
                'building_name' => 'Tower Alpha',
                'locale' => 'en',
            ]);

        $tenantResponse->assertStatus(201);

        // =====================================================================
        // PHASE 2: Issue Lifecycle - Tenant creates issue
        // =====================================================================

        // Tenant logs in
        $tenantLoginResponse = $this->postJson('/api/v1/auth/login', [
            'email' => 'fatima@test.com',
            'password' => 'tenantpassword123',
        ]);

        $tenantLoginResponse->assertOk();
        $tenantToken = $tenantLoginResponse->json('data.access_token');
        $tenantUserId = $tenantLoginResponse->json('data.user.id');

        // Verify tenant role
        expect($tenantLoginResponse->json('data.user.is_tenant'))->toBeTrue();

        // Tenant creates an issue
        $issuePhoto = UploadedFile::fake()->image('broken-ac.jpg', 800, 600);

        $createIssueResponse = $this->withHeader('Authorization', "Bearer {$tenantToken}")
            ->postJson('/api/v1/issues', [
                'title' => 'AC Unit Not Cooling - Bedroom',
                'description' => 'The air conditioning unit in the master bedroom has stopped cooling. It runs but only blows warm air.',
                'priority' => 'high',
                'category_ids' => [$childCategory->id],
                'latitude' => 24.7136,
                'longitude' => 46.6753,
                'media' => [$issuePhoto],
            ]);

        $createIssueResponse->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'title' => 'AC Unit Not Cooling - Bedroom',
                    'status' => ['value' => 'pending'],
                    'priority' => ['value' => 'high'],
                ],
            ]);

        $issueId = $createIssueResponse->json('data.id');

        // Verify timeline entry created
        $issue = Issue::find($issueId);
        $createdTimeline = IssueTimeline::where('issue_id', $issueId)
            ->where('action', TimelineAction::CREATED)
            ->first();
        expect($createdTimeline)->not->toBeNull()
            ->and($createdTimeline->performed_by)->toBe($tenantUserId);

        // Verify media attached
        expect($issue->media)->toHaveCount(1);

        // Verify category attached
        expect($issue->categories)->toHaveCount(1)
            ->and($issue->categories->first()->id)->toBe($childCategory->id);

        // =====================================================================
        // PHASE 3: Administrative Review
        // =====================================================================

        // Admin sees the issue in dashboard
        $dashboardResponse = $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->getJson('/api/v1/admin/dashboard/stats');

        $dashboardResponse->assertOk();
        $pendingCount = $dashboardResponse->json('data.issues.pending');
        expect($pendingCount)->toBeGreaterThanOrEqual(1);

        // Admin views the issue
        $adminIssueResponse = $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $adminIssueResponse->assertOk()
            ->assertJsonPath('data.id', $issueId)
            ->assertJsonPath('data.title', 'AC Unit Not Cooling - Bedroom')
            ->assertJsonPath('data.status.value', 'pending');

        // Admin assigns SP to the issue
        $assignResponse = $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp->id,
                'scheduled_date' => now()->toDateString(),
                'time_slot_id' => $timeSlot->id,
                'notes' => 'Please check the AC compressor and refrigerant levels.',
            ]);

        $assignResponse->assertOk()
            ->assertJson(['success' => true]);

        // Verify issue status changed to assigned
        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::ASSIGNED);

        // Verify assignment created
        $assignment = IssueAssignment::where('issue_id', $issueId)
            ->where('service_provider_id', $sp->id)
            ->first();
        expect($assignment)->not->toBeNull()
            ->and($assignment->status)->toBe(AssignmentStatus::ASSIGNED);

        // =====================================================================
        // PHASE 4: Service Provider Execution
        // =====================================================================

        // SP logs in
        $spLoginResponse = $this->postJson('/api/v1/auth/login', [
            'email' => 'ahmed-hvac@test.com',
            'password' => 'securepassword123',
        ]);

        $spLoginResponse->assertOk();
        $spToken = $spLoginResponse->json('data.access_token');

        expect($spLoginResponse->json('data.user.is_service_provider'))->toBeTrue();

        // SP sees their assignment
        $spAssignmentsResponse = $this->withHeader('Authorization', "Bearer {$spToken}")
            ->getJson('/api/v1/assignments');

        $spAssignmentsResponse->assertOk();
        $spAssignments = $spAssignmentsResponse->json('data');
        expect($spAssignments)->toHaveCount(1);
        expect($spAssignments[0]['id'])->toBe($assignment->id);
        expect($spAssignments[0]['issue']['title'])->toBe('AC Unit Not Cooling - Bedroom');

        // SP views assignment detail
        $spAssignmentDetailResponse = $this->withHeader('Authorization', "Bearer {$spToken}")
            ->getJson("/api/v1/assignments/{$assignment->id}");

        $spAssignmentDetailResponse->assertOk()
            ->assertJsonPath('data.can_start', true)
            ->assertJsonPath('data.can_hold', false)
            ->assertJsonPath('data.can_finish', false);

        // 4a. SP starts work
        $startResponse = $this->withHeader('Authorization', "Bearer {$spToken}")
            ->postJson("/api/v1/assignments/{$assignment->id}/start");

        $startResponse->assertOk()
            ->assertJsonPath('data.status.value', 'in_progress')
            ->assertJsonPath('data.can_hold', true)
            ->assertJsonPath('data.can_finish', true);

        $assignment->refresh();
        $issue->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::IN_PROGRESS)
            ->and($assignment->started_at)->not->toBeNull()
            ->and($issue->status)->toBe(IssueStatus::IN_PROGRESS);

        // 4b. SP puts work on hold (waiting for parts)
        $holdResponse = $this->withHeader('Authorization', "Bearer {$spToken}")
            ->postJson("/api/v1/assignments/{$assignment->id}/hold", [
                'reason' => 'Waiting for replacement compressor part to arrive',
            ]);

        $holdResponse->assertOk()
            ->assertJsonPath('data.status.value', 'on_hold')
            ->assertJsonPath('data.can_resume', true);

        $assignment->refresh();
        $issue->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::ON_HOLD)
            ->and($issue->status)->toBe(IssueStatus::ON_HOLD);

        // Verify hold timeline with reason
        $holdTimeline = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::HELD)
            ->first();
        expect($holdTimeline)->not->toBeNull()
            ->and($holdTimeline->notes)->toBe('Waiting for replacement compressor part to arrive');

        // 4c. SP resumes work
        $resumeResponse = $this->withHeader('Authorization', "Bearer {$spToken}")
            ->postJson("/api/v1/assignments/{$assignment->id}/resume");

        $resumeResponse->assertOk()
            ->assertJsonPath('data.status.value', 'in_progress');

        $assignment->refresh();
        $issue->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::IN_PROGRESS)
            ->and($issue->status)->toBe(IssueStatus::IN_PROGRESS);

        // 4d. SP finishes work with proofs, notes, and consumables
        $proofPhoto = UploadedFile::fake()->image('completed-work.jpg', 800, 600);

        $consumable = Consumable::create([
            'category_id' => $rootCategory->id,
            'name_en' => 'Refrigerant R-410A',
            'name_ar' => 'مبرد',
            'is_active' => true,
        ]);

        $finishResponse = $this->withHeader('Authorization', "Bearer {$spToken}")
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'notes' => 'Replaced compressor and recharged refrigerant. AC is now cooling at expected temperature.',
                'proofs' => [$proofPhoto],
                'consumables' => [
                    [
                        'consumable_id' => $consumable->id,
                        'quantity' => 1,
                    ],
                    [
                        'custom_name' => 'Compressor Belt',
                        'quantity' => 1,
                    ],
                ],
            ]);

        $finishResponse->assertOk()
            ->assertJsonPath('data.status.value', 'finished')
            ->assertJsonPath('data.notes', 'Replaced compressor and recharged refrigerant. AC is now cooling at expected temperature.')
            ->assertJsonCount(1, 'data.proofs')
            ->assertJsonCount(2, 'data.consumables');

        $assignment->refresh();
        $issue->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::FINISHED)
            ->and($assignment->finished_at)->not->toBeNull()
            ->and($issue->status)->toBe(IssueStatus::FINISHED);

        // =====================================================================
        // PHASE 5: Completion & Audit
        // =====================================================================

        // Admin approves the finished work
        $approveResponse = $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->postJson("/api/v1/admin/issues/{$issueId}/approve");

        $approveResponse->assertOk()
            ->assertJson([
                'success' => true,
                'data' => ['status' => 'completed'],
            ]);

        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::COMPLETED);

        // Tenant can see the completed issue
        $tenantIssueResponse = $this->withHeader('Authorization', "Bearer {$tenantToken}")
            ->getJson("/api/v1/issues/{$issueId}");

        $tenantIssueResponse->assertOk()
            ->assertJsonPath('data.status.value', 'completed');

        // Verify complete audit trail
        $timelineEntries = IssueTimeline::where('issue_id', $issueId)
            ->orderBy('created_at')
            ->get();

        $timelineActions = $timelineEntries->pluck('action')->map(fn ($a) => $a->value)->toArray();

        // The timeline should contain the full workflow
        expect($timelineActions)->toContain('created')
            ->and($timelineActions)->toContain('started')
            ->and($timelineActions)->toContain('held')
            ->and($timelineActions)->toContain('resumed')
            ->and($timelineActions)->toContain('finished');
    });

});

/*
|--------------------------------------------------------------------------
| Alternative Paths
|--------------------------------------------------------------------------
*/

describe('Alternative Workflow: Admin Cancellation', function () {

    it('admin can cancel an issue with a reason before assignment', function () {
        $admin = createAdminUser('super_admin');
        $adminToken = getAuthToken($admin);

        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        // Tenant creates issue
        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create(['title' => 'Duplicate Report']);
        $issue->categories()->attach($category);

        // Admin cancels with reason
        $cancelResponse = $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->postJson("/api/v1/admin/issues/{$issue->id}/cancel", [
                'reason' => 'Duplicate of issue #42. Already being addressed.',
            ]);

        $cancelResponse->assertOk()
            ->assertJson([
                'success' => true,
                'data' => ['status' => 'cancelled'],
            ]);

        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::CANCELLED)
            ->and($issue->cancelled_reason)->toBe('Duplicate of issue #42. Already being addressed.')
            ->and($issue->cancelled_by)->toBe($admin->id)
            ->and($issue->cancelled_at)->not->toBeNull();

        // Tenant sees the cancellation
        $tenantToken = getAuthToken($tenantUser);
        $tenantView = $this->withHeader('Authorization', "Bearer {$tenantToken}")
            ->getJson("/api/v1/issues/{$issue->id}");

        $tenantView->assertOk()
            ->assertJsonPath('data.status.value', 'cancelled')
            ->assertJsonPath('data.cancellation.reason', 'Duplicate of issue #42. Already being addressed.');
    });
});

describe('Alternative Workflow: Tenant Self-Cancellation', function () {

    it('tenant can cancel their own pending issue', function () {
        $tenantUser = createTenantUser();
        $tenantToken = getAuthToken($tenantUser);
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create(['title' => 'Wrong report']);
        $issue->categories()->attach($category);

        $cancelResponse = $this->withHeader('Authorization', "Bearer {$tenantToken}")
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => 'I reported this by mistake',
            ]);

        $cancelResponse->assertOk()
            ->assertJsonPath('data.status.value', 'cancelled');

        // Verify timeline
        $cancelTimeline = IssueTimeline::where('issue_id', $issue->id)
            ->where('action', TimelineAction::CANCELLED)
            ->first();

        expect($cancelTimeline)->not->toBeNull()
            ->and($cancelTimeline->performed_by)->toBe($tenantUser->id)
            ->and($cancelTimeline->notes)->toBe('I reported this by mistake');
    });
});

describe('Alternative Workflow: Manager Assignment', function () {

    it('manager can assign issues and approve work', function () {
        $manager = createAdminUser('manager');
        $managerToken = getAuthToken($manager);

        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $sp = ServiceProvider::factory()->create();
        $sp->categories()->attach([$category->id]);

        $timeSlot = TimeSlot::factory()->create([
            'service_provider_id' => $sp->id,
            'day_of_week' => now()->dayOfWeek,
            'start_time' => '09:00:00',
            'end_time' => '17:00:00',
            'is_active' => true,
        ]);

        // Manager assigns
        $assignResponse = $this->withHeader('Authorization', "Bearer {$managerToken}")
            ->postJson("/api/v1/admin/issues/{$issue->id}/assign", [
                'service_provider_id' => $sp->id,
                'scheduled_date' => now()->toDateString(),
                'time_slot_id' => $timeSlot->id,
            ]);

        $assignResponse->assertOk();

        // SP completes work
        $spUser = $sp->user;
        $spToken = getAuthToken($spUser);

        $assignment = IssueAssignment::where('issue_id', $issue->id)->first();

        $this->withHeader('Authorization', "Bearer {$spToken}")
            ->postJson("/api/v1/assignments/{$assignment->id}/start")
            ->assertOk();

        $this->withHeader('Authorization', "Bearer {$spToken}")
            ->postJson("/api/v1/assignments/{$assignment->id}/finish")
            ->assertOk();

        // Manager approves
        $approveResponse = $this->withHeader('Authorization', "Bearer {$managerToken}")
            ->postJson("/api/v1/admin/issues/{$issue->id}/approve");

        $approveResponse->assertOk();

        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::COMPLETED);
    });
});

describe('Isolation: Cross-tenant data isolation', function () {

    it('tenant A cannot see tenant B issues or cancel them', function () {
        $tenantA = createTenantUser([], ['name' => 'Tenant A']);
        $tenantB = createTenantUser([], ['name' => 'Tenant B']);
        $category = Category::factory()->create();

        $issueA = Issue::factory()->for($tenantA->tenant)->create(['title' => 'A issue']);
        $issueA->categories()->attach($category);

        $issueB = Issue::factory()->for($tenantB->tenant)->create(['title' => 'B issue']);
        $issueB->categories()->attach($category);

        $tokenA = getAuthToken($tenantA);
        $tokenB = getAuthToken($tenantB);

        // Tenant A list should only show their issue
        $listA = $this->withHeader('Authorization', "Bearer {$tokenA}")
            ->getJson('/api/v1/issues');
        $listA->assertOk()->assertJsonCount(1, 'data');
        expect($listA->json('data.0.title'))->toBe('A issue');

        // Tenant A cannot view Tenant B's issue
        $viewB = $this->withHeader('Authorization', "Bearer {$tokenA}")
            ->getJson("/api/v1/issues/{$issueB->id}");
        $viewB->assertStatus(404);

        // Tenant A cannot cancel Tenant B's issue
        $cancelB = $this->withHeader('Authorization', "Bearer {$tokenA}")
            ->postJson("/api/v1/issues/{$issueB->id}/cancel", ['reason' => 'Not mine']);
        $cancelB->assertStatus(404);
    });
});

describe('Isolation: Cross-SP assignment isolation', function () {

    it('SP A cannot see or act on SP B assignments', function () {
        $spUserA = createServiceProviderUser([], ['name' => 'SP A']);
        $spUserB = createServiceProviderUser([], ['name' => 'SP B']);
        $tenantUser = createTenantUser();

        $issue = Issue::factory()->for($tenantUser->tenant)->create();

        $assignmentA = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUserA->serviceProvider->id,
            'category_id' => $spUserA->serviceProvider->category_id,
            'status' => AssignmentStatus::ASSIGNED,
            'scheduled_date' => now()->addDay()->toDateString(),
            'proof_required' => false,
        ]);

        $tokenB = getAuthToken($spUserB);

        // SP B cannot see SP A's assignment
        $this->withHeader('Authorization', "Bearer {$tokenB}")
            ->getJson("/api/v1/assignments/{$assignmentA->id}")
            ->assertNotFound();

        // SP B cannot start SP A's assignment
        $this->withHeader('Authorization', "Bearer {$tokenB}")
            ->postJson("/api/v1/assignments/{$assignmentA->id}/start")
            ->assertNotFound();
    });
});
