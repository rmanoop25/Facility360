<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\UserRole;
use App\Http\Controllers\Api\V1\ApiController;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AdminTenantController extends ApiController
{
    /**
     * List all tenants with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'search' => ['nullable', 'string', 'max:255'],
            'building_name' => ['nullable', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
            'sort_by' => ['nullable', 'string', Rule::in(['created_at', 'name', 'unit_number', 'building_name'])],
            'sort_order' => ['nullable', 'string', Rule::in(['asc', 'desc'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $query = Tenant::with(['user:id,name,email,phone,profile_photo,is_active,created_at'])
            ->withCount('issues');

        // Apply filters
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('unit_number', 'like', "%{$search}%")
                    ->orWhere('building_name', 'like', "%{$search}%")
                    ->orWhereHas('user', fn ($uq) => $uq->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                    );
            });
        }

        if ($request->filled('building_name')) {
            $query->where('building_name', $request->input('building_name'));
        }

        if ($request->has('is_active')) {
            $query->whereHas('user', fn ($q) => $q->where('is_active', $request->boolean('is_active')));
        }

        // Apply sorting
        $sortBy = $request->input('sort_by', 'created_at');
        $sortOrder = $request->input('sort_order', 'desc');

        if ($sortBy === 'name') {
            $query->join('users', 'tenants.user_id', '=', 'users.id')
                ->orderBy('users.name', $sortOrder)
                ->select('tenants.*');
        } else {
            $query->orderBy($sortBy, $sortOrder);
        }

        $perPage = $request->input('per_page', 15);
        $tenants = $query->paginate($perPage);

        $data = $tenants->getCollection()->map(fn ($tenant) => $this->formatTenant($tenant));

        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => [
                'current_page' => $tenants->currentPage(),
                'last_page' => $tenants->lastPage(),
                'per_page' => $tenants->perPage(),
                'total' => $tenants->total(),
            ],
        ]);
    }

    /**
     * Create a new tenant.
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::min(8)->mixedCase()->numbers()],
            'phone' => ['required', 'string', 'max:20'],
            'unit_number' => ['required', 'string', 'max:50'],
            'building_name' => ['required', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
            'profile_photo' => ['nullable', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Create user
            $user = User::create([
                'name' => $request->input('name'),
                'email' => $request->input('email'),
                'password' => Hash::make($request->input('password')),
                'phone' => $request->input('phone'),
                'is_active' => $request->input('is_active', true),
                'locale' => $request->input('locale', 'en'),
            ]);

            // Assign tenant role
            $user->assignRole(UserRole::TENANT->value);

            // Handle profile photo upload
            if ($request->hasFile('profile_photo')) {
                $path = $request->file('profile_photo')->store("profile-photos/{$user->id}", 'public');
                $user->update(['profile_photo' => $path]);
            }

            // Create tenant profile
            $tenant = Tenant::create([
                'user_id' => $user->id,
                'unit_number' => $request->input('unit_number'),
                'building_name' => $request->input('building_name'),
            ]);

            $tenant->load('user:id,name,email,phone,profile_photo,is_active,created_at');

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('tenants.created_successfully'),
                'data' => $this->formatTenant($tenant),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Get tenant details.
     */
    public function show(int $id): JsonResponse
    {
        $tenant = Tenant::with([
            'user:id,name,email,phone,profile_photo,is_active,locale,created_at,updated_at',
            'issues' => fn ($q) => $q->latest()->limit(10)->with('categories:id,name_en,name_ar'),
        ])->withCount(['issues', 'issues as open_issues_count' => fn ($q) => $q->active()])->find($id);

        if (! $tenant) {
            return response()->json([
                'success' => false,
                'message' => __('tenants.not_found'),
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatTenantDetail($tenant),
        ]);
    }

    /**
     * Update tenant.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $tenant = Tenant::with('user')->find($id);

        if (! $tenant) {
            return response()->json([
                'success' => false,
                'message' => __('tenants.not_found'),
            ], 404);
        }

        // Cast is_active from multipart string ("true"/"false"/"1"/"0") to boolean
        if ($request->has('is_active')) {
            $request->merge([
                'is_active' => filter_var($request->input('is_active'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE),
            ]);
        }

        $validator = Validator::make($request->all(), [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['sometimes', 'required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($tenant->user_id)],
            'phone' => ['sometimes', 'required', 'string', 'max:20'],
            'unit_number' => ['sometimes', 'required', 'string', 'max:50'],
            'building_name' => ['sometimes', 'required', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
            'locale' => ['nullable', 'string', Rule::in(['en', 'ar'])],
            'profile_photo' => ['nullable', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Update user fields
            $userFields = [];
            if ($request->has('name')) {
                $userFields['name'] = $request->input('name');
            }
            if ($request->has('email')) {
                $userFields['email'] = $request->input('email');
            }
            if ($request->has('phone')) {
                $userFields['phone'] = $request->input('phone');
            }
            if ($request->has('is_active')) {
                $userFields['is_active'] = $request->boolean('is_active');
            }
            if ($request->has('locale')) {
                $userFields['locale'] = $request->input('locale');
            }

            // Handle profile photo upload
            if ($request->hasFile('profile_photo')) {
                // Delete old photo if exists
                if ($tenant->user->profile_photo) {
                    Storage::disk('public')->delete($tenant->user->profile_photo);
                }
                $path = $request->file('profile_photo')->store("profile-photos/{$tenant->user_id}", 'public');
                $userFields['profile_photo'] = $path;
            }

            if (! empty($userFields)) {
                $tenant->user->update($userFields);
            }

            // Update tenant fields
            $tenantFields = [];
            if ($request->has('unit_number')) {
                $tenantFields['unit_number'] = $request->input('unit_number');
            }
            if ($request->has('building_name')) {
                $tenantFields['building_name'] = $request->input('building_name');
            }

            if (! empty($tenantFields)) {
                $tenant->update($tenantFields);
            }

            $tenant->refresh();
            $tenant->load('user:id,name,email,phone,profile_photo,is_active,created_at');

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('tenants.updated_successfully'),
                'data' => $this->formatTenant($tenant),
            ]);

        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Delete tenant.
     */
    public function destroy(int $id): JsonResponse
    {
        $tenant = Tenant::with('user')->withCount('issues')->find($id);

        if (! $tenant) {
            return response()->json([
                'success' => false,
                'message' => __('tenants.not_found'),
            ], 404);
        }

        // Check for active issues
        $activeIssuesCount = $tenant->issues()->active()->count();
        if ($activeIssuesCount > 0) {
            return response()->json([
                'success' => false,
                'message' => __('tenants.has_active_issues', ['count' => $activeIssuesCount]),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Delete tenant profile
            $tenant->delete();

            // Delete user account
            $tenant->user->delete();

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('tenants.deleted_successfully'),
            ]);

        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Reset tenant password.
     */
    public function resetPassword(Request $request, int $id): JsonResponse
    {
        $tenant = Tenant::with('user')->find($id);

        if (! $tenant) {
            return response()->json([
                'success' => false,
                'message' => __('tenants.not_found'),
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'password' => ['nullable', 'string', Password::min(8)->mixedCase()->numbers()],
            'send_email' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        // Generate password if not provided
        $newPassword = $request->input('password') ?? Str::random(12);

        try {
            $tenant->user->update([
                'password' => Hash::make($newPassword),
            ]);

            // TODO: Send email notification with new password if requested
            // if ($request->boolean('send_email', true)) {
            //     $tenant->user->notify(new PasswordResetNotification($newPassword));
            // }

            return response()->json([
                'success' => true,
                'message' => __('tenants.password_reset_successfully'),
                'data' => [
                    'tenant_id' => $tenant->id,
                    'new_password' => $request->has('password') ? null : $newPassword, // Only return if auto-generated
                ],
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Format tenant for list response.
     */
    private function formatTenant(Tenant $tenant): array
    {
        return [
            'id' => $tenant->id,
            'user_id' => $tenant->user_id,
            'name' => $tenant->user?->name,
            'email' => $tenant->user?->email,
            'phone' => $tenant->user?->phone,
            'unit_number' => $tenant->unit_number,
            'building_name' => $tenant->building_name,
            'full_address' => $tenant->full_address,
            'profile_photo_url' => $tenant->user?->profile_photo
                ? Storage::disk('public')->url($tenant->user->profile_photo)
                : null,
            'is_active' => $tenant->user?->is_active ?? false,
            'issues_count' => $tenant->issues_count ?? 0,
            'created_at' => $tenant->created_at?->format('Y-m-d\TH:i:s\Z'),
        ];
    }

    /**
     * Format tenant for detail response.
     */
    private function formatTenantDetail(Tenant $tenant): array
    {
        return [
            'id' => $tenant->id,
            'user_id' => $tenant->user_id,
            'name' => $tenant->user?->name,
            'email' => $tenant->user?->email,
            'phone' => $tenant->user?->phone,
            'unit_number' => $tenant->unit_number,
            'building_name' => $tenant->building_name,
            'full_address' => $tenant->full_address,
            'profile_photo_url' => $tenant->user?->profile_photo
                ? Storage::disk('public')->url($tenant->user->profile_photo)
                : null,
            'is_active' => $tenant->user?->is_active ?? false,
            'locale' => $tenant->user?->locale ?? 'en',
            'issues_count' => $tenant->issues_count ?? 0,
            'open_issues_count' => $tenant->open_issues_count ?? 0,
            'recent_issues' => $tenant->issues->map(fn ($issue) => [
                'id' => $issue->id,
                'title' => $issue->title,
                'status' => $issue->status->value,
                'status_label' => $issue->status->label(),
                'priority' => $issue->priority->value,
                'categories' => $issue->categories->pluck('name'),
                'created_at' => $issue->created_at->format('Y-m-d\TH:i:s\Z'),
            ]),
            'created_at' => $tenant->created_at?->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $tenant->updated_at?->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
