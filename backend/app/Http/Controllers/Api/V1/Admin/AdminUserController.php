<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AdminUserController extends ApiController
{
    /**
     * List all admin users with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        // Check permission
        if (!$request->user()->can('viewAny', User::class)) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'search' => ['nullable', 'string', 'max:255'],
            'role' => ['nullable', 'string', Rule::in(['super_admin', 'manager', 'viewer'])],
            'is_active' => ['nullable', 'boolean'],
            'sort_by' => ['nullable', 'string', Rule::in(['created_at', 'name', 'email'])],
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

        $query = User::with('roles')
            ->whereHas('roles', fn ($q) => $q->whereIn('name', ['super_admin', 'manager', 'viewer']));

        // Apply filters
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        if ($request->filled('role')) {
            $query->whereHas('roles', fn ($q) => $q->where('name', $request->input('role')));
        }

        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        // Apply sorting
        $sortBy = $request->input('sort_by', 'created_at');
        $sortOrder = $request->input('sort_order', 'desc');
        $query->orderBy($sortBy, $sortOrder);

        $perPage = $request->input('per_page', 15);
        $users = $query->paginate($perPage);

        $data = $users->getCollection()->map(fn ($user) => $this->formatUser($user));

        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    /**
     * Create a new admin user.
     */
    public function store(Request $request): JsonResponse
    {
        // Check permission
        if (!$request->user()->can('create', User::class)) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::min(8)->mixedCase()->numbers()],
            'phone' => ['nullable', 'string', 'max:20'],
            'role' => ['required', 'string', Rule::in(['super_admin', 'manager', 'viewer'])],
            'is_active' => ['nullable', 'boolean'],
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

            $user = User::create([
                'name' => $request->input('name'),
                'email' => $request->input('email'),
                'password' => Hash::make($request->input('password')),
                'phone' => $request->input('phone'),
                'is_active' => $request->input('is_active', true),
            ]);

            $user->assignRole($request->input('role'));

            $user->load('roles');

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('admin_users.messages.created'),
                'data' => $this->formatUser($user),
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
     * Get admin user details.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $user = User::with('roles')
            ->whereHas('roles', fn ($q) => $q->whereIn('name', ['super_admin', 'manager', 'viewer']))
            ->find($id);

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => __('common.not_found'),
            ], 404);
        }

        // Check permission
        if (!$request->user()->can('view', $user)) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatUser($user),
        ]);
    }

    /**
     * Update admin user.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $user = User::with('roles')
            ->whereHas('roles', fn ($q) => $q->whereIn('name', ['super_admin', 'manager', 'viewer']))
            ->find($id);

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => __('common.not_found'),
            ], 404);
        }

        // Check permission
        if (!$request->user()->can('update', $user)) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['sometimes', 'required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($id)],
            'phone' => ['nullable', 'string', 'max:20'],
            'role' => ['sometimes', 'required', 'string', Rule::in(['super_admin', 'manager', 'viewer'])],
            'is_active' => ['nullable', 'boolean'],
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

            $updateData = [];
            if ($request->has('name')) $updateData['name'] = $request->input('name');
            if ($request->has('email')) $updateData['email'] = $request->input('email');
            if ($request->has('phone')) $updateData['phone'] = $request->input('phone');
            if ($request->has('is_active')) $updateData['is_active'] = $request->boolean('is_active');

            if (!empty($updateData)) {
                $user->update($updateData);
            }

            if ($request->has('role')) {
                $user->syncRoles([$request->input('role')]);
            }

            $user->refresh();
            $user->load('roles');

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('admin_users.messages.updated'),
                'data' => $this->formatUser($user),
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
     * Delete admin user.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $user = User::with('roles')
            ->whereHas('roles', fn ($q) => $q->whereIn('name', ['super_admin', 'manager', 'viewer']))
            ->find($id);

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => __('common.not_found'),
            ], 404);
        }

        // Check permission
        if (!$request->user()->can('delete', $user)) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        // Prevent deleting self
        if ($user->id === auth()->id()) {
            return response()->json([
                'success' => false,
                'message' => __('admin_users.messages.cannot_delete_self'),
            ], 422);
        }

        try {
            $user->delete();

            return response()->json([
                'success' => true,
                'message' => __('admin_users.messages.deleted'),
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
     * Reset admin user password.
     */
    public function resetPassword(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'password' => ['required', 'string', Password::min(8)->mixedCase()->numbers(), 'confirmed'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = User::with('roles')
            ->whereHas('roles', fn ($q) => $q->whereIn('name', ['super_admin', 'manager', 'viewer']))
            ->find($id);

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => __('common.not_found'),
            ], 404);
        }

        $user->update([
            'password' => Hash::make($request->input('password')),
        ]);

        return response()->json([
            'success' => true,
            'message' => __('admin_users.messages.password_reset'),
        ]);
    }

    /**
     * Toggle admin user active status.
     */
    public function toggleActive(int $id): JsonResponse
    {
        $user = User::with('roles')
            ->whereHas('roles', fn ($q) => $q->whereIn('name', ['super_admin', 'manager', 'viewer']))
            ->find($id);

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => __('common.not_found'),
            ], 404);
        }

        // Prevent deactivating self
        if ($user->id === auth()->id()) {
            return response()->json([
                'success' => false,
                'message' => __('admin_users.messages.cannot_deactivate_self'),
            ], 422);
        }

        $user->update([
            'is_active' => !$user->is_active,
        ]);

        return response()->json([
            'success' => true,
            'message' => $user->is_active
                ? __('admin_users.messages.activated')
                : __('admin_users.messages.deactivated'),
            'data' => [
                'id' => $user->id,
                'is_active' => $user->is_active,
            ],
        ]);
    }

    /**
     * Format user for response.
     */
    private function formatUser(User $user): array
    {
        $role = $user->roles->first()?->name;

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $role,
            'role_label' => $role ? __("admin_users.roles.{$role}") : null,
            'is_active' => $user->is_active,
            'created_at' => $user->created_at?->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $user->updated_at?->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
