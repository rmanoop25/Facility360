<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class AdminCategoryController extends ApiController
{
    /**
     * List all categories with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        // Convert string booleans from query parameters to actual booleans
        $input = $request->all();
        foreach (['is_active', 'with_counts', 'all', 'nested', 'roots_only', 'include_archived'] as $field) {
            if (isset($input[$field]) && is_string($input[$field])) {
                $input[$field] = filter_var($input[$field], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            }
        }

        $validator = Validator::make($input, [
            'search' => ['nullable', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
            'with_counts' => ['nullable', 'boolean'],
            'sort_by' => ['nullable', 'string', Rule::in(['created_at', 'name_en', 'name_ar', 'is_active', 'depth', 'path'])],
            'sort_order' => ['nullable', 'string', Rule::in(['asc', 'desc'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
            'all' => ['nullable', 'boolean'],
            'nested' => ['nullable', 'boolean'],
            'roots_only' => ['nullable', 'boolean'],
            'parent_id' => ['nullable', 'integer', 'exists:categories,id'],
            'depth' => ['nullable', 'integer', 'min:0'],
            'include_archived' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $query = Category::query();

        // Include archived (soft deleted) categories if requested
        if ($request->boolean('include_archived', false)) {
            $query->withTrashed();
        }

        // Include counts if requested
        if ($request->boolean('with_counts', false)) {
            $query->withCount(['consumables', 'serviceProviders', 'issues', 'children']);
        }

        // Apply filters
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('name_en', 'like', "%{$search}%")
                    ->orWhere('name_ar', 'like', "%{$search}%");
            });
        }

        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        // Filter by parent
        if ($request->boolean('roots_only', false)) {
            $query->roots();
        } elseif ($request->filled('parent_id')) {
            $query->where('parent_id', $request->input('parent_id'));
        }

        // Filter by depth
        if ($request->filled('depth')) {
            $query->atDepth((int) $request->input('depth'));
        }

        // Apply sorting
        $sortBy = $request->input('sort_by', 'path'); // Default to hierarchy order
        $sortOrder = $request->input('sort_order', 'asc');
        $query->orderBy($sortBy, $sortOrder);

        // Load children for nested response
        if ($request->boolean('nested', false)) {
            $query->roots()->with(['allChildren']);
        }

        // Return all categories without pagination if requested
        if ($request->boolean('all', false)) {
            $categories = $query->get();

            return response()->json([
                'success' => true,
                'data' => CategoryResource::collection($categories),
            ]);
        }

        $perPage = $request->input('per_page', 15);
        $categories = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => CategoryResource::collection($categories->getCollection()),
            'meta' => [
                'current_page' => $categories->currentPage(),
                'last_page' => $categories->lastPage(),
                'per_page' => $categories->perPage(),
                'total' => $categories->total(),
            ],
        ]);
    }

    /**
     * Get category tree structure.
     */
    public function tree(Request $request): JsonResponse
    {
        $query = Category::roots()
            ->with(['allChildren'])
            ->withCount('children');

        if (! $request->boolean('include_inactive', false)) {
            $query->active();
        }

        $categories = $query->orderBy('name_en')->get();

        return response()->json([
            'success' => true,
            'data' => CategoryResource::collection($categories),
        ]);
    }

    /**
     * Create a new category.
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'parent_id' => ['nullable', 'integer', 'exists:categories,id'],
            'name_en' => ['required', 'string', 'max:255', 'unique:categories,name_en'],
            'name_ar' => ['required', 'string', 'max:255', 'unique:categories,name_ar'],
            'icon' => ['nullable', 'string', 'max:255'],
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
            $category = Category::create([
                'parent_id' => $request->input('parent_id'),
                'name_en' => $request->input('name_en'),
                'name_ar' => $request->input('name_ar'),
                'icon' => $request->input('icon'),
                'is_active' => $request->input('is_active', true),
            ]);

            // Reload with counts
            $category->loadCount(['children', 'consumables', 'serviceProviders', 'issues']);

            return response()->json([
                'success' => true,
                'message' => __('categories.created_successfully'),
                'data' => new CategoryResource($category),
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Get category details.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $query = Category::withCount(['consumables', 'serviceProviders', 'issues', 'children'])
            ->with('parent');

        // Include archived if requested
        if ($request->boolean('include_archived', false)) {
            $query->withTrashed();
        }

        $category = $query->find($id);

        if (! $category) {
            return response()->json([
                'success' => false,
                'message' => __('categories.not_found'),
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => new CategoryResource($category),
        ]);
    }

    /**
     * Get children of a category.
     */
    public function children(Request $request, int $id): JsonResponse
    {
        $category = Category::find($id);

        if (! $category) {
            return response()->json([
                'success' => false,
                'message' => __('categories.not_found'),
            ], 404);
        }

        $query = Category::where('parent_id', $id)
            ->withCount(['children', 'consumables', 'serviceProviders', 'issues'])
            ->orderBy('name_en');

        if (! $request->boolean('include_inactive', false)) {
            $query->active();
        }

        $children = $query->get();

        return response()->json([
            'success' => true,
            'data' => CategoryResource::collection($children),
        ]);
    }

    /**
     * Update category.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $category = Category::find($id);

        if (! $category) {
            return response()->json([
                'success' => false,
                'message' => __('categories.not_found'),
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'parent_id' => [
                'nullable',
                'integer',
                Rule::exists('categories', 'id')->whereNull('deleted_at'),
                // Prevent circular reference
                function ($attribute, $value, $fail) use ($category) {
                    if ($value === $category->id) {
                        $fail(__('categories.cannot_be_own_parent'));
                    }
                    if ($value) {
                        $potentialParent = Category::find($value);
                        if ($potentialParent && $potentialParent->isDescendantOf($category)) {
                            $fail(__('categories.cannot_move_to_descendant'));
                        }
                    }
                },
            ],
            'name_en' => ['sometimes', 'required', 'string', 'max:255', Rule::unique('categories')->ignore($id)],
            'name_ar' => ['sometimes', 'required', 'string', 'max:255', Rule::unique('categories')->ignore($id)],
            'icon' => ['nullable', 'string', 'max:255'],
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
            $updateData = [];

            if ($request->has('parent_id')) {
                $updateData['parent_id'] = $request->input('parent_id');
            }
            if ($request->has('name_en')) {
                $updateData['name_en'] = $request->input('name_en');
            }
            if ($request->has('name_ar')) {
                $updateData['name_ar'] = $request->input('name_ar');
            }
            if ($request->has('icon')) {
                $updateData['icon'] = $request->input('icon');
            }
            if ($request->has('is_active')) {
                $updateData['is_active'] = $request->boolean('is_active');
            }

            $category->update($updateData);

            // Reload with counts
            $category->loadCount(['children', 'consumables', 'serviceProviders', 'issues']);

            return response()->json([
                'success' => true,
                'message' => __('categories.updated_successfully'),
                'data' => new CategoryResource($category),
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
     * Archive (soft delete) category.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $category = Category::withCount(['consumables', 'serviceProviders', 'issues', 'children'])->find($id);

        if (! $category) {
            return response()->json([
                'success' => false,
                'message' => __('categories.not_found'),
            ], 404);
        }

        // Check for related records that would be affected
        if ($category->consumables_count > 0) {
            return response()->json([
                'success' => false,
                'message' => __('categories.has_consumables', ['count' => $category->consumables_count]),
            ], 422);
        }

        if ($category->service_providers_count > 0) {
            return response()->json([
                'success' => false,
                'message' => __('categories.has_service_providers', ['count' => $category->service_providers_count]),
            ], 422);
        }

        if ($category->issues_count > 0) {
            return response()->json([
                'success' => false,
                'message' => __('categories.has_issues', ['count' => $category->issues_count]),
            ], 422);
        }

        // Get descendants count
        $descendantsCount = Category::where('path', 'like', $category->path.'/%')->count();

        // If has children and not confirmed, return warning
        if ($descendantsCount > 0 && ! $request->boolean('confirm_cascade', false)) {
            return response()->json([
                'success' => false,
                'message' => __('categories.archive_warning_with_children', ['count' => $descendantsCount]),
                'requires_confirmation' => true,
                'descendants_count' => $descendantsCount,
            ], 422);
        }

        try {
            // Archive category and all descendants (soft delete)
            $category->archive();

            return response()->json([
                'success' => true,
                'message' => __('categories.archived_successfully'),
                'archived_count' => $descendantsCount + 1,
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
     * Restore archived category.
     */
    public function restore(Request $request, int $id): JsonResponse
    {
        $category = Category::withTrashed()->find($id);

        if (! $category) {
            return response()->json([
                'success' => false,
                'message' => __('categories.not_found'),
            ], 404);
        }

        if (! $category->trashed()) {
            return response()->json([
                'success' => false,
                'message' => __('categories.not_archived'),
            ], 422);
        }

        try {
            $includeDescendants = $request->boolean('include_descendants', true);
            $category->restoreWithDescendants($includeDescendants);

            // Count restored descendants
            $restoredCount = $includeDescendants
                ? Category::where('path', 'like', $category->path.'/%')->count() + 1
                : 1;

            return response()->json([
                'success' => true,
                'message' => __('categories.restored_successfully'),
                'restored_count' => $restoredCount,
                'data' => new CategoryResource($category->fresh()),
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
     * Move category to a new parent.
     */
    public function move(Request $request, int $id): JsonResponse
    {
        $category = Category::find($id);

        if (! $category) {
            return response()->json([
                'success' => false,
                'message' => __('categories.not_found'),
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'parent_id' => [
                'nullable',
                'integer',
                Rule::exists('categories', 'id')->whereNull('deleted_at'),
            ],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $newParentId = $request->input('parent_id');

        try {
            $newParent = $newParentId ? Category::find($newParentId) : null;
            $category->moveTo($newParent);

            return response()->json([
                'success' => true,
                'message' => __('categories.moved_successfully'),
                'data' => new CategoryResource($category->fresh()),
            ]);

        } catch (\InvalidArgumentException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 422);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }
}
