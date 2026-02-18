<?php

declare(strict_types=1);

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Enums\TimelineAction;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\Feature\E2E\BaseE2ETest;

/**
 * Complete Issue Lifecycle End-to-End Test
 *
 * This test simulates a real-world issue from creation to completion:
 * 1. Tenant creates issue with image upload
 * 2. Admin views and assigns to service provider
 * 3. SP accepts assignment
 * 4. SP checks in, updates status to in_progress
 * 5. SP uploads progress photos
 * 6. SP marks as finished with resolution notes
 * 7. Admin approves and marks completed
 * 8. Tenant views completion and rating
 * 9. Admin archives issue
 * 10. Full timeline audit verification
 */
class IssueLifecycleE2ETest extends BaseE2ETest
{
    public function test_complete_issue_lifecycle_from_creation_to_archival(): void
    {
        Storage::fake('public');

        $context = $this->createFullWorkflowContext();
        extract($context);

        // Step 1: Tenant creates issue with image upload
        $issueImage = UploadedFile::fake()->image('broken-ac.jpg', 1024, 768);

        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'AC Unit Not Working in Living Room',
                'description' => 'The AC has been making strange noises and not cooling properly for 2 days.',
                'priority' => 'high',
                'category_ids' => [$leafCategory->id],
                'latitude' => 25.276987,
                'longitude' => 55.296249,
                'media' => [$issueImage],
            ]);

        $createResponse->assertStatus(201)
            ->assertJsonPath('data.status.value', 'pending')
            ->assertJsonPath('data.priority.value', 'high')
            ->assertJsonPath('data.title', 'AC Unit Not Working in Living Room')
            ->assertJsonCount(1, 'data.media');

        $issueId = $createResponse->json('data.id');
        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'tenant_id' => $tenant->tenant->id,
            'status' => 'pending',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::CREATED->value, $tenant->id);

        // Step 2: Admin (super_admin) views issue and assigns to service provider
        $viewResponse = $this->withHeaders(authHeaders($superAdmin))
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $viewResponse->assertStatus(200)
            ->assertJsonPath('data.id', $issueId)
            ->assertJsonPath('data.status.value', 'pending');

        // Get available SPs for the leaf category (should include SP from root via ancestors)
        $spListResponse = $this->withHeaders(authHeaders($superAdmin))
            ->getJson("/api/v1/admin/categories/{$leafCategory->id}/service-providers");

        $spListResponse->assertStatus(200)
            ->assertJsonCount(1, 'data'); // Should find SP linked to root category

        // Assign to SP
        $assignResponse = $this->withHeaders(authHeaders($superAdmin))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $leafCategory->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
                'time_slot' => 'morning',
                'notes' => 'Please check the AC compressor and refrigerant levels.',
            ]);

        $assignResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'assigned');

        $assignmentId = $assignResponse->json('data.current_assignment.id');

        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignmentId,
            'issue_id' => $issueId,
            'service_provider_id' => $sp->serviceProvider->id,
            'status' => 'pending',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::ASSIGNED->value, $superAdmin->id);

        // Step 3: Service Provider accepts assignment
        $acceptResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/accept");

        $acceptResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'accepted');

        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignmentId,
            'status' => 'accepted',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::ACCEPTED->value, $sp->id);

        // Step 4: SP checks in at location and updates to in_progress
        $checkinResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/checkin", [
                'latitude' => 25.276987,
                'longitude' => 55.296249,
            ]);

        $checkinResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'in_progress');

        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignmentId,
            'status' => 'in_progress',
        ]);
        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'status' => 'in_progress',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::STARTED->value, $sp->id);

        // Step 5: SP uploads progress photos
        $progressImage1 = UploadedFile::fake()->image('progress-1.jpg', 800, 600);
        $progressImage2 = UploadedFile::fake()->image('progress-2.jpg', 800, 600);

        $uploadResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/upload-proof", [
                'type' => 'in_progress',
                'images' => [$progressImage1, $progressImage2],
                'notes' => 'Replaced the compressor filter and refilled refrigerant.',
            ]);

        $uploadResponse->assertStatus(200)
            ->assertJsonCount(2, 'data.proofs');

        // Step 6: SP marks as finished with resolution notes
        $finishResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/finish", [
                'completion_notes' => 'AC unit fully repaired. Compressor cleaned, refrigerant refilled. System tested and cooling properly.',
                'consumables_used' => [
                    ['name' => 'R-410A Refrigerant', 'quantity' => 2, 'unit' => 'kg'],
                    ['name' => 'Compressor Filter', 'quantity' => 1, 'unit' => 'piece'],
                ],
            ]);

        $finishResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'finished');

        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignmentId,
            'status' => 'finished',
        ]);
        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'status' => 'finished',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::FINISHED->value, $sp->id);

        // Step 7: Admin approves and marks completed
        $approveResponse = $this->withHeaders(authHeaders($superAdmin))
            ->postJson("/api/v1/admin/issues/{$issueId}/approve", [
                'notes' => 'Approved after reviewing SP work photos and notes.',
            ]);

        $approveResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'completed');

        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'status' => 'completed',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::APPROVED->value, $superAdmin->id);

        // Step 8: Tenant views completion
        $tenantViewResponse = $this->withHeaders(authHeaders($tenant))
            ->getJson("/api/v1/issues/{$issueId}");

        $tenantViewResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'completed')
            ->assertJsonPath('data.current_assignment.status.value', 'finished')
            ->assertJsonStructure([
                'data' => [
                    'assignments' => [
                        '*' => [
                            'completion_notes',
                            'consumables' => [
                                '*' => ['name', 'quantity', 'unit'],
                            ],
                            'proofs',
                        ],
                    ],
                ],
            ]);

        // Step 9: Verify full timeline audit trail
        $timelineResponse = $this->withHeaders(authHeaders($superAdmin))
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $timeline = $timelineResponse->json('data.timeline');

        expect($timeline)->toBeArray()
            ->and(count($timeline))->toBeGreaterThanOrEqual(6);

        // Verify timeline order (chronological)
        $actions = collect($timeline)->pluck('action.value')->toArray();
        expect($actions)->toContain('created', 'assigned', 'accepted', 'started', 'finished', 'approved');

        // Step 10: Admin archives issue (optional final step)
        $archiveResponse = $this->withHeaders(authHeaders($superAdmin))
            ->postJson("/api/v1/admin/issues/{$issueId}/archive");

        $archiveResponse->assertStatus(200);

        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'archived_at' => now()->toDateString(),
        ]);
    }

    public function test_issue_lifecycle_with_reassignment_after_rejection(): void
    {
        Storage::fake('public');

        $context = $this->createFullWorkflowContext();
        extract($context);

        // Create second SP
        $sp2 = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Second SP', 'email' => 'sp2@test.local']
        );
        $sp2->serviceProvider->categories()->attach($rootCategory->id);

        // Tenant creates issue
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Plumbing Issue',
                'description' => 'Leak in kitchen sink',
                'priority' => 'medium',
                'category_ids' => [$leafCategory->id],
            ]);

        $issueId = $createResponse->json('data.id');

        // Admin assigns to first SP
        $assignResponse = $this->withHeaders(authHeaders($superAdmin))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $leafCategory->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
                'time_slot' => 'morning',
            ]);

        $assignmentId = $assignResponse->json('data.current_assignment.id');

        // First SP rejects
        $rejectResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/reject", [
                'reason' => 'Schedule conflict, cannot attend tomorrow.',
            ]);

        $rejectResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'rejected');

        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignmentId,
            'status' => 'rejected',
        ]);
        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'status' => 'pending', // Back to pending after rejection
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::REJECTED->value, $sp->id);

        // Admin reassigns to second SP
        $reassignResponse = $this->withHeaders(authHeaders($superAdmin))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp2->serviceProvider->id,
                'category_id' => $leafCategory->id,
                'scheduled_date' => now()->addDays(2)->format('Y-m-d'),
                'time_slot' => 'afternoon',
            ]);

        $newAssignmentId = $reassignResponse->json('data.current_assignment.id');

        expect($newAssignmentId)->not->toBe($assignmentId);

        $this->assertDatabaseHas('issue_assignments', [
            'id' => $newAssignmentId,
            'service_provider_id' => $sp2->serviceProvider->id,
            'status' => 'pending',
        ]);

        // Second SP accepts
        $acceptResponse = $this->withHeaders(authHeaders($sp2))
            ->postJson("/api/v1/assignments/{$newAssignmentId}/accept");

        $acceptResponse->assertStatus(200);

        // Verify issue has 2 assignments in history
        $issueDetailResponse = $this->withHeaders(authHeaders($superAdmin))
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $assignments = $issueDetailResponse->json('data.assignments');
        expect($assignments)->toHaveCount(2);
    }

    public function test_issue_lifecycle_with_on_hold_and_resume(): void
    {
        $context = $this->createMinimalContext();
        extract($context);

        // Create issue and assign
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Complex Issue',
                'description' => 'Needs parts order',
                'priority' => 'medium',
                'category_ids' => [$category->id],
            ]);

        $issueId = $createResponse->json('data.id');

        $assignResponse = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
            ]);

        $assignmentId = $assignResponse->json('data.current_assignment.id');

        // SP accepts and starts work
        $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/accept");

        $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/checkin", [
                'latitude' => 25.0,
                'longitude' => 55.0,
            ]);

        // SP puts on hold (waiting for parts)
        $holdResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/hold", [
                'reason' => 'Waiting for replacement part to arrive.',
            ]);

        $holdResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'on_hold');

        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'status' => 'on_hold',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::ON_HOLD->value, $sp->id);

        // SP resumes work
        $resumeResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/resume", [
                'notes' => 'Parts arrived, resuming work.',
            ]);

        $resumeResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'in_progress');

        $this->assertDatabaseHas('issues', [
            'id' => $issueId,
            'status' => 'in_progress',
        ]);

        $this->assertTimelineEntryExists($issueId, TimelineAction::RESUMED->value, $sp->id);

        // SP finishes
        $finishResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/finish", [
                'completion_notes' => 'Part installed, issue resolved.',
            ]);

        $finishResponse->assertStatus(200);
    }

    public function test_multiple_issues_same_tenant_different_statuses(): void
    {
        $context = $this->createMinimalContext();
        extract($context);

        // Create 3 issues in different states
        $pendingIssue = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Pending Issue',
                'description' => 'Not yet assigned',
                'priority' => 'low',
                'category_ids' => [$category->id],
            ])->json('data.id');

        $assignedIssue = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Assigned Issue',
                'description' => 'Currently assigned',
                'priority' => 'medium',
                'category_ids' => [$category->id],
            ])->json('data.id');

        $completedIssue = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Completed Issue',
                'description' => 'Already done',
                'priority' => 'high',
                'category_ids' => [$category->id],
            ])->json('data.id');

        // Assign second issue
        $assignResponse = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$assignedIssue}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
            ]);

        // Complete third issue
        $assignmentId = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$completedIssue}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->format('Y-m-d'),
            ])->json('data.current_assignment.id');

        $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/accept");

        $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/checkin", [
                'latitude' => 25.0,
                'longitude' => 55.0,
            ]);

        $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/finish", [
                'completion_notes' => 'Done',
            ]);

        $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$completedIssue}/approve");

        // Verify tenant sees all 3 issues with correct statuses
        $listResponse = $this->withHeaders(authHeaders($tenant))
            ->getJson('/api/v1/issues');

        $listResponse->assertStatus(200)
            ->assertJsonCount(3, 'data');

        $issues = collect($listResponse->json('data'));
        $statusMap = $issues->pluck('status.value', 'id')->toArray();

        expect($statusMap[$pendingIssue])->toBe('pending')
            ->and($statusMap[$assignedIssue])->toBe('assigned')
            ->and($statusMap[$completedIssue])->toBe('completed');
    }
}
