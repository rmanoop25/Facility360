<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class ShieldPermissionsSeeder extends Seeder
{
    /**
     * This seeder runs AFTER Shield generates permissions.
     * It assigns permissions to roles based on their access level.
     */
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // Super admin gets all permissions
        $superAdmin = Role::findByName('super_admin', 'web');
        $superAdmin->syncPermissions(Permission::all());

        // Manager permissions - can manage most things but not roles/users
        $manager = Role::findByName('manager', 'web');
        $managerPermissions = Permission::whereIn('name', [
            // User - view only
            'ViewAny:User',
            'View:User',
            // Tenant - view only
            'ViewAny:Tenant',
            'View:Tenant',
            // ServiceProvider - view only
            'ViewAny:ServiceProvider',
            'View:ServiceProvider',
            // Category - view only
            'ViewAny:Category',
            'View:Category',
            // Consumable - full access
            'ViewAny:Consumable',
            'View:Consumable',
            'Create:Consumable',
            'Update:Consumable',
            // Issue - full access except delete
            'ViewAny:Issue',
            'View:Issue',
            'Create:Issue',
            'Update:Issue',
        ])->pluck('name')->toArray();

        // Add custom permissions
        $managerPermissions = array_merge($managerPermissions, [
            'update_issues',
            'assign_issues',
            'approve_issues',
            'cancel_issues',
            'view_reports',
        ]);
        $manager->syncPermissions($managerPermissions);

        // Viewer permissions - read-only access
        $viewer = Role::findByName('viewer', 'web');
        $viewerPermissions = Permission::whereIn('name', [
            'ViewAny:Issue',
            'View:Issue',
        ])->pluck('name')->toArray();

        // Add custom permissions
        $viewerPermissions = array_merge($viewerPermissions, [
            'view_reports',
        ]);
        $viewer->syncPermissions($viewerPermissions);

        // Tenant & Service Provider - no Filament permissions needed
        // They use mobile app with API-based access control
        $tenant = Role::findByName('tenant', 'web');
        $tenant->syncPermissions([]);

        $serviceProvider = Role::findByName('service_provider', 'web');
        $serviceProvider->syncPermissions([]);

        $this->command->info('Shield permissions assigned to roles successfully!');
        $this->command->table(
            ['Role', 'Permissions Count'],
            [
                ['super_admin', $superAdmin->permissions()->count()],
                ['manager', $manager->permissions()->count()],
                ['viewer', $viewer->permissions()->count()],
                ['tenant', $tenant->permissions()->count()],
                ['service_provider', $serviceProvider->permissions()->count()],
            ]
        );
    }
}
