<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RolesAndPermissionsSeeder extends Seeder
{
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // Create all permissions manually (Shield format)
        $this->createPermissions();

        // Reset cache again
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // Create roles and assign permissions
        $this->createRolesWithPermissions();

        $this->command->info('Roles and permissions seeded successfully!');
    }

    private function createPermissions(): void
    {
        // Shield permission format: PascalCase action : PascalCase resource (e.g., ViewAny:User)
        // Based on filament-shield.php config: separator => ':', case => 'pascal'
        $resources = [
            'User' => ['ViewAny', 'View', 'Create', 'Update', 'Delete', 'DeleteAny', 'ForceDelete', 'ForceDeleteAny', 'Restore', 'RestoreAny', 'Replicate', 'Reorder'],
            'Tenant' => ['ViewAny', 'View', 'Create', 'Update', 'Delete', 'DeleteAny', 'ForceDelete', 'ForceDeleteAny', 'Restore', 'RestoreAny', 'Replicate', 'Reorder'],
            'ServiceProvider' => ['ViewAny', 'View', 'Create', 'Update', 'Delete', 'DeleteAny', 'ForceDelete', 'ForceDeleteAny', 'Restore', 'RestoreAny', 'Replicate', 'Reorder'],
            'Category' => ['ViewAny', 'View', 'Create', 'Update', 'Delete', 'DeleteAny', 'ForceDelete', 'ForceDeleteAny', 'Restore', 'RestoreAny', 'Replicate', 'Reorder'],
            'Consumable' => ['ViewAny', 'View', 'Create', 'Update', 'Delete', 'DeleteAny', 'ForceDelete', 'ForceDeleteAny', 'Restore', 'RestoreAny', 'Replicate', 'Reorder'],
            'Issue' => ['ViewAny', 'View', 'Create', 'Update', 'Delete', 'DeleteAny', 'ForceDelete', 'ForceDeleteAny', 'Restore', 'RestoreAny', 'Replicate', 'Reorder'],
            'WorkType' => ['ViewAny', 'View', 'Create', 'Update', 'Delete'],
            'TimeExtensionRequest' => ['ViewAny', 'View'],
            'Role' => ['ViewAny', 'View', 'Create', 'Update', 'Delete', 'DeleteAny'],
        ];

        $permissionCount = 0;

        foreach ($resources as $resource => $actions) {
            foreach ($actions as $action) {
                Permission::firstOrCreate([
                    'name' => "{$action}:{$resource}",
                    'guard_name' => 'web',
                ]);
                $permissionCount++;
            }
        }

        // Create custom permissions (these stay as-is since they're custom)
        // Snake_case permissions are used by the mobile app for permission checks
        $customPermissions = [
            'create_issues',
            'update_issues',
            'assign_issues',
            'approve_issues',
            'cancel_issues',
            'view_reports',
            'export_reports',
            'manage_settings',
            // Mobile CRUD permissions (snake_case format for mobile app)
            'view_issues',
            'view_tenants', 'create_tenants', 'update_tenants', 'delete_tenants',
            'view_service_providers', 'create_service_providers', 'update_service_providers', 'delete_service_providers',
            'view_categories', 'create_categories', 'update_categories', 'delete_categories',
            'view_consumables', 'create_consumables', 'update_consumables', 'delete_consumables',
            'view_users', 'create_users', 'update_users', 'delete_users',

            // Work Type Management
            'view_work_types',
            'create_work_types',
            'update_work_types',
            'delete_work_types',
            'override_work_type_duration', // Admin can edit duration during assignment

            // Time Extension Management
            'view_time_extensions',
            'request_time_extension', // Service providers
            'approve_time_extensions', // Admins only
            'reject_time_extensions', // Admins only
        ];

        foreach ($customPermissions as $permission) {
            Permission::firstOrCreate([
                'name' => $permission,
                'guard_name' => 'web',
            ]);
            $permissionCount++;
        }

        $this->command->info("Permissions created: {$permissionCount}");
    }

    private function createRolesWithPermissions(): void
    {
        // Super Admin - has all permissions (but with define_via_gate: true, this bypasses checks anyway)
        $superAdmin = Role::firstOrCreate(['name' => 'super_admin', 'guard_name' => 'web']);
        $superAdmin->syncPermissions(Permission::all());

        // Manager - can view all resources, assign/approve/cancel issues, view reports
        $manager = Role::firstOrCreate(['name' => 'manager', 'guard_name' => 'web']);
        $manager->syncPermissions([
            // View all resources (Shield format: Action:Resource)
            'ViewAny:User',
            'View:User',
            'ViewAny:Tenant',
            'View:Tenant',
            'ViewAny:ServiceProvider',
            'View:ServiceProvider',
            'ViewAny:Category',
            'View:Category',
            'ViewAny:Consumable',
            'View:Consumable',
            'Create:Consumable',
            'Update:Consumable',
            'ViewAny:Issue',
            'View:Issue',
            'Create:Issue',
            'Update:Issue',

            // Work Types (Shield format)
            'ViewAny:WorkType',
            'View:WorkType',
            'Create:WorkType',
            'Update:WorkType',
            'Delete:WorkType',

            // Time Extensions (Shield format)
            'ViewAny:TimeExtensionRequest',
            'View:TimeExtensionRequest',

            // Issue management (custom permissions)
            'create_issues',
            'update_issues',
            'assign_issues',
            'approve_issues',
            'cancel_issues',

            // Reports
            'view_reports',

            // Mobile permissions (snake_case for mobile app)
            'view_issues',
            'view_tenants',
            'view_service_providers',
            'view_categories',
            'view_consumables', 'create_consumables', 'update_consumables',
            'view_users',

            // Work Types (mobile format)
            'view_work_types',
            'create_work_types',
            'update_work_types',
            'delete_work_types',
            'override_work_type_duration',

            // Time Extensions (mobile format)
            'view_time_extensions',
            'approve_time_extensions',
            'reject_time_extensions',
        ]);

        // Viewer - can only view issues and reports
        $viewer = Role::firstOrCreate(['name' => 'viewer', 'guard_name' => 'web']);
        $viewer->syncPermissions([
            'ViewAny:Issue',
            'View:Issue',
            'ViewAny:WorkType',
            'View:WorkType',
            'ViewAny:TimeExtensionRequest',
            'View:TimeExtensionRequest',
            'view_reports',

            // Mobile permissions (snake_case for mobile app)
            'view_issues',
            'view_work_types',
            'view_time_extensions',
        ]);

        // Tenant - no panel access (mobile app only)
        $tenant = Role::firstOrCreate(['name' => 'tenant', 'guard_name' => 'web']);
        $tenant->syncPermissions([]);

        // Service Provider - no panel access (mobile app only)
        $serviceProvider = Role::firstOrCreate(['name' => 'service_provider', 'guard_name' => 'web']);
        $serviceProvider->syncPermissions([
            'request_time_extension',
        ]);

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
