<?php

declare(strict_types=1);

use App\Models\Category;
use Tests\Feature\E2E\BaseE2ETest;

/**
 * Category Hierarchy & SP Selection End-to-End Test
 *
 * Tests materialized path category system and ancestor-based SP assignment:
 * 1. Create 4-level category tree
 * 2. Assign SPs to various levels
 * 3. Create issue in leaf category
 * 4. Verify ancestor-based SP pool
 * 5. Assign to SP from parent category
 * 6. Move category, verify SP pool updates
 */
class CategoryAssignmentE2ETest extends BaseE2ETest
{
    public function test_sp_linked_to_parent_category_is_available_for_child(): void
    {
        $admin = createAdminUser('super_admin');
        $tenant = createTenantUser();

        // Create 3-level hierarchy: Root > Parent > Child
        $root = Category::create([
            'name_en' => 'Maintenance',
            'name_ar' => 'صيانة',
            'is_active' => true,
        ]);

        $parent = Category::create([
            'name_en' => 'Electrical',
            'name_ar' => 'كهربائي',
            'is_active' => true,
            'parent_id' => $root->id,
        ]);

        $child = Category::create([
            'name_en' => 'Lighting',
            'name_ar' => 'إضاءة',
            'is_active' => true,
            'parent_id' => $parent->id,
        ]);

        // Refresh to update paths
        $root->refresh();
        $parent->refresh();
        $child->refresh();

        // Create SP linked to parent category
        $sp = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Electrician', 'email' => 'electrician@test.local']
        );

        $sp->serviceProvider->categories()->attach($parent->id);

        // Verify SP's path includes parent
        expect($parent->path)->toContain((string) $parent->id);

