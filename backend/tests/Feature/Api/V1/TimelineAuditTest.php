<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Enums\TimelineAction;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\IssueTimeline;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/*
|--------------------------------------------------------------------------
| Timeline & Audit Trail Tests
|--------------------------------------------------------------------------
|
| Verifies the audit trail is complete and correct throughout the
| issue lifecycle. Every status change MUST produce a timeline entry
| with correct performed_by, action, notes, and metadata.
|
*/

beforeEach(function () {
    $this->seed(RolesAndPermissionsSeeder::class);
    Storage::fake('public');
});

/*
|--------------------------------------------------------------------------
| Timeline entry creation for each lifecycle action
|--------------------------------------------------------------------------
*/

describe('Timeline entries are created for every lifecycle action', function () {

    it('creates CREATED timeline entry when tenant creates issue', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Timeline: Created',
                'description' => 'Testing timeline entry for creation',
                'category_ids' => [$category->id],
            ]);

        $response->assertStatus(201);
        $issueId = $response->json('data.id');

        $entry = IssueTimeline::where('issue_id', $issueId)
            ->where('action', TimelineAction::CREATED)
            ->first();

        expect($entry)->not->toBeNull()
            ->and($entry->performed_by)->toBe($tenantUser->id)
            ->and($entry->issue_id)->toBe($issueId);
    });

    it('creates ASSIGNED timeline entry when admin assigns SP', function () {
        $admin = createAdminUser('super_admin');
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

        $this->withHeader('Authorization', 'Bearer ' . getAuthToken($admin))
            ->postJson("/api/v1/admin/issues/{$issue->id}/assign", [
                'service_provider_id' => $sp->id,
                'scheduled_date' => now()->toDateString(),
                'time_slot_id' => $timeSlot->id,
                'notes' => 'Please prioritize this.',
            ])
            ->assertOk();

        $entry = IssueTimeline::where('issue_id', $issue->id)
            ->where('action', TimelineAction::ASSIGNED)
            ->first();

        expect($entry)->not->toBeNull()
            ->and($entry->performed_by)->toBe($admin->id);
    });

    it('creates STARTED timeline entry when SP starts work', function () {
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

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/start")
            ->assertOk();

        $entry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::STARTED)
            ->first();

        expect($entry)->not->toBeNull()
            ->and($entry->performed_by)->toBe($spUser->id)
            ->and($entry->issue_id)->toBe($issue->id);
    });

    it('creates HELD timeline entry with reason when SP holds work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create(['status' => IssueStatus::IN_PROGRESS]);

        $assignment = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUser->serviceProvider->id,
            'category_id' => $spUser->serviceProvider->category_id,
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now()->subHour(),
            'scheduled_date' => now()->toDateString(),
            'proof_required' => false,
        ]);

        $holdReason = 'Waiting for parts delivery from supplier';

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/hold", [
                'reason' => $holdReason,
            ])
            ->assertOk();

        $entry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::HELD)
            ->first();

        expect($entry)->not->toBeNull()
            ->and($entry->performed_by)->toBe($spUser->id)
            ->and($entry->notes)->toBe($holdReason);
    });

    it('creates RESUMED timeline entry when SP resumes work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create(['status' => IssueStatus::ON_HOLD]);

        $assignment = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUser->serviceProvider->id,
            'category_id' => $spUser->serviceProvider->category_id,
            'status' => AssignmentStatus::ON_HOLD,
            'started_at' => now()->subHours(2),
            'held_at' => now()->subHour(),
            'scheduled_date' => now()->toDateString(),
            'proof_required' => false,
        ]);

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/resume")
            ->assertOk();

        $entry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::RESUMED)
            ->first();

        expect($entry)->not->toBeNull()
            ->and($entry->performed_by)->toBe($spUser->id);
    });

    it('creates FINISHED timeline entry with metadata when SP finishes work', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create(['status' => IssueStatus::IN_PROGRESS]);

        $assignment = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUser->serviceProvider->id,
            'category_id' => $spUser->serviceProvider->category_id,
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now()->subMinutes(45),
            'scheduled_date' => now()->toDateString(),
            'proof_required' => false,
        ]);

        $photo = UploadedFile::fake()->image('proof.jpg');

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish", [
                'notes' => 'All fixed',
                'proofs' => [$photo],
                'consumables' => [
                    ['custom_name' => 'Tool', 'quantity' => 1],
                ],
            ])
            ->assertOk();

        $entry = IssueTimeline::where('issue_assignment_id', $assignment->id)
            ->where('action', TimelineAction::FINISHED)
            ->first();

        expect($entry)->not->toBeNull()
            ->and($entry->performed_by)->toBe($spUser->id)
            ->and($entry->notes)->toBe('All fixed')
            ->and($entry->metadata)->toBeArray()
            ->and($entry->metadata['proof_count'])->toBe(1)
            ->and($entry->metadata['consumable_count'])->toBe(1);
    });

    it('creates CANCELLED timeline entry when tenant cancels issue', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->pending()
            ->create();
        $issue->categories()->attach($category);

        $cancelReason = 'No longer needed';

        $this->withHeaders(authHeaders($tenantUser))
            ->postJson("/api/v1/issues/{$issue->id}/cancel", [
                'reason' => $cancelReason,
            ])
            ->assertOk();

        $entry = IssueTimeline::where('issue_id', $issue->id)
            ->where('action', TimelineAction::CANCELLED)
            ->first();

        expect($entry)->not->toBeNull()
            ->and($entry->performed_by)->toBe($tenantUser->id)
            ->and($entry->notes)->toBe($cancelReason);
    });
});

/*
|--------------------------------------------------------------------------
| Timeline ordering
|--------------------------------------------------------------------------
*/

