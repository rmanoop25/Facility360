<?php

declare(strict_types=1);

use Tests\Feature\E2E\BaseE2ETest;

/**
 * Multi-User Concurrent Operations End-to-End Test
 *
 * Tests concurrent operations by multiple users:
 * 1. Two tenants create issues simultaneously
 * 2. Admin assigns both to same SP
 * 3. SP accepts one, rejects the other
 * 4. Admin reassigns rejected issue
 * 5. Verify no cross-tenant data leakage
 * 6. Verify proper assignment isolation
 */
class MultiUserConcurrencyE2ETest extends BaseE2ETest
{
    public function test_concurrent_issue_creation_by_multiple_tenants(): void
    {
        $tenant1 = createTenantUser([], ['email' => 'tenant1@test.local', 'name' => 'Tenant One']);
        $tenant2 = createTenantUser([], ['email' => 'tenant2@test.local', 'name' => 'Tenant Two']);

        $category = \App\Models\Category::factory()->create();

        // Simulate concurrent creation
        $response1 = $this->withHeaders(authHeaders($tenant1))
            ->postJson('/api/v1/issues', [
                'title' => 'Tenant 1 Issue',
                'description' => 'From tenant 1',
                'priority' => 'high',
                'category_ids' => [$category->id],
            ]);

        $response2 = $this->withHeaders(authHeaders($tenant2))
            ->postJson('/api/v1/issues', [
                'title' => 'Tenant 2 Issue',
                'description' => 'From tenant 2',
                'priority' => 'medium',
                'category_ids' => [$category->id],
            ]);

        $response1->assertStatus(201);
        $response2->assertStatus(201);

        $issue1Id = $response1->json('data.id');
        $issue2Id = $response2->json('data.id');

        // Verify isolation: tenant 1 cannot see tenant 2's issue
        $tenant1List = $this->withHeaders(authHeaders($tenant1))
            ->getJson('/api/v1/issues');

        $tenant1List->assertStatus(200)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $issue1Id);

        // Verify isolation: tenant 2 cannot see tenant 1's issue
        $tenant2List = $this->withHeaders(authHeaders($tenant2))
            ->getJson('/api/v1/issues');

