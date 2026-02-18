<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;

class AuthController extends ApiController
{
    /**
     * Authenticate user and return JWT token.
     *
     * @throws ValidationException
     */
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        // Check if user is active
        $token = Auth::guard('api')->attempt($credentials);

        if (! $token) {
            throw ValidationException::withMessages([
                'email' => [__('auth.failed')],
            ]);
        }

        /** @var \App\Models\User $user */
        $user = Auth::guard('api')->user();

        // Check if user account is active
        if (! $user->is_active) {
            Auth::guard('api')->logout();

            throw ValidationException::withMessages([
                'email' => [__('auth.inactive')],
            ]);
        }

        return $this->respondWithToken($token);
    }

    /**
     * Invalidate the current token and log out the user.
     */
    public function logout(): JsonResponse
    {
        Auth::guard('api')->logout();

        return response()->json([
            'success' => true,
            'message' => __('auth.logged_out'),
        ]);
    }

    /**
     * Refresh the current JWT token.
     */
    public function refresh(): JsonResponse
    {
        try {
            $token = Auth::guard('api')->refresh();

            return $this->respondWithToken($token);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => __('auth.token_refresh_failed'),
            ], 401);
        }
    }

    /**
     * Get the authenticated user's information.
     */
    public function me(): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = Auth::guard('api')->user();

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'profile_photo_url' => $user->profile_photo
                    ? \Illuminate\Support\Facades\Storage::disk('public')->url($user->profile_photo)
                    : null,
                'locale' => $user->locale ?? 'en',
                'is_active' => $user->is_active,
                'roles' => $user->getRoleNames(),
                'permissions' => $user->getAllPermissions()->pluck('name'),
                'is_tenant' => $user->isTenant(),
                'is_service_provider' => $user->isServiceProvider(),
                'is_admin' => $user->isAdmin(),
                'tenant' => $user->isTenant() ? [
                    'id' => $user->tenant->id,
                    'user_id' => $user->tenant->user_id,
                    'unit_number' => $user->tenant->unit_number ?? null,
                    'building_name' => $user->tenant->building_name ?? null,
                ] : null,
                'service_provider' => $user->isServiceProvider() ? [
                    'id' => $user->serviceProvider->id,
                    'user_id' => $user->serviceProvider->user_id,
                    'category_ids' => $user->serviceProvider->categories->pluck('id'),
                    'is_available' => $user->serviceProvider->is_available ?? true,
                ] : null,
                'created_at' => $user->created_at->toISOString(),
            ],
        ]);
    }

    /**
     * Format the token response.
     */
    protected function respondWithToken(string $token): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = Auth::guard('api')->user();

        return response()->json([
            'success' => true,
            'data' => [
                'access_token' => $token,
                'token_type' => 'bearer',
                'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'locale' => $user->locale ?? 'en',
                    'roles' => $user->getRoleNames(),
                    'is_tenant' => $user->isTenant(),
                    'is_service_provider' => $user->isServiceProvider(),
                    'is_admin' => $user->isAdmin(),
                ],
            ],
        ]);
    }
}