        // Create issue in child category
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Broken Light Fixture',
                'description' => 'Light not working in bedroom',
                'priority' => 'medium',
                'category_ids' => [$child->id],
            ]);

        $issueId = $createResponse->json('data.id');

        // Get available SPs for child category
        // Should include SP from parent via ancestor resolution
        $spListResponse = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$child->id}/service-providers");

        $spListResponse->assertStatus(200);

        $spIds = collect($spListResponse->json('data'))->pluck('id')->toArray();
        expect($spIds)->toContain($sp->serviceProvider->id);

        // Admin assigns SP to issue
        $assignResponse = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $child->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
            ]);

        $assignResponse->assertStatus(200);

        $this->assertDatabaseHas('issue_assignments', [
            'issue_id' => $issueId,
            'service_provider_id' => $sp->serviceProvider->id,
            'category_id' => $child->id,
        ]);
    }

    public function test_sp_linked_to_root_is_available_for_all_descendants(): void
    {
        $admin = createAdminUser('super_admin');
        $tenant = createTenantUser();

        // Create 4-level hierarchy
        $root = Category::create([
            'name_en' => 'Building Services',
            'name_ar' => 'خدمات المبنى',
            'is_active' => true,
        ]);

        $level2 = Category::create([
            'name_en' => 'HVAC',
            'name_ar' => 'تكييف',
            'is_active' => true,
            'parent_id' => $root->id,
        ]);

        $level3 = Category::create([
            'name_en' => 'Air Conditioning',
            'name_ar' => 'تكييف هواء',
            'is_active' => true,
            'parent_id' => $level2->id,
        ]);

        $level4 = Category::create([
            'name_en' => 'Central AC',
            'name_ar' => 'مكيف مركزي',
            'is_active' => true,
            'parent_id' => $level3->id,
        ]);

        [$root, $level2, $level3, $level4] = array_map(
            fn ($c) => $c->fresh(),
            [$root, $level2, $level3, $level4]
        );

        // Create SP linked to ROOT
        $sp = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'General Technician', 'email' => 'general@test.local']
        );

        $sp->serviceProvider->categories()->attach($root->id);

        // Create issue in deepest level (level4)
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Central AC Not Cooling',
                'description' => 'Building-wide AC issue',
                'priority' => 'high',
                'category_ids' => [$level4->id],
            ]);

        $issueId = $createResponse->json('data.id');

        // Get SPs for level4 - should include SP from root
        $spListResponse = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$level4->id}/service-providers");

        $spListResponse->assertStatus(200);

        $spIds = collect($spListResponse->json('data'))->pluck('id')->toArray();
        expect($spIds)->toContain($sp->serviceProvider->id);

        // Assign SP to issue
        $assignResponse = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issueId}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $level4->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
            ]);

        $assignResponse->assertStatus(200);
    }

    public function test_multiple_sps_at_different_hierarchy_levels(): void
    {
        $admin = createAdminUser('super_admin');
        $tenant = createTenantUser();

        // Create hierarchy
        $root = Category::create([
            'name_en' => 'Plumbing',
            'name_ar' => 'سباكة',
            'is_active' => true,
        ]);

        $child = Category::create([
            'name_en' => 'Water Heater',
            'name_ar' => 'سخان مياه',
            'is_active' => true,
            'parent_id' => $root->id,
        ]);

        [$root, $child] = array_map(fn ($c) => $c->fresh(), [$root, $child]);

        // SP1 linked to root
        $sp1 = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'General Plumber', 'email' => 'plumber1@test.local']
        );
        $sp1->serviceProvider->categories()->attach($root->id);

        // SP2 linked to child (specialist)
        $sp2 = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Water Heater Specialist', 'email' => 'plumber2@test.local']
        );
        $sp2->serviceProvider->categories()->attach($child->id);

        // Create issue in child category
        $createResponse = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Water Heater Leaking',
                'description' => 'Urgent leak',
                'priority' => 'high',
                'category_ids' => [$child->id],
            ]);

        $issueId = $createResponse->json('data.id');

        // Get SPs for child - should include BOTH (ancestor + direct)
        $spListResponse = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$child->id}/service-providers");

        $spListResponse->assertStatus(200);

        $spIds = collect($spListResponse->json('data'))->pluck('id')->toArray();
        expect($spIds)->toContain($sp1->serviceProvider->id, $sp2->serviceProvider->id);
    }

    public function test_sp_not_available_for_sibling_categories(): void
    {
        $admin = createAdminUser('super_admin');

        // Create siblings
        $parent = Category::create([
            'name_en' => 'Home Services',
            'name_ar' => 'خدمات منزلية',
            'is_active' => true,
        ]);

        $sibling1 = Category::create([
            'name_en' => 'Plumbing',
            'name_ar' => 'سباكة',
            'is_active' => true,
            'parent_id' => $parent->id,
        ]);

        $sibling2 = Category::create([
            'name_en' => 'Electrical',
            'name_ar' => 'كهربائي',
            'is_active' => true,
            'parent_id' => $parent->id,
        ]);

        [$parent, $sibling1, $sibling2] = array_map(
            fn ($c) => $c->fresh(),
            [$parent, $sibling1, $sibling2]
        );

        // SP linked to sibling1 only
        $sp = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Plumber Only', 'email' => 'plumber@test.local']
        );
        $sp->serviceProvider->categories()->attach($sibling1->id);

        // Get SPs for sibling1 - should include SP
        $list1 = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$sibling1->id}/service-providers");

        $ids1 = collect($list1->json('data'))->pluck('id')->toArray();
        expect($ids1)->toContain($sp->serviceProvider->id);

        // Get SPs for sibling2 - should NOT include SP
        $list2 = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$sibling2->id}/service-providers");

        $ids2 = collect($list2->json('data'))->pluck('id')->toArray();
        expect($ids2)->not->toContain($sp->serviceProvider->id);
    }

    public function test_category_move_updates_sp_availability(): void
    {
        $admin = createAdminUser('super_admin');

        // Initial hierarchy
        $root1 = Category::create([
            'name_en' => 'Indoor',
            'name_ar' => 'داخلي',
            'is_active' => true,
        ]);

        $root2 = Category::create([
            'name_en' => 'Outdoor',
            'name_ar' => 'خارجي',
            'is_active' => true,
        ]);

        $child = Category::create([
            'name_en' => 'Plumbing',
            'name_ar' => 'سباكة',
            'is_active' => true,
            'parent_id' => $root1->id,
        ]);

        [$root1, $root2, $child] = array_map(
            fn ($c) => $c->fresh(),
            [$root1, $root2, $child]
        );

        // SP linked to root1
        $sp = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Indoor Specialist', 'email' => 'indoor@test.local']
        );
        $sp->serviceProvider->categories()->attach($root1->id);

        // Verify SP available for child under root1
        $before = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$child->id}/service-providers");

        $beforeIds = collect($before->json('data'))->pluck('id')->toArray();
        expect($beforeIds)->toContain($sp->serviceProvider->id);

        // Move child to root2
        $child->parent_id = $root2->id;
        $child->save();
        $child->refresh();

        // Verify path updated
        expect($child->path)->toContain((string) $root2->id)
            ->and($child->path)->not->toContain((string) $root1->id);

        // SP should NO LONGER be available (no ancestor relationship)
        $after = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$child->id}/service-providers");

        $afterIds = collect($after->json('data'))->pluck('id')->toArray();
        expect($afterIds)->not->toContain($sp->serviceProvider->id);
    }

    public function test_inactive_category_sps_not_returned(): void
    {
        $admin = createAdminUser('super_admin');

        $parent = Category::create([
            'name_en' => 'Test Parent',
            'name_ar' => 'أصل الاختبار',
            'is_active' => true,
        ]);

        $child = Category::create([
            'name_en' => 'Test Child',
            'name_ar' => 'طفل الاختبار',
            'is_active' => true,
            'parent_id' => $parent->id,
        ]);

        [$parent, $child] = array_map(fn ($c) => $c->fresh(), [$parent, $child]);

        // Active SP
        $spActive = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Active SP', 'email' => 'active@test.local']
        );
        $spActive->serviceProvider->categories()->attach($parent->id);

        // Inactive SP
        $spInactive = createServiceProviderUser(
            ['is_available' => false],
            ['name' => 'Inactive SP', 'email' => 'inactive@test.local']
        );
        $spInactive->serviceProvider->categories()->attach($parent->id);

        // Get SPs for child - should only include active
        $listResponse = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$child->id}/service-providers");

        $listResponse->assertStatus(200);

        $spIds = collect($listResponse->json('data'))->pluck('id')->toArray();
        expect($spIds)->toContain($spActive->serviceProvider->id)
            ->and($spIds)->not->toContain($spInactive->serviceProvider->id);
    }

    public function test_sp_with_multiple_category_links(): void
    {
        $admin = createAdminUser('super_admin');
        $tenant = createTenantUser();

        // Create separate category trees
        $cat1 = Category::create([
            'name_en' => 'Plumbing',
            'name_ar' => 'سباكة',
            'is_active' => true,
        ]);

        $cat2 = Category::create([
            'name_en' => 'HVAC',
            'name_ar' => 'تكييف',
            'is_active' => true,
        ]);

        // Multi-skilled SP
        $sp = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Multi-Skilled Technician', 'email' => 'multi@test.local']
        );
        $sp->serviceProvider->categories()->attach([$cat1->id, $cat2->id]);

        // SP should appear in both category lists
        $list1 = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$cat1->id}/service-providers");

        $ids1 = collect($list1->json('data'))->pluck('id')->toArray();
        expect($ids1)->toContain($sp->serviceProvider->id);

        $list2 = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$cat2->id}/service-providers");

        $ids2 = collect($list2->json('data'))->pluck('id')->toArray();
        expect($ids2)->toContain($sp->serviceProvider->id);

        // Can be assigned to issues in either category
        $issue1 = $this->withHeaders(authHeaders($tenant))
            ->postJson('/api/v1/issues', [
                'title' => 'Plumbing Issue',
                'description' => 'Leak',
                'priority' => 'high',
                'category_ids' => [$cat1->id],
            ])->json('data.id');

        $assign1 = $this->withHeaders(authHeaders($admin))
            ->postJson("/api/v1/admin/issues/{$issue1}/assign", [
                'service_provider_id' => $sp->serviceProvider->id,
                'category_id' => $cat1->id,
                'scheduled_date' => now()->addDay()->format('Y-m-d'),
            ]);

        $assign1->assertStatus(200);
    }

    public function test_deep_hierarchy_path_resolution(): void
    {
        $admin = createAdminUser('super_admin');

        // Create 5-level hierarchy
        $level1 = Category::create(['name_en' => 'L1', 'name_ar' => '١', 'is_active' => true]);
        $level2 = Category::create(['name_en' => 'L2', 'name_ar' => '٢', 'is_active' => true, 'parent_id' => $level1->id]);
        $level3 = Category::create(['name_en' => 'L3', 'name_ar' => '٣', 'is_active' => true, 'parent_id' => $level2->id]);
        $level4 = Category::create(['name_en' => 'L4', 'name_ar' => '٤', 'is_active' => true, 'parent_id' => $level3->id]);
        $level5 = Category::create(['name_en' => 'L5', 'name_ar' => '٥', 'is_active' => true, 'parent_id' => $level4->id]);

        [$level1, $level2, $level3, $level4, $level5] = array_map(
            fn ($c) => $c->fresh(),
            [$level1, $level2, $level3, $level4, $level5]
        );

        // Verify path for deepest level contains all ancestors
        $pathIds = $level5->getAncestorIds();
        expect($pathIds)->toContain($level1->id, $level2->id, $level3->id, $level4->id);

        // SP at level 2
        $sp = createServiceProviderUser(['is_available' => true]);
        $sp->serviceProvider->categories()->attach($level2->id);

        // SP should be available for level 3, 4, and 5 (descendants of 2)
        foreach ([$level3, $level4, $level5] as $category) {
            $list = $this->withHeaders(authHeaders($admin))
                ->getJson("/api/v1/admin/categories/{$category->id}/service-providers");

            $spIds = collect($list->json('data'))->pluck('id')->toArray();
            expect($spIds)->toContain($sp->serviceProvider->id);
        }

        // SP should NOT be available for level 1 (parent of SP's category)
        $list1 = $this->withHeaders(authHeaders($admin))
            ->getJson("/api/v1/admin/categories/{$level1->id}/service-providers");

        $ids1 = collect($list1->json('data'))->pluck('id')->toArray();
        expect($ids1)->not->toContain($sp->serviceProvider->id);
    }
}
