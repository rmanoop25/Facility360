<?php

declare(strict_types=1);

use App\Models\User;
use App\Models\Tenant;
use App\Models\ServiceProvider;
use App\Models\Category;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
|
| The closure you provide to your test functions is always bound to a specific PHPUnit test
| case class. By default, that class is "PHPUnit\Framework\TestCase". Of course, you may
| need to change it using the "pest()" function to bind a different classes or traits.
|
*/

pest()->extend(Tests\TestCase::class)
    ->use(Illuminate\Foundation\Testing\RefreshDatabase::class)
    ->in('Feature');

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
|
| When you're writing tests, you often need to check that values meet certain conditions. The
| "expect()" function gives you access to a set of "expectations" methods that you can use
| to assert different things. Of course, you may extend the Expectation API at any time.
|
*/

expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

/*
|--------------------------------------------------------------------------
| Helper Functions
|--------------------------------------------------------------------------
|
| Global helper functions for creating test data and authentication.
| These functions are available in all test files.
|
*/

/**
 * Ensure required roles exist in the database.
 */
function ensureRolesExist(): void
{
    $roles = ['super_admin', 'manager', 'viewer', 'tenant', 'service_provider'];

    foreach ($roles as $roleName) {
        Role::firstOrCreate(
            ['name' => $roleName, 'guard_name' => 'web']
        );
    }
}

/**
 * Ensure required permissions exist and assign them to roles.
 */
function ensurePermissionsExist(): void
{
    $permissions = [
        'manage_users',
        'manage_service_providers',
        'manage_tenants',
        'manage_categories',
        'manage_consumables',
        'assign_issues',
        'approve_issues',
        'view_reports',
        'manage_settings',
    ];

    foreach ($permissions as $permissionName) {
        Permission::firstOrCreate(
            ['name' => $permissionName, 'guard_name' => 'web']
        );
    }

    // Assign all permissions to super_admin
    $superAdmin = Role::where('name', 'super_admin')->first();
    if ($superAdmin) {
        $superAdmin->syncPermissions(Permission::all());
    }

    // Assign limited permissions to manager
    $manager = Role::where('name', 'manager')->first();
    if ($manager) {
        $manager->syncPermissions([
            'assign_issues',
            'approve_issues',
            'view_reports',
            'manage_tenants',
            'manage_service_providers',
        ]);
    }

    // Assign view-only permissions to viewer
    $viewer = Role::where('name', 'viewer')->first();
    if ($viewer) {
        $viewer->syncPermissions(['view_reports']);
    }
}

/**
 * Create a basic user with optional attributes.
 */
function createUser(array $attributes = []): User
{
    return User::factory()->create(array_merge([
        'password' => Hash::make('password'),
        'is_active' => true,
        'locale' => 'en',
    ], $attributes));
}

/**
 * Create a tenant user with associated Tenant record.
 */
function createTenantUser(array $tenantAttributes = [], array $userAttributes = []): User
{
    ensureRolesExist();

    $user = User::factory()->create(array_merge([
        'password' => Hash::make('password'),
        'is_active' => true,
        'locale' => 'en',
    ], $userAttributes));

    $user->assignRole('tenant');

    Tenant::create(array_merge([
        'user_id' => $user->id,
        'unit_number' => 'A-' . fake()->numberBetween(100, 999),
        'building_name' => 'Building ' . fake()->randomLetter(),
    ], $tenantAttributes));

    return $user->fresh();
}

/**
 * Create a service provider user with associated ServiceProvider record.
 */
function createServiceProviderUser(array $spAttributes = [], array $userAttributes = []): User
{
    ensureRolesExist();

    $user = User::factory()->create(array_merge([
        'password' => Hash::make('password'),
        'is_active' => true,
        'locale' => 'en',
    ], $userAttributes));

    $user->assignRole('service_provider');

    // Ensure a category exists for the service provider
    $category = Category::first() ?? Category::create([
        'name_en' => 'Plumbing',
        'name_ar' => 'السباكة',
        'is_active' => true,
    ]);

    ServiceProvider::create(array_merge([
        'user_id' => $user->id,
        'category_id' => $spAttributes['category_id'] ?? $category->id,
        'is_available' => true,
    ], $spAttributes));

    return $user->fresh();
}

/**
 * Create an admin user with the specified role.
 */
function createAdminUser(string $role = 'super_admin', array $attributes = []): User
{
    ensureRolesExist();
    ensurePermissionsExist();

    $user = User::factory()->create(array_merge([
        'password' => Hash::make('password'),
        'is_active' => true,
        'locale' => 'en',
    ], $attributes));

    $user->assignRole($role);

    return $user->fresh();
}

/**
 * Get JWT token for a user.
 */
function getAuthToken(User $user): string
{
    return auth('api')->login($user);
}

/**
 * Get authentication headers for a user.
 */
function authHeaders(User $user): array
{
    $token = getAuthToken($user);

    return [
        'Authorization' => 'Bearer ' . $token,
        'Accept' => 'application/json',
    ];
}

/**
 * Login a user and return the JWT token.
 *
 * @deprecated Use getAuthToken() instead
 */
function loginUser(User $user): string
{
    return getAuthToken($user);
}
