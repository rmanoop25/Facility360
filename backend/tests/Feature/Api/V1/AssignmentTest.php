<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Enums\IssuePriority;
use App\Enums\ProofStage;
use App\Enums\ProofType;
use App\Enums\TimelineAction;
use App\Models\Category;
use App\Models\Consumable;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\IssueAssignmentConsumable;
use App\Models\IssueTimeline;
use App\Models\Proof;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/*
|--------------------------------------------------------------------------
| Service Provider Assignment API Tests
|--------------------------------------------------------------------------
|
| Comprehensive tests for the service provider assignment endpoints:
| - GET /api/v1/assignments - List SP's assignments
| - GET /api/v1/assignments/{id} - Get assignment details
| - POST /api/v1/assignments/{id}/start - Start work
| - POST /api/v1/assignments/{id}/hold - Put work on hold
| - POST /api/v1/assignments/{id}/resume - Resume work
| - POST /api/v1/assignments/{id}/finish - Complete work (with proofs)
|
*/

/*
|--------------------------------------------------------------------------
| Local Helper Functions
|--------------------------------------------------------------------------
*/

/**
 * Create an issue with a tenant.
 */
function createIssue(Tenant $tenant, array $attributes = []): Issue
{
    return Issue::create(array_merge([
        'tenant_id' => $tenant->id,
        'title' => 'Test Issue',
        'description' => 'Test issue description',
        'status' => IssueStatus::PENDING,
        'priority' => IssuePriority::MEDIUM,
        'proof_required' => false,
    ], $attributes));
}

/**
 * Create an assignment for an issue.
 */
function createAssignment(
    Issue $issue,
    ServiceProvider $serviceProvider,
    array $attributes = []
): IssueAssignment {
    return IssueAssignment::create(array_merge([
        'issue_id' => $issue->id,
        'service_provider_id' => $serviceProvider->id,
        'category_id' => $serviceProvider->category_id,
        'status' => AssignmentStatus::ASSIGNED,
        'scheduled_date' => now()->addDay()->toDateString(),
        'proof_required' => false,
    ], $attributes));
}

/*
|--------------------------------------------------------------------------
| List Assignments Tests
|--------------------------------------------------------------------------
*/

