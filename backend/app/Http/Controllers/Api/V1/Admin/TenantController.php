<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Http\Resources\TenantResource;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class TenantController extends ApiController
{
    /**
     * List all tenants with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Tenant::with('user:id,name,email,phone,profile_photo,is_active,locale')
            ->withCount('issues')
            ->orderBy('created_at', 'desc');

        if ($request->filled('search')) {
            $search = $validated['search'];
            $query->whereHas('user', function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            })->orWhere('unit_number', 'like', "%{$search}%");
        }

        if ($request->has('is_active')) {
            $query->whereHas('user', fn ($q) => $q->where('is_active', $validated['is_active']));
        }

        $perPage = $validated['per_page'] ?? 15;
        $tenants = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => TenantResource::collection($tenants->items()),
            'message' => __('api.tenants.list_success'),
            'meta' => [
                'current_page' => $tenants->currentPage(),
                'last_page' => $tenants->lastPage(),
                'per_page' => $tenants->perPage(),
                'total' => $tenants->total(),
            ],
            'links' => [
                'first' => $tenants->url(1),
                'last' => $tenants->url($tenants->lastPage()),
                'prev' => $tenants->previousPageUrl(),
                'next' => $tenants->nextPageUrl(),
            ],
        ]);
    }

    /**
     * Create a new tenant.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:20'],
            'password' => ['required', 'string', 'min:8'],
            'unit_number' => ['required', 'string', 'max:50'],
            'building_name' => ['nullable', 'string', 'max:255'],
            'floor' => ['nullable', 'string', 'max:10'],
            'locale' => ['nullable', 'string', Rule::in(['en', 'ar'])],
            'is_active' => ['nullable', 'boolean'],
            'profile_photo' => ['nullable', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
        ]);

        try {
            DB::beginTransaction();

            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'phone' => $validated['phone'] ?? null,
                'password' => Hash::make($validated['password']),
                'locale' => $validated['locale'] ?? 'en',
                'is_active' => $validated['is_active'] ?? true,
            ]);

            // Handle profile photo upload
            if ($request->hasFile('profile_photo')) {
                $path = $request->file('profile_photo')->store("profile-photos/{$user->id}", 'public');
                $user->update(['profile_photo' => $path]);
            }

            $tenant = Tenant::create([
                'user_id' => $user->id,
                'unit_number' => $validated['unit_number'],
                'building_name' => $validated['building_name'] ?? null,
                'floor' => $validated['floor'] ?? null,
            ]);

            DB::commit();

            $tenant->load('user:id,name,email,phone,profile_photo,is_active,locale');

            return response()->json([
                'success' => true,
                'data' => new TenantResource($tenant),
                'message' => __('api.tenants.created_success'),
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.tenants.create_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Show tenant details.
     */
    public function show(int $id): JsonResponse
    {
        $tenant = Tenant::with([
            'user:id,name,email,phone,profile_photo,is_active,locale,created_at',
            'issues' => fn ($q) => $q->latest()->limit(10),
        ])->find($id);

        if (! $tenant) {
            return $this->notFound(__('api.tenants.not_found'));
        }

        return response()->json([
            'success' => true,
            'data' => new TenantResource($tenant),
            'message' => __('api.tenants.show_success'),
        ]);
    }

    /**
     * Update tenant details.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $tenant = Tenant::with('user')->find($id);

        if (! $tenant) {
            return $this->notFound(__('api.tenants.not_found'));
        }

        // Cast is_active from multipart string ("true"/"false"/"1"/"0") to boolean
        if ($request->has('is_active')) {
            $request->merge([
                'is_active' => filter_var($request->input('is_active'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE),
            ]);
        }

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'email', Rule::unique('users')->ignore($tenant->user_id)],
            'phone' => ['nullable', 'string', 'max:20'],
            'password' => ['nullable', 'string', 'min:8'],
            'unit_number' => ['sometimes', 'string', 'max:50'],
            'building_name' => ['nullable', 'string', 'max:255'],
            'floor' => ['nullable', 'string', 'max:10'],
            'locale' => ['nullable', 'string', Rule::in(['en', 'ar'])],
            'is_active' => ['nullable', 'boolean'],
            'profile_photo' => ['nullable', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
        ]);

        try {
            DB::beginTransaction();

            // Update user
            $userUpdates = array_filter([
                'name' => $validated['name'] ?? null,
                'email' => $validated['email'] ?? null,
                'phone' => $validated['phone'] ?? null,
                'locale' => $validated['locale'] ?? null,
                'is_active' => $validated['is_active'] ?? null,
            ], fn ($value) => $value !== null);

            if (isset($validated['password'])) {
                $userUpdates['password'] = Hash::make($validated['password']);
            }

            // Handle profile photo upload
            if ($request->hasFile('profile_photo')) {
                // Delete old photo if exists
                if ($tenant->user->profile_photo) {
                    Storage::disk('public')->delete($tenant->user->profile_photo);
                }
                $path = $request->file('profile_photo')->store("profile-photos/{$tenant->user_id}", 'public');
                $userUpdates['profile_photo'] = $path;
            }

            if (! empty($userUpdates)) {
                $tenant->user->update($userUpdates);
            }

            // Update tenant
            $tenantUpdates = array_filter([
                'unit_number' => $validated['unit_number'] ?? null,
                'building_name' => $validated['building_name'] ?? null,
                'floor' => $validated['floor'] ?? null,
            ], fn ($value) => $value !== null);

            if (! empty($tenantUpdates)) {
                $tenant->update($tenantUpdates);
            }

            DB::commit();

            $tenant->refresh();
            $tenant->load('user:id,name,email,phone,profile_photo,is_active,locale');

            return response()->json([
                'success' => true,
                'data' => new TenantResource($tenant),
                'message' => __('api.tenants.updated_success'),
            ]);
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.tenants.update_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Delete a tenant.
     */
    public function destroy(int $id): JsonResponse
    {
        $tenant = Tenant::with('user')->find($id);

        if (! $tenant) {
            return $this->notFound(__('api.tenants.not_found'));
        }

        try {
            DB::beginTransaction();

            // Soft delete or hard delete based on business rules
            $tenant->user->update(['is_active' => false]);
            $tenant->delete();

            DB::commit();

            return $this->success(null, __('api.tenants.deleted_success'));
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.tenants.delete_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }
}
