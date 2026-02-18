<?php

declare(strict_types=1);

namespace Tests\Feature\E2E;

use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Base class for End-to-End tests that simulate complete workflows.
 *
 * E2E tests use real HTTP requests and verify full integration from
 * API endpoint to database, including authentication, authorization,
 * events, queues, and side effects.
 */
abstract class BaseE2ETest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolesAndPermissionsSeeder::class);
    }

    /**
     * Create a complete workflow context with all necessary users and data.
     *
     * @return array{
     *     superAdmin: User,
     *     manager: User,
     *     viewer: User,
     *     tenant: User,
     *     sp: User,
     *     rootCategory: Category,
     *     subCategory: Category,
     *     leafCategory: Category
     * }
     */
    protected function createFullWorkflowContext(): array
    {
        $superAdmin = createAdminUser('super_admin', [
            'name' => 'Super Admin User',
            'email' => 'super@test.local',
        ]);

        $manager = createAdminUser('manager', [
            'name' => 'Manager User',
            'email' => 'manager@test.local',
        ]);

        $viewer = createAdminUser('viewer', [
            'name' => 'Viewer User',
            'email' => 'viewer@test.local',
        ]);

        $tenant = createTenantUser(
            ['unit_number' => 'A-101', 'building_name' => 'Building A'],
            ['name' => 'Tenant User', 'email' => 'tenant@test.local']
        );

        // Create 3-level category hierarchy
        $rootCategory = Category::create([
            'name_en' => 'Maintenance',
            'name_ar' => 'صيانة',
            'is_active' => true,
            'parent_id' => null,
        ]);

        $subCategory = Category::create([
            'name_en' => 'Plumbing',
            'name_ar' => 'سباكة',
            'is_active' => true,
            'parent_id' => $rootCategory->id,
        ]);

        $leafCategory = Category::create([
            'name_en' => 'Water Heater',
            'name_ar' => 'سخان مياه',
            'is_active' => true,
            'parent_id' => $subCategory->id,
        ]);

        // Refresh paths
        $rootCategory->refresh();
        $subCategory->refresh();
        $leafCategory->refresh();

        // Create service provider linked to root category (should be available for all descendants)
        $sp = createServiceProviderUser(
            ['is_available' => true],
            ['name' => 'Service Provider User', 'email' => 'sp@test.local']
        );

        // Attach SP to root category via pivot (using new materialized path system)
        $sp->serviceProvider->categories()->attach($rootCategory->id);

        return compact(
            'superAdmin',
            'manager',
            'viewer',
            'tenant',
            'sp',
            'rootCategory',
            'subCategory',
            'leafCategory'
        );
    }

    /**
     * Create a minimal workflow context for simpler tests.
     */
    protected function createMinimalContext(): array
    {
        $tenant = createTenantUser();
        $sp = createServiceProviderUser();
        $admin = createAdminUser('super_admin');

        $category = Category::create([
            'name_en' => 'General',
            'name_ar' => 'عام',
            'is_active' => true,
        ]);

        $sp->serviceProvider->categories()->attach($category->id);

        return compact('tenant', 'sp', 'admin', 'category');
    }

    /**
     * Assert that a timeline entry exists with specific criteria.
     */
    protected function assertTimelineEntryExists(
        int $issueId,
        string $action,
        ?int $performedBy = null
    ): void {
        $this->assertDatabaseHas('issue_timelines', array_filter([
            'issue_id' => $issueId,
            'action' => $action,
            'performed_by' => $performedBy,
        ]));
    }

    /**
     * Wait for a short period (useful for timestamp-dependent tests).
     */
    protected function waitMs(int $milliseconds): void
    {
        usleep($milliseconds * 1000);
    }

    /**
     * Create multiple service providers for the same category.
     */
    protected function createMultipleServiceProviders(Category $category, int $count = 3): array
    {
        $providers = [];

        for ($i = 1; $i <= $count; $i++) {
            $sp = createServiceProviderUser(
                ['is_available' => true],
                ['name' => "Service Provider {$i}", 'email' => "sp{$i}@test.local"]
            );

            $sp->serviceProvider->categories()->attach($category->id);
            $providers[] = $sp;
        }

        return $providers;
    }

    /**
     * Simulate offline-created issue (negative ID in sync operation).
     */
    protected function createOfflineIssueData(string $localId): array
    {
        return [
            'local_id' => $localId,
            'title' => 'Offline Created Issue',
            'description' => 'This was created while offline',
            'priority' => 'high',
            'sync_status' => 'pending',
        ];
    }
}