describe('GET /api/v1/assignments (List Assignments)', function () {
    beforeEach(function () {
        Storage::fake('public');
    });

    test('service provider sees only their assigned work', function () {
        // Create two service providers
        $sp1User = createServiceProviderUser([], ['name' => 'SP One']);
        $sp2User = createServiceProviderUser([], ['name' => 'SP Two']);

        // Create a tenant and issues
        $tenantUser = createTenantUser();
        $tenant = $tenantUser->tenant;

        $issue1 = createIssue($tenant, ['title' => 'Issue for SP1']);
        $issue2 = createIssue($tenant, ['title' => 'Issue for SP2']);
        $issue3 = createIssue($tenant, ['title' => 'Another Issue for SP1']);

        // Create assignments
        createAssignment($issue1, $sp1User->serviceProvider);
        createAssignment($issue2, $sp2User->serviceProvider);
        createAssignment($issue3, $sp1User->serviceProvider);

        // SP1 should see only their 2 assignments
        $response = $this->withHeaders(authHeaders($sp1User))
            ->getJson('/api/v1/assignments');

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(2, 'data');

        // SP2 should see only their 1 assignment
        $response = $this->withHeaders(authHeaders($sp2User))
            ->getJson('/api/v1/assignments');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.issue.title', 'Issue for SP2');
    });

    test('returns paginated response', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        // Create 20 issues and assignments
        for ($i = 1; $i <= 20; $i++) {
            $issue = createIssue($tenantUser->tenant, ['title' => "Issue {$i}"]);
            createAssignment($issue, $spUser->serviceProvider, [
                'scheduled_date' => now()->addDays($i)->toDateString(),
            ]);
        }

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?per_page=5');

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
            ])
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.last_page', 4)
            ->assertJsonPath('meta.per_page', 5)
            ->assertJsonPath('meta.total', 20)
            ->assertJsonCount(5, 'data');

        // Test page 2
        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?per_page=5&page=2');

        $response->assertOk()
            ->assertJsonPath('meta.current_page', 2)
            ->assertJsonCount(5, 'data');
    });

    test('filters by status', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        // Create assignments with different statuses
        $issue1 = createIssue($tenantUser->tenant, ['title' => 'Assigned Issue']);
        $issue2 = createIssue($tenantUser->tenant, ['title' => 'In Progress Issue']);
        $issue3 = createIssue($tenantUser->tenant, ['title' => 'On Hold Issue']);

        createAssignment($issue1, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ASSIGNED,
        ]);
        createAssignment($issue2, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
        ]);
        createAssignment($issue3, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ON_HOLD,
        ]);

        // Filter by assigned status
        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?status=assigned');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status.value', 'assigned');

        // Filter by in_progress status
        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?status=in_progress');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status.value', 'in_progress');

        // Filter by on_hold status
        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?status=on_hold');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status.value', 'on_hold');
    });

    test('filters by date', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $today = now()->toDateString();
        $tomorrow = now()->addDay()->toDateString();

        $issue1 = createIssue($tenantUser->tenant, ['title' => 'Today Issue']);
        $issue2 = createIssue($tenantUser->tenant, ['title' => 'Tomorrow Issue']);

        createAssignment($issue1, $spUser->serviceProvider, [
            'scheduled_date' => $today,
        ]);
        createAssignment($issue2, $spUser->serviceProvider, [
            'scheduled_date' => $tomorrow,
        ]);

        // Filter by today
        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson("/api/v1/assignments?date={$today}");

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.scheduled_date', $today);
    });

    test('filters active only assignments', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue1 = createIssue($tenantUser->tenant, ['title' => 'Active Issue']);
        $issue2 = createIssue($tenantUser->tenant, ['title' => 'Completed Issue']);

        createAssignment($issue1, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
        ]);
        createAssignment($issue2, $spUser->serviceProvider, [
            'status' => AssignmentStatus::COMPLETED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?active_only=true');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status.value', 'in_progress');
    });

    test('filters in_progress only assignments', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue1 = createIssue($tenantUser->tenant);
        $issue2 = createIssue($tenantUser->tenant);
        $issue3 = createIssue($tenantUser->tenant);

        createAssignment($issue1, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ASSIGNED,
        ]);
        createAssignment($issue2, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
        ]);
        createAssignment($issue3, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ON_HOLD,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?in_progress_only=true');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status.value', 'in_progress');
    });

    test('non-service-provider cannot access assignments', function () {
        $tenantUser = createTenantUser();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/assignments');

        $response->assertForbidden()
            ->assertJsonPath('success', false);
    });

    test('unauthenticated request returns 401', function () {
        $response = $this->getJson('/api/v1/assignments');

        $response->assertUnauthorized();
    });
});

/*
|--------------------------------------------------------------------------
| Show Assignment Tests
|--------------------------------------------------------------------------
*/

