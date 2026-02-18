<?php

declare(strict_types=1);

use App\Models\User;
use App\Models\Tenant;
use App\Models\ServiceProvider;
use App\Models\Category;

/*
|--------------------------------------------------------------------------
| Authentication API Tests
|--------------------------------------------------------------------------
|
| Comprehensive tests for the authentication endpoints:
| - POST /api/v1/auth/login
| - POST /api/v1/auth/logout
| - POST /api/v1/auth/refresh
| - GET /api/v1/auth/me
|
*/

/*
|--------------------------------------------------------------------------
| Login Tests
|--------------------------------------------------------------------------
*/

describe('POST /api/v1/auth/login', function () {
    it('returns token and user data with valid credentials', function () {
        $user = createUser();

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => [
                    'access_token',
                    'token_type',
                    'expires_in',
                    'user' => [
                        'id',
                        'name',
                        'email',
                        'locale',
                        'roles',
                        'is_tenant',
                        'is_service_provider',
                        'is_admin',
                    ],
                ],
            ])
            ->assertJson([
                'success' => true,
                'data' => [
                    'token_type' => 'bearer',
                    'user' => [
                        'id' => $user->id,
                        'email' => $user->email,
                    ],
                ],
            ]);
    });

    it('fails with invalid email format', function () {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'invalid-email',
            'password' => 'password',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    });

    it('fails with non-existent email', function () {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'nonexistent@example.com',
            'password' => 'password',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    });

    it('fails with wrong password', function () {
        $user = createUser();

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'wrong-password',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    });

    it('fails with inactive user account', function () {
        $user = createUser(['is_active' => false]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    });

    it('validates required email field', function () {
        $response = $this->postJson('/api/v1/auth/login', [
            'password' => 'password',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    });

    it('validates required password field', function () {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'test@example.com',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['password']);
    });

    it('validates both required fields', function () {
        $response = $this->postJson('/api/v1/auth/login', []);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'password']);
    });

    it('returns tenant info for tenant user', function () {
        $user = createTenantUser();

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'is_tenant' => true,
                        'is_service_provider' => false,
                        'is_admin' => false,
                    ],
                ],
            ]);
    });

    it('returns service provider info for SP user', function () {
        $user = createServiceProviderUser();

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'is_tenant' => false,
                        'is_service_provider' => true,
                        'is_admin' => false,
                    ],
                ],
            ]);
    });

    it('returns admin info for admin user', function () {
        $user = createAdminUser('super_admin');

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'is_admin' => true,
                    ],
                ],
            ]);
    });
});

/*
|--------------------------------------------------------------------------
| Logout Tests
|--------------------------------------------------------------------------
*/

describe('POST /api/v1/auth/logout', function () {
    it('successfully logs out with valid token', function () {
        $user = createUser();
        $headers = authHeaders($user);

        $response = $this->postJson('/api/v1/auth/logout', [], $headers);

        $response->assertOk()
            ->assertJson([
                'success' => true,
            ]);
    });

    it('returns 401 without authentication token', function () {
        $response = $this->postJson('/api/v1/auth/logout');

        $response->assertUnauthorized();
    });

    it('returns 401 with invalid token', function () {
        $response = $this->postJson('/api/v1/auth/logout', [], [
            'Authorization' => 'Bearer invalid-token',
        ]);

        $response->assertUnauthorized();
    });

    it('invalidates token after logout', function () {
        $user = createUser();
        $headers = authHeaders($user);

        // First, logout
        $this->postJson('/api/v1/auth/logout', [], $headers)->assertOk();

        // Try to access protected route with same token
        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertUnauthorized();
    });
});

/*
|--------------------------------------------------------------------------
| Refresh Token Tests
|--------------------------------------------------------------------------
*/

describe('POST /api/v1/auth/refresh', function () {
    it('successfully refreshes token with valid token', function () {
        $user = createUser();
        $headers = authHeaders($user);

        $response = $this->postJson('/api/v1/auth/refresh', [], $headers);

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => [
                    'access_token',
                    'token_type',
                    'expires_in',
                    'user',
                ],
            ])
            ->assertJson([
                'success' => true,
                'data' => [
                    'token_type' => 'bearer',
                ],
            ]);
    });

    it('returns new token different from original', function () {
        $user = createUser();
        $originalToken = getAuthToken($user);

        $response = $this->postJson('/api/v1/auth/refresh', [], [
            'Authorization' => 'Bearer ' . $originalToken,
        ]);

        $response->assertOk();

        $newToken = $response->json('data.access_token');
        expect($newToken)->not->toBe($originalToken);
    });

    it('returns 401 without authentication token', function () {
        $response = $this->postJson('/api/v1/auth/refresh');

        $response->assertUnauthorized();
    });

    it('returns 401 with invalid token', function () {
        $response = $this->postJson('/api/v1/auth/refresh', [], [
            'Authorization' => 'Bearer invalid-token',
        ]);

        $response->assertUnauthorized();
    });
});