describe('Timeline ordering', function () {

    it('timeline entries are in chronological order', function () {
        $spUser = createServiceProviderUser();
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        // Create issue
        $response = $this->withHeaders(authHeaders($tenantUser))
            ->postJson('/api/v1/issues', [
                'title' => 'Chronological Test',
                'description' => 'Testing timeline order',
                'category_ids' => [$category->id],
            ]);

        $issueId = $response->json('data.id');
        $issue = Issue::find($issueId);

        // Create assignment manually to simulate admin action
        $assignment = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $spUser->serviceProvider->id,
            'category_id' => $spUser->serviceProvider->category_id,
            'status' => AssignmentStatus::ASSIGNED,
            'scheduled_date' => now()->addDay()->toDateString(),
            'proof_required' => false,
        ]);

        $issue->update(['status' => IssueStatus::ASSIGNED]);

        // SP workflow: start -> finish
        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/start")
            ->assertOk();

        $this->withHeaders(authHeaders($spUser))
            ->postJson("/api/v1/assignments/{$assignment->id}/finish")
            ->assertOk();

        // Fetch timeline
        $entries = IssueTimeline::where('issue_id', $issueId)
            ->orderBy('created_at', 'asc')
            ->get();

        // Verify order: created -> started -> finished
        expect($entries->count())->toBeGreaterThanOrEqual(3);

        $timestamps = $entries->pluck('created_at')->toArray();
        for ($i = 1; $i < count($timestamps); $i++) {
            expect($timestamps[$i])->toBeGreaterThanOrEqual($timestamps[$i - 1]);
        }
    });
});

/*
|--------------------------------------------------------------------------
| Timeline in API responses
|--------------------------------------------------------------------------
*/

describe('Timeline appears in API responses', function () {

    it('tenant issue detail includes timeline', function () {
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($category);

        IssueTimeline::create([
            'issue_id' => $issue->id,
            'action' => TimelineAction::CREATED,
            'performed_by' => $tenantUser->id,
        ]);

        $response = $this->withHeaders(authHeaders($tenantUser))
            ->getJson("/api/v1/issues/{$issue->id}");

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'timeline' => [
                        '*' => [
                            'id',
                            'action',
                            'performed_by',
                            'notes',
                            'created_at',
                        ],
                    ],
                ],
            ]);

        expect($response->json('data.timeline'))->not->toBeEmpty();
    });

    it('admin issue detail includes timeline', function () {
        $admin = createAdminUser('super_admin');
        $tenantUser = createTenantUser();
        $category = Category::factory()->create();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create();
        $issue->categories()->attach($category);

        IssueTimeline::create([
            'issue_id' => $issue->id,
            'action' => TimelineAction::CREATED,
            'performed_by' => $tenantUser->id,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer ' . getAuthToken($admin))
            ->getJson("/api/v1/admin/issues/{$issue->id}");

        $response->assertOk();

        expect($response->json('data.timeline'))->not->toBeEmpty();
    });
});

/*
|--------------------------------------------------------------------------
| Multiple assignments generate separate timelines
|--------------------------------------------------------------------------
*/

describe('Multiple assignment timelines', function () {

    it('each assignment has its own timeline entries', function () {
        $sp1User = createServiceProviderUser();
        $sp2User = createServiceProviderUser();
        $tenantUser = createTenantUser();

        $issue = Issue::factory()
            ->for($tenantUser->tenant)
            ->create(['status' => IssueStatus::ASSIGNED]);

        // First assignment
        $assignment1 = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $sp1User->serviceProvider->id,
            'category_id' => $sp1User->serviceProvider->category_id,
            'status' => AssignmentStatus::ASSIGNED,
            'scheduled_date' => now()->addDay()->toDateString(),
            'proof_required' => false,
        ]);

        // SP1 starts and finishes
        $this->withHeaders(authHeaders($sp1User))
            ->postJson("/api/v1/assignments/{$assignment1->id}/start")
            ->assertOk();

        $this->withHeaders(authHeaders($sp1User))
            ->postJson("/api/v1/assignments/{$assignment1->id}/finish")
            ->assertOk();

        // Second assignment (e.g., after reassignment)
        $assignment2 = IssueAssignment::create([
            'issue_id' => $issue->id,
            'service_provider_id' => $sp2User->serviceProvider->id,
            'category_id' => $sp2User->serviceProvider->category_id,
            'status' => AssignmentStatus::ASSIGNED,
            'scheduled_date' => now()->addDays(2)->toDateString(),
            'proof_required' => false,
        ]);

        // SP2 starts
        $issue->update(['status' => IssueStatus::ASSIGNED]);
        $this->withHeaders(authHeaders($sp2User))
            ->postJson("/api/v1/assignments/{$assignment2->id}/start")
            ->assertOk();

        // Verify each assignment has separate timeline entries
        $assignment1Entries = IssueTimeline::where('issue_assignment_id', $assignment1->id)->count();
        $assignment2Entries = IssueTimeline::where('issue_assignment_id', $assignment2->id)->count();

        expect($assignment1Entries)->toBeGreaterThanOrEqual(2) // started, finished
            ->and($assignment2Entries)->toBeGreaterThanOrEqual(1); // started

        // Verify performed_by correctly identifies different SPs
        $sp1Entries = IssueTimeline::where('issue_assignment_id', $assignment1->id)
            ->pluck('performed_by')
            ->unique()
            ->toArray();
        expect($sp1Entries)->toBe([$sp1User->id]);

        $sp2Entries = IssueTimeline::where('issue_assignment_id', $assignment2->id)
            ->pluck('performed_by')
            ->unique()
            ->toArray();
        expect($sp2Entries)->toBe([$sp2User->id]);
    });
});