describe('GET /api/v1/assignments/{id} (Show Assignment)', function () {
    beforeEach(function () {
        Storage::fake('public');
    });

    test('service provider can view their assignment details', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant, [
            'title' => 'Detailed Issue',
            'description' => 'Detailed description',
        ]);

        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'notes' => 'Assignment notes',
            'proof_required' => true,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson("/api/v1/assignments/{$assignment->id}");

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.id', $assignment->id)
            ->assertJsonPath('data.notes', 'Assignment notes')
            ->assertJsonPath('data.proof_required', true)
            ->assertJsonPath('data.issue.title', 'Detailed Issue')
            ->assertJsonPath('data.issue.description', 'Detailed description')
            ->assertJsonStructure([
                'data' => [
                    'id',
                    'status',
                    'issue' => [
                        'id',
                        'title',
                        'description',
                        'status',
                        'priority',
                        'categories',
                        'tenant',
                    ],
                    'category',
                    'scheduled_date',
                    'proof_required',
                    'can_start',
                    'can_hold',
                    'can_resume',
                    'can_finish',
                    'proofs',
                    'consumables',
                ],
            ]);
    });

    test('returns issue info, consumables, and proofs', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::FINISHED,
        ]);

        // Create consumables
        $consumable = Consumable::create([
            'category_id' => $spUser->serviceProvider->category_id,
            'name_en' => 'Pipe',
            'name_ar' => 'انبوب',
            'is_active' => true,
        ]);

        IssueAssignmentConsumable::create([
            'issue_assignment_id' => $assignment->id,
            'consumable_id' => $consumable->id,
            'quantity' => 2,
        ]);

        IssueAssignmentConsumable::create([
            'issue_assignment_id' => $assignment->id,
            'custom_name' => 'Custom Tool',
            'quantity' => 1,
        ]);

        // Create proofs
        Proof::create([
            'issue_assignment_id' => $assignment->id,
            'type' => ProofType::PHOTO,
            'file_path' => 'proofs/test.jpg',
            'stage' => ProofStage::COMPLETION,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson("/api/v1/assignments/{$assignment->id}");

        $response->assertOk()
            ->assertJsonCount(2, 'data.consumables')
            ->assertJsonCount(1, 'data.proofs')
            ->assertJsonPath('data.consumables.0.quantity', 2)
            ->assertJsonPath('data.consumables.1.is_custom', true)
            ->assertJsonPath('data.proofs.0.type.value', 'photo')
            ->assertJsonPath('data.proofs.0.stage.value', 'completion');
    });

    test('cannot view another service provider assignment', function () {
        $sp1User = createServiceProviderUser();
        $sp2User = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $sp1User->serviceProvider);

        // SP2 trying to view SP1's assignment
        $response = $this->withHeaders(authHeaders($sp2User))
            ->getJson("/api/v1/assignments/{$assignment->id}");

        $response->assertNotFound()
            ->assertJsonPath('success', false);
    });

    test('returns 404 for non-existent assignment', function () {
        $spUser = createServiceProviderUser();

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments/99999');

        $response->assertNotFound();
    });
});

/*
|--------------------------------------------------------------------------
| Start Work Tests
|--------------------------------------------------------------------------
*/

describe('POST /api/v1/assignments/{id}/start (Start Work)', function () {
    beforeEach(function () {
        Storage::fake('public');
    });

    test('service provider can start work on assigned task', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant, [
            'status' => IssueStatus::ASSIGNED,
        ]);

        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ASSIGNED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/start");

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status.value', 'in_progress')
            ->assertJsonPath('data.can_start', false)
            ->assertJsonPath('data.can_hold', true)
            ->assertJsonPath('data.can_finish', true);

        // Verify database updates
        $assignment->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::IN_PROGRESS)
            ->and($assignment->started_at)->not->toBeNull();

        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::IN_PROGRESS);
    });

    test('creates timeline entry when starting work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider);

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/start");

        $timelineEntry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::STARTED)
            ->first();

        expect($timelineEntry)->not->toBeNull()
            ->and($timelineEntry->performed_by)->toBe($spUser->id)
            ->and($timelineEntry->issue_id)->toBe($issue->id);
    });

    test('cannot start already started work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/start");

        $response->assertStatus(400)
            ->assertJsonPath('success', false);
    });

    test('cannot start finished work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::FINISHED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/start");

        $response->assertStatus(400);
    });

    test('cannot start another service provider assignment', function () {
        $sp1User = createServiceProviderUser();
        $sp2User = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $sp1User->serviceProvider);

        $response = $this->withHeaders(authHeaders($sp2User))
            ->postJson("/api/v1/assignments/{$assignment->id}/start");

        $response->assertNotFound();
    });
});

/*
|--------------------------------------------------------------------------
| Hold Work Tests
|--------------------------------------------------------------------------
*/

