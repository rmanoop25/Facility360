<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            // 1. First create roles and permissions
            RolesAndPermissionsSeeder::class,

            // 2. Create master data (needed for service providers)
            CategorySeeder::class,
            WorkTypeSeeder::class,
            ConsumableSeeder::class,

            // 3. Create users (admin, tenants, service providers)
            AdminUserSeeder::class,

            // 4. Create time slots for service providers
            TimeSlotSeeder::class,

            // 5. Create issues with various statuses
            EnhancedIssueSeeder::class,

            // 6. Create assignments, timeline, media, proofs, consumables
            DemoDataSeeder::class,
        ]);

        $this->command->newLine();
        $this->command->info('===========================================');
        $this->command->info('Database seeding completed successfully!');
        $this->command->info('===========================================');
        $this->command->newLine();
        $this->command->warn('Default password for all users: password');
        $this->command->newLine();
        $this->command->info('Admin Panel: /admin');
        $this->command->info('  - admin@maintenance.local (super_admin)');
        $this->command->info('  - manager@maintenance.local (manager)');
        $this->command->info('  - viewer@maintenance.local (viewer)');
        $this->command->newLine();
        $this->command->info('Mobile App Users:');
        $this->command->info('  - tenant1@maintenance.local to tenant30@maintenance.local (30 tenants)');
        $this->command->info('  - plumber@maintenance.local, electrician@maintenance.local, etc. (30 service providers)');
        $this->command->newLine();
        $this->command->info('Categories: 50+ categories with 3-level hierarchy');
        $this->command->info('Work Types: 20+ work types with duration estimates');
        $this->command->info('Consumables: 150+ consumables across all categories');
        $this->command->info('Issues: 38 issues with various statuses and priorities');
        $this->command->info('Assignments: Capacity-based with time ranges and work types');
        $this->command->newLine();
    }
}