/*
|--------------------------------------------------------------------------
| Me Endpoint Tests
|--------------------------------------------------------------------------
*/

describe('GET /api/v1/auth/me', function () {
    it('returns authenticated user data', function () {
        $user = createUser([
            'name' => 'Test User',
            'email' => 'testuser@example.com',
            'phone' => '+1234567890',
            'locale' => 'en',
        ]);
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => [
                    'id',
                    'name',
                    'email',
                    'phone',
                    'locale',
                    'is_active',
                    'roles',
                    'permissions',
                    'is_tenant',
                    'is_service_provider',
                    'is_admin',
                    'tenant',
                    'service_provider',
                    'created_at',
                ],
            ])
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $user->id,
                    'name' => 'Test User',
                    'email' => 'testuser@example.com',
                    'phone' => '+1234567890',
                    'locale' => 'en',
                    'is_active' => true,
                ],
            ]);
    });

    it('returns 401 for unauthenticated requests', function () {
        $response = $this->getJson('/api/v1/auth/me');

        $response->assertUnauthorized();
    });

    it('returns 401 with invalid token', function () {
        $response = $this->getJson('/api/v1/auth/me', [
            'Authorization' => 'Bearer invalid-token',
        ]);

        $response->assertUnauthorized();
    });

    it('returns tenant role information correctly', function () {
        $user = createTenantUser([
            'unit_number' => 'A101',
            'building_name' => 'Tower One',
        ]);
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_tenant' => true,
                    'is_service_provider' => false,
                    'is_admin' => false,
                    'tenant' => [
                        'unit_number' => 'A101',
                    ],
                ],
            ]);

        expect($response->json('data.service_provider'))->toBeNull();
    });

    it('returns service provider role information correctly', function () {
        $user = createServiceProviderUser();
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_tenant' => false,
                    'is_service_provider' => true,
                    'is_admin' => false,
                ],
            ]);

        expect($response->json('data.tenant'))->toBeNull();
        expect($response->json('data.service_provider'))->not->toBeNull();
    });

    it('returns super_admin role information correctly', function () {
        $user = createAdminUser('super_admin');
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_admin' => true,
                ],
            ]);

        $roles = $response->json('data.roles');
        expect($roles)->toContain('super_admin');
    });

    it('returns manager role information correctly', function () {
        $user = createAdminUser('manager');
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_admin' => true,
                ],
            ]);

        $roles = $response->json('data.roles');
        expect($roles)->toContain('manager');
    });

    it('returns viewer role information correctly', function () {
        $user = createAdminUser('viewer');
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_admin' => true,
                ],
            ]);

        $roles = $response->json('data.roles');
        expect($roles)->toContain('viewer');
    });

    it('returns user permissions list', function () {
        $user = createAdminUser('super_admin');
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk();

        expect($response->json('data.permissions'))->toBeArray();
    });

    it('returns ISO formatted created_at timestamp', function () {
        $user = createUser();
        $headers = authHeaders($user);

        $response = $this->getJson('/api/v1/auth/me', $headers);

        $response->assertOk();

        $createdAt = $response->json('data.created_at');
        expect($createdAt)->toMatch('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d+Z$/');
    });
});

/*
|--------------------------------------------------------------------------
| Token Expiry Tests
|--------------------------------------------------------------------------
*/

describe('Token Expiration', function () {
    it('includes expires_in value in login response', function () {
        $user = createUser();

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertOk();

        $expiresIn = $response->json('data.expires_in');
        expect($expiresIn)->toBeInt()
            ->toBeGreaterThan(0);
    });

    it('includes expires_in value in refresh response', function () {
        $user = createUser();
        $headers = authHeaders($user);

        $response = $this->postJson('/api/v1/auth/refresh', [], $headers);

        $response->assertOk();

        $expiresIn = $response->json('data.expires_in');
        expect($expiresIn)->toBeInt()
            ->toBeGreaterThan(0);
    });
});