describe('POST /api/v1/assignments/{id}/hold (Hold Work)', function () {
    beforeEach(function () {
        Storage::fake('public');
    });

    test('service provider can hold work that is in progress', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant, [
            'status' => IssueStatus::IN_PROGRESS,
        ]);

        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now()->subHour(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/hold", [
                'reason' => 'Waiting for parts',
            ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status.value', 'on_hold')
            ->assertJsonPath('data.can_resume', true)
            ->assertJsonPath('data.can_hold', false);

        $assignment->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::ON_HOLD)
            ->and($assignment->held_at)->not->toBeNull();

        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::ON_HOLD);
    });

    test('hold reason is saved in timeline', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $holdReason = 'Waiting for customer approval';

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/hold", [
                'reason' => $holdReason,
            ]);

        $timelineEntry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::HELD)
            ->first();

        expect($timelineEntry)->not->toBeNull()
            ->and($timelineEntry->notes)->toBe($holdReason);
    });

    test('hold reason is optional', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/hold");

        $response->assertOk()
            ->assertJsonPath('data.status.value', 'on_hold');
    });

    test('cannot hold work that is not in progress', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        // Try to hold assigned (not started) work
        $issue1 = createIssue($tenantUser->tenant);
        $assignment1 = createAssignment($issue1, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ASSIGNED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment1->id}/hold");

        $response->assertStatus(400)
            ->assertJsonPath('success', false);

        // Try to hold already on_hold work
        $issue2 = createIssue($tenantUser->tenant);
        $assignment2 = createAssignment($issue2, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ON_HOLD,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment2->id}/hold");

        $response->assertStatus(400);
    });

    test('cannot hold finished work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::FINISHED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/hold");

        $response->assertStatus(400);
    });
});

/*
|--------------------------------------------------------------------------
| Resume Work Tests
|--------------------------------------------------------------------------
*/

describe('POST /api/v1/assignments/{id}/resume (Resume Work)', function () {
    beforeEach(function () {
        Storage::fake('public');
    });

    test('service provider can resume held work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant, [
            'status' => IssueStatus::ON_HOLD,
        ]);

        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ON_HOLD,
            'started_at' => now()->subHours(2),
            'held_at' => now()->subHour(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/resume");

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status.value', 'in_progress')
            ->assertJsonPath('data.can_hold', true)
            ->assertJsonPath('data.can_resume', false)
            ->assertJsonPath('data.can_finish', true);

        $assignment->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::IN_PROGRESS)
            ->and($assignment->resumed_at)->not->toBeNull();

        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::IN_PROGRESS);
    });

    test('creates timeline entry when resuming work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ON_HOLD,
            'started_at' => now()->subHours(2),
            'held_at' => now()->subHour(),
        ]);

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/resume");

        $timelineEntry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::RESUMED)
            ->first();

        expect($timelineEntry)->not->toBeNull()
            ->and($timelineEntry->performed_by)->toBe($spUser->id);
    });

    test('cannot resume work that is not on hold', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        // Try to resume assigned work
        $issue1 = createIssue($tenantUser->tenant);
        $assignment1 = createAssignment($issue1, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ASSIGNED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment1->id}/resume");

        $response->assertStatus(400);

        // Try to resume in_progress work
        $issue2 = createIssue($tenantUser->tenant);
        $assignment2 = createAssignment($issue2, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment2->id}/resume");

        $response->assertStatus(400);
    });

    test('cannot resume finished or completed work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue1 = createIssue($tenantUser->tenant);
        $assignment1 = createAssignment($issue1, $spUser->serviceProvider, [
            'status' => AssignmentStatus::FINISHED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment1->id}/resume");

        $response->assertStatus(400);

        $issue2 = createIssue($tenantUser->tenant);
        $assignment2 = createAssignment($issue2, $spUser->serviceProvider, [
            'status' => AssignmentStatus::COMPLETED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment2->id}/resume");

        $response->assertStatus(400);
    });
});