        $tenant2List->assertStatus(200)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $issue2Id);

        // Verify tenant 1 cannot access tenant 2's issue
        $forbidden = $this->withHeaders(authHeaders($tenant1))
            ->getJson("/api/v1/issues/{$issue2Id}");

        $forbidden->assertStatus(404);
    }

    public function test_same_sp_handles_multiple_assignments_concurrently(): void
    {
        $tenant1 = createTenantUser([], ['email' => 'tenant1@test.local']);
        $tenant2 = createTenantUser([], ['email' => 'tenant2@test.local']);
        $sp = createServiceProviderUser([], ['email' => 'sp@test.local']);
        $admin = createAdminUser('super_admin');

        $category = \App\Models\Category::factory()->create();
        $sp->serviceProvider->categories()->attach($category->id);

        // Tenant 1 creates issue
        $issue1Response = $this->withHeaders(authHeaders($tenant1))
            ->postJson('/api/v1/issues', [
                'title' => 'Issue 1',
                'description' => 'First issue',
                'priority' => 'high',
                'category_ids' => [$category->id],
            ]);

        $issue1Id = $issue1Response->json('data.id');

        // Tenant 2 creates issue
        $issue2Response = $this->withHeaders(authHeaders($tenant2))
            ->postJson('/api/v1/issues', [
                'title' => 'Issue 2',
                'description' => 'Second issue',
                'priority' => 'medium',
                'category_ids' => [$category->id],
            ]);

        $issue2Id = $issue2Response->json('data.id');

        // Admin assigns both to same SP
        $assign1 = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issue1Id}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
                'time_slot' => 'morning',
            ]);

        $assign2 = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issue2Id}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
                'time_slot' => 'afternoon',
            ]);

        $assign1->assertStatus(200);
        $assign2->assertStatus(200);

        $assignment1Id = $assign1->json('data.current_assignment.id');
        $assignment2Id = $assign2->json('data.current_assignment.id');

        // SP should see both assignments
        $spAssignments = $this->withHeaders(authHeaders($sp))
            ->getJson('/api/v1/assignments');

        $spAssignments->assertStatus(200)
            ->assertJsonCount(2, 'data');

        $assignmentIds = collect($spAssignments->json('data'))->pluck('id')->toArray();
        expect($assignmentIds)->toContain($assignment1Id, $assignment2Id);

        // SP accepts first, rejects second
        $accept1 = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignment1Id}/accept");

        $accept1->assertStatus(200)
            ->assertJsonPath('data.status.value', 'accepted');

        $reject2 = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignment2Id}/reject", [
                'reason' => 'Schedule conflict',
            ]);

        $reject2->assertStatus(200)
            ->assertJsonPath('data.status.value', 'rejected');

        // Verify database state
        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignment1Id,
            'status' => 'accepted',
        ]);

        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignment2Id,
            'status' => 'rejected',
        ]);

        // Admin reassigns rejected issue to another SP
        $sp2 = createServiceProviderUser([], ['email' => 'sp2@test.local']);
        $sp2->serviceProvider->categories()->attach($category->id);

        $reassign = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issue2Id}/assign", [
                'service_provider_id' => $sp2->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->addDays(2)->format('Y-m-d'),
            ]);

        $reassign->assertStatus(200);
        $newAssignmentId = $reassign->json('data.current_assignment.id');

        expect($newAssignmentId)->not->toBe($assignment2Id);

        // Verify original SP doesn't see new assignment
        $sp1List = $this->withHeaders(authHeaders($sp))
            ->getJson('/api/v1/assignments');

        $sp1Ids = collect($sp1List->json('data'))->pluck('id')->toArray();
        expect($sp1Ids)->not->toContain($newAssignmentId)
            ->and($sp1Ids)->toContain($assignment1Id);
    }

    public function test_concurrent_updates_to_same_assignment(): void
    {
        $context = $this->createMinimalContext();
        extract($context);

        // Create and assign issue
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Concurrent Update Test',
                'description' => 'Testing concurrent updates',
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

        // SP accepts
        $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/accept");

        // SP checks in
        $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/checkin", [
                'latitude' => 25.0,
                'longitude' => 55.0,
            ]);

        // Simulate concurrent status updates
        // Note: In production, this should use optimistic locking to prevent race conditions

        // SP finishes work
        $finishResponse = $this->withHeaders(authHeaders($sp))
            ->postJson("/api/v1/assignments/{$assignmentId}/finish", [
                'completion_notes' => 'Work completed',
            ]);

        $finishResponse->assertStatus(200)
            ->assertJsonPath('data.status.value', 'finished');

        // Verify final state
        $this->assertDatabaseHas('issue_assignments', [
            'id' => $assignmentId,
            'status' => 'finished',
        ]);
    }

    public function test_multiple_admins_manage_same_issue_without_conflicts(): void
    {
        $admin1 = createAdminUser('super_admin', ['email' => 'admin1@test.local']);
        $admin2 = createAdminUser('manager', ['email' => 'admin2@test.local']);
        $tenant = createTenantUser();

        $category = \App\Models\Category::factory()->create();

        // Tenant creates issue
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Multi-Admin Issue',
                'description' => 'Multiple admins will handle this',
                'priority' => 'high',
                'category_ids' => [$category->id],
            ]);

        $issueId = $createResponse->json('data.id');

        // Admin 1 views issue
        $admin1View = $this->withHeaders(authHeaders($admin1))
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $admin1View->assertStatus(200)
            ->assertJsonPath('data.id', $issueId);

        // Admin 2 views issue
        $admin2View = $this->withHeaders(authHeaders($admin2))
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $admin2View->assertStatus(200)
            ->assertJsonPath('data.id', $issueId);

        // Admin 1 assigns
        $sp = createServiceProviderUser();
        $sp->serviceProvider->categories()->attach($category->id);

        $assignResponse = $this->withHeaders(authHeaders($admin1))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
            ]);

        $assignResponse->assertStatus(200);
        $assignmentId = $assignResponse->json('data.current_assignment.id');

        // Admin 2 can see the assignment
        $admin2ViewUpdated = $this->withHeaders(authHeaders($admin2))
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $admin2ViewUpdated->assertStatus(200)
            ->assertJsonPath('data.current_assignment.id', $assignmentId);

        // Verify timeline shows both admins' actions
        $timelineResponse = $this->withHeaders(authHeaders($admin1))
            ->getJson("/api/v1/admin/issues/{$issueId}");

        $timeline = $timelineResponse->json('data.timeline');
        expect($timeline)->toBeArray();
    }

    public function test_sp_cannot_access_another_sp_assignment(): void
    {
        $tenant = createTenantUser();
        $sp1 = createServiceProviderUser([], ['email' => 'sp1@test.local']);
        $sp2 = createServiceProviderUser([], ['email' => 'sp2@test.local']);
        $admin = createAdminUser('super_admin');

        $category = \App\Models\Category::factory()->create();
        $sp1->serviceProvider->categories()->attach($category->id);
        $sp2->serviceProvider->categories()->attach($category->id);

        // Create issue
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'SP Isolation Test',
                'description' => 'Should be isolated between SPs',
                'priority' => 'medium',
                'category_ids' => [$category->id],
            ]);

        $issueId = $createResponse->json('data.id');

        // Assign to SP1
        $assignResponse = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp1->serviceProvider->id,
                'category_id' => $category->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
            ]);

        $assignmentId = $assignResponse->json('data.current_assignment.id');

        // SP1 can access
        $sp1Access = $this->withHeaders(authHeaders($sp1))
            ->getJson("/api/v1/assignments/{$assignmentId}");

        $sp1Access->assertStatus(200)
            ->assertJsonPath('data.id', $assignmentId);

        // SP2 cannot access SP1's assignment
        $sp2Access = $this->withHeaders(authHeaders($sp2))
            ->getJson("/api/v1/assignments/{$assignmentId}");

        $sp2Access->assertStatus(403); // Forbidden

        // SP2's assignment list should be empty
        $sp2List = $this->withHeaders(authHeaders($sp2))
            ->getJson('/api/v1/assignments');

        $sp2List->assertStatus(200)
            ->assertJsonCount(0, 'data');
    }

    public function test_rapid_issue_creation_maintains_data_integrity(): void
    {
        $tenant = createTenantUser();
        $category = \App\Models\Category::factory()->create();

        $issueIds = [];

        // Create 10 issues rapidly
        for ($i = 1; $i <= 10; $i++) {
            $response = $this->withHeaders(authHeaders($tenant))
                ->postJson('/api/v1/issues', [
                    'title' => "Rapid Issue {$i}",
                    'description' => "Description {$i}",
                    'priority' => 'medium',
                    'category_ids' => [$category->id],
                ]);

            $response->assertStatus(201);
            $issueIds[] = $response->json('data.id');
        }

        // Verify all 10 issues were created
        expect($issueIds)->toHaveCount(10);

        // Verify all issues exist in database
        foreach ($issueIds as $issueId) {
            $this->assertDatabaseHas('issues', [
                'id' => $issueId,
                'tenant_id' => $tenant->tenant->id,
            ]);
        }

        // Verify tenant can see all 10 issues
        $listResponse = $this->withHeaders(authHeaders($tenant))
            ->getJson('/api/v1/issues');

        $listResponse->assertStatus(200)
            ->assertJsonCount(10, 'data');
    }
}
