<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\Models\Permission;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Removes PascalCase duplicate permissions that were incorrectly created.
     * These duplicates (e.g., ApproveIssues, AssignIssues) are not used anywhere
     * in the codebase. The correct snake_case versions (e.g., approve_issues,
     * assign_issues) are used by the mobile app and API controllers.
     */
    public function up(): void
    {
        // List of PascalCase duplicates to remove (not following Action:Resource format)
        $duplicates = [
            // Issue workflow actions
            'ApproveIssues',
            'AssignIssues',
            'CancelIssues',

            // Categories CRUD
            'CreateCategories',
            'UpdateCategories',
            'DeleteCategories',
            'ViewCategories',

            // Consumables CRUD
            'CreateConsumables',
            'UpdateConsumables',
            'DeleteConsumables',
            'ViewConsumables',

            // Issues CRUD
            'CreateIssues',
            'ViewIssues',

            // Tenants CRUD
            'CreateTenants',
            'UpdateTenants',
            'DeleteTenants',
            'ViewTenants',

            // Service Providers CRUD
            'CreateServiceProviders',
            'UpdateServiceProviders',
            'DeleteServiceProviders',
            'ViewServiceProviders',

            // Users CRUD
            'CreateUsers',
            'UpdateUsers',
            'DeleteUsers',
            'ViewUsers',

            // Reports & Settings
            'ExportReports',
            'ManageSettings',
            'ViewReports',
        ];

        // Delete duplicate permissions
        Permission::whereIn('name', $duplicates)->delete();

        // Clear cache after permission changes
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();
    }

    /**
     * Reverse the migrations.
     *
     * No rollback needed - these were incorrect duplicates that shouldn't exist.
     */
    public function down(): void
    {
        // No rollback - duplicates should not be recreated
    }
};