/*
|--------------------------------------------------------------------------
| Finish Work Tests
|--------------------------------------------------------------------------
*/

describe('POST /api/v1/assignments/{id}/finish (Finish Work)', function () {
    beforeEach(function () {
        Storage::fake('public');
    });

    test('service provider can finish work with notes and consumables', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant, [
            'status' => IssueStatus::IN_PROGRESS,
        ]);

        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now()->subHour(),
        ]);

        $consumable = Consumable::create([
            'category_id' => $spUser->serviceProvider->category_id,
            'name_en' => 'Wrench',
            'name_ar' => 'مفتاح ربط',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'notes' => 'Work completed successfully',
                'consumables' => [
                    [
                        'consumable_id' => $consumable->id,
                        'quantity' => 2,
                    ],
                ],
            ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status.value', 'finished')
            ->assertJsonPath('data.notes', 'Work completed successfully')
            ->assertJsonCount(1, 'data.consumables');

        $assignment->refresh();
        expect($assignment->status)->toBe(AssignmentStatus::FINISHED)
            ->and($assignment->finished_at)->not->toBeNull()
            ->and($assignment->notes)->toBe('Work completed successfully');

        $issue->refresh();
        expect($issue->status)->toBe(IssueStatus::FINISHED);
    });

    test('handles custom consumables (others)', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'consumables' => [
                    [
                        'custom_name' => 'Custom Tool XYZ',
                        'quantity' => 1,
                    ],
                    [
                        'custom_name' => 'Special Part',
                        'quantity' => 3,
                    ],
                ],
            ]);

        $response->assertOk()
            ->assertJsonCount(2, 'data.consumables');

        $customConsumables = IssueAssignmentConsumable::where('issue_assignment_id', $assignment->id)
            ->whereNull('consumable_id')
            ->get();

        expect($customConsumables)->toHaveCount(2);
        expect($customConsumables->first()->custom_name)->toBe('Custom Tool XYZ');
    });

    test('can attach proof files (multipart upload)', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $photo = UploadedFile::fake()->image('proof1.jpg', 800, 600);
        $video = UploadedFile::fake()->create('proof2.mp4', 1024, 'video/mp4');

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'notes' => 'With proof files',
                'proofs' => [$photo, $video],
            ]);

        $response->assertOk()
            ->assertJsonCount(2, 'data.proofs');

        $proofs = Proof::where('issue_assignment_id', $assignment->id)->get();
        expect($proofs)->toHaveCount(2);

        $photoProof = $proofs->where('type', ProofType::PHOTO)->first();
        $videoProof = $proofs->where('type', ProofType::VIDEO)->first();

        expect($photoProof)->not->toBeNull()
            ->and($photoProof->stage)->toBe(ProofStage::COMPLETION)
            ->and($videoProof)->not->toBeNull();

        Storage::disk('public')->assertExists($photoProof->file_path);
        Storage::disk('public')->assertExists($videoProof->file_path);
    });

    test('updates status to finished', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish");

        $assignment->refresh();
        $issue->refresh();

        expect($assignment->status)->toBe(AssignmentStatus::FINISHED)
            ->and($issue->status)->toBe(IssueStatus::FINISHED);
    });

    test('creates timeline entry with metadata', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now()->subMinutes(30),
        ]);

        $photo = UploadedFile::fake()->image('proof.jpg');

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'notes' => 'Finished!',
                'proofs' => [$photo],
                'consumables' => [
                    ['custom_name' => 'Tool', 'quantity' => 1],
                ],
            ]);

        $timelineEntry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::FINISHED)
            ->first();

        expect($timelineEntry)->not->toBeNull()
            ->and($timelineEntry->notes)->toBe('Finished!')
            ->and($timelineEntry->metadata)->toBeArray()
            ->and($timelineEntry->metadata['proof_count'])->toBe(1)
            ->and($timelineEntry->metadata['consumable_count'])->toBe(1);
    });

    test('cannot finish work that is not in progress', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        // Try to finish assigned (not started) work
        $issue1 = createIssue($tenantUser->tenant);
        $assignment1 = createAssignment($issue1, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ASSIGNED,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment1->id}/finish");

        $response->assertStatus(400);

        // Try to finish on_hold work
        $issue2 = createIssue($tenantUser->tenant);
        $assignment2 = createAssignment($issue2, $spUser->serviceProvider, [
            'status' => AssignmentStatus::ON_HOLD,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment2->id}/finish");

        $response->assertStatus(400);
    });

    test('cannot finish already finished work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::FINISHED,
            'finished_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish");

        $response->assertStatus(400);
    });

    test('validates required proofs when proof_required is true', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
            'proof_required' => true,
        ]);

        // Try to finish without proofs
        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'notes' => 'Trying without proofs',
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonStructure(['errors' => ['proofs']]);
    });

    test('proof_required assignment can be finished with proofs', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
            'proof_required' => true,
        ]);

        $photo = UploadedFile::fake()->image('required_proof.jpg');

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'proofs' => [$photo],
            ]);

        $response->assertOk()
            ->assertJsonPath('data.status.value', 'finished');
    });

    test('validates consumable data', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        // Try with invalid consumable_id
        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'consumables' => [
                    [
                        'consumable_id' => 99999,
                        'quantity' => 1,
                    ],
                ],
            ]);

        $response->assertStatus(422);
    });

    test('validates proof file types', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        // Try with invalid file type
        $invalidFile = UploadedFile::fake()->create('document.pdf', 1024, 'application/pdf');

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'proofs' => [$invalidFile],
            ]);

        $response->assertStatus(422);
    });
});

