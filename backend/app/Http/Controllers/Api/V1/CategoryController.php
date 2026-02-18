<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\CategoryResource;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CategoryController extends ApiController
{
    /**
     * List all active categories.
     *
     * Query parameters:
     * - nested: bool - Return nested tree structure (default: false)
     * - roots_only: bool - Return only root categories (default: false)
     * - include_leaf_info: bool - Include is_leaf field (default: false)
     * - include_children_info: bool - Include has_children field (default: false)
     * - with_consumables_count: bool - Include consumables count
     */
    public function index(Request $request): JsonResponse
    {
        $query = Category::query()
            ->active();

        // Filter roots only if requested
        if ($request->boolean('roots_only', false)) {
            $query->roots();
        }

        // Order by hierarchy for proper tree display
        $query->orderByHierarchy();

        // Optional: include consumables count
        if ($request->boolean('with_consumables_count')) {
            $query->withCount(['consumables' => function ($q) {
                $q->active();
            }]);
        }

        // Include children count
        if ($request->boolean('include_children_info') || $request->boolean('nested')) {
            $query->withCount('children');
        }

        // Load children for nested response
        if ($request->boolean('nested', false)) {
            $query->roots()->with(['allActiveChildren']);
        }

        $categories = $query->get();

        // Use resource for response
        return $this->success(
            CategoryResource::collection($categories),
            __('api.categories.list_success')
        );
    }

    /**
     * Get children of a specific category.
     */
    public function children(Request $request, int $parentId): JsonResponse
    {
        $parent = Category::active()->find($parentId);

        if (! $parent) {
            return $this->error(__('categories.not_found'), 404);
        }

        $query = Category::query()
            ->active()
            ->where('parent_id', $parentId)
            ->orderBy('name_en');

        if ($request->boolean('include_children_info')) {
            $query->withCount('children');
        }

        $children = $query->get();

        return $this->success(
            CategoryResource::collection($children),
            __('api.categories.children_success')
        );
    }

    /**
     * Get category tree structure.
     */
    public function tree(Request $request): JsonResponse
    {
        $categories = Category::active()
            ->roots()
            ->with(['allActiveChildren'])
            ->withCount('children')
            ->orderBy('name_en')
            ->get();

        return $this->success(
            CategoryResource::collection($categories),
            __('api.categories.tree_success')
        );
    }
}