/*
|--------------------------------------------------------------------------
| Authorization Tests
|--------------------------------------------------------------------------
*/

describe('Assignment API Authorization', function () {
    test('tenant user cannot access assignment endpoints', function () {
        $tenantUser = createTenantUser();

        $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/assignments')
            ->assertForbidden();

        $this->withHeaders(authHeaders($tenantUser))
            ->getJson('/api/v1/assignments/1')
            ->assertForbidden();

        $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/assignments/1/start')
            ->assertForbidden();

        $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/assignments/1/hold')
            ->assertForbidden();

        $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/assignments/1/resume')
            ->assertForbidden();

        $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/assignments/1/finish')
            ->assertForbidden();
    });

    test('all endpoints require authentication', function () {
        $this->getJson('/api/v1/assignments')
            ->assertUnauthorized();

        $this->getJson('/api/v1/assignments/1')
            ->assertUnauthorized();

        $this->postJson('/api/v1/assignments/1/start')
            ->assertUnauthorized();

        $this->postJson('/api/v1/assignments/1/hold')
            ->assertUnauthorized();

        $this->postJson('/api/v1/assignments/1/resume')
            ->assertUnauthorized();

        $this->postJson('/api/v1/assignments/1/finish')
            ->assertUnauthorized();
    });

    test('service provider cannot access other SP assignments via any endpoint', function () {
        $sp1User = createServiceProviderUser();
        $sp2User = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $sp1User->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        // SP2 trying to access SP1's assignment
        $this->withHeaders(authHeaders($sp2User))
            ->getJson("/api/v1/assignments/{$assignment->id}")
            ->assertNotFound();

        $this->withHeaders(authHeaders($sp2User))
            ->postJson("/api/v1/assignments/{$assignment->id}/start")
            ->assertNotFound();

        $this->withHeaders(authHeaders($sp2User))
            ->postJson("/api/v1/assignments/{$assignment->id}/hold")
            ->assertNotFound();

        // Put SP1's assignment on hold first, then test resume
        $assignment->update([
            'status' => AssignmentStatus::ON_HOLD,
            'held_at' => now(),
        ]);

        $this->withHeaders(authHeaders($sp2User))
            ->postJson("/api/v1/assignments/{$assignment->id}/resume")
            ->assertNotFound();

        // Put back to in_progress for finish test
        $assignment->update([
            'status' => AssignmentStatus::IN_PROGRESS,
        ]);

        $this->withHeaders(authHeaders($sp2User))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish")
            ->assertNotFound();
    });
});

/*
|--------------------------------------------------------------------------
| Edge Cases & Error Handling
|--------------------------------------------------------------------------
*/

describe('Assignment API Edge Cases', function () {
    beforeEach(function () {
        Storage::fake('public');
    });

    test('mixed consumables - standard and custom', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $consumable = Consumable::create([
            'category_id' => $spUser->serviceProvider->category_id,
            'name_en' => 'Standard Part',
            'name_ar' => 'قطعة قياسية',
            'is_active' => true,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'consumables' => [
                    [
                        'consumable_id' => $consumable->id,
                        'quantity' => 2,
                    ],
                    [
                        'custom_name' => 'Custom Part',
                        'quantity' => 1,
                    ],
                ],
            ]);

        $response->assertOk();

        $assignmentConsumables = IssueAssignmentConsumable::where('issue_assignment_id', $assignment->id)->get();
        expect($assignmentConsumables)->toHaveCount(2);

        $standard = $assignmentConsumables->whereNotNull('consumable_id')->first();
        $custom = $assignmentConsumables->whereNull('consumable_id')->first();

        expect($standard->quantity)->toBe(2)
            ->and($custom->custom_name)->toBe('Custom Part')
            ->and($custom->quantity)->toBe(1);
    });

    test('handles multiple proof file types', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $photo = UploadedFile::fake()->image('photo.jpg');
        $video = UploadedFile::fake()->create('video.mp4', 2048, 'video/mp4');
        $audio = UploadedFile::fake()->create('audio.mp3', 512, 'audio/mpeg');

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'proofs' => [$photo, $video, $audio],
            ]);

        $response->assertOk()
            ->assertJsonCount(3, 'data.proofs');

        $proofs = Proof::where('issue_assignment_id', $assignment->id)->get();

        expect($proofs->where('type', ProofType::PHOTO)->count())->toBe(1)
            ->and($proofs->where('type', ProofType::VIDEO)->count())->toBe(1)
            ->and($proofs->where('type', ProofType::AUDIO)->count())->toBe(1);
    });

    test('empty consumables array does not create records', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'consumables' => [],
            ]);

        $response->assertOk();

        $consumablesCount = IssueAssignmentConsumable::where('issue_assignment_id', $assignment->id)->count();
        expect($consumablesCount)->toBe(0);
    });

    test('skips invalid consumable entries without consumable_id or custom_name', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'consumables' => [
                    [
                        'quantity' => 1,
                        // Missing both consumable_id and custom_name
                    ],
                    [
                        'custom_name' => 'Valid Entry',
                        'quantity' => 2,
                    ],
                ],
            ]);

        $response->assertOk();

        $consumablesCount = IssueAssignmentConsumable::where('issue_assignment_id', $assignment->id)->count();
        expect($consumablesCount)->toBe(1);
    });

    test('per_page parameter is capped at 50', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        // Create 60 assignments
        for ($i = 1; $i <= 60; $i++) {
            $issue = createIssue($tenantUser->tenant, ['title' => "Issue {$i}"]);
            createAssignment($issue, $spUser->serviceProvider);
        }

        $response = $this->withHeaders(authHeaders($spUser))
            ->getJson('/api/v1/assignments?per_page=100');

        $response->assertOk()
            ->assertJsonPath('meta.per_page', 50);
    });

    test('duration is calculated correctly when finishing work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $startedAt = now()->subMinutes(45);

        $issue = createIssue($tenantUser->tenant);
        $assignment = createAssignment($issue, $spUser->serviceProvider, [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => $startedAt,
        ]);

        $response = $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish");

        $response->assertOk();

        $assignment->refresh();
        $duration = $assignment->getDurationInMinutes();

        expect($duration)->toBeGreaterThanOrEqual(44)
            ->and($duration)->toBeLessThanOrEqual(46);
    });
});
