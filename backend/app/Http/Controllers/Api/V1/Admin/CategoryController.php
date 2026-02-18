<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CategoryController extends ApiController
{
    /**
     * List all categories.
     */
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Category::withCount(['issues', 'serviceProviders', 'consumables'])
            ->orderBy('name_en');

        if ($request->filled('search')) {
            $search = $validated['search'];
            $query->where(function ($q) use ($search) {
                $q->where('name_en', 'like', "%{$search}%")
                    ->orWhere('name_ar', 'like', "%{$search}%");
            });
        }

        if ($request->has('is_active')) {
            $query->where('is_active', $validated['is_active']);
        }

        $perPage = $validated['per_page'] ?? 50;
        $categories = $query->paginate($perPage);

        // Transform to include counts explicitly
        $transformed = $categories->through(function ($category) use ($request) {
            $locale = $request->header('Accept-Language', app()->getLocale());

            return [
                'id' => $category->id,
                'name' => $locale === 'ar' ? $category->name_ar : $category->name_en,
                'name_en' => $category->name_en,
                'name_ar' => $category->name_ar,
                'icon' => $category->icon,
                'is_active' => $category->is_active,
                'created_at' => $category->created_at?->toIso8601String(),
                'updated_at' => $category->updated_at?->toIso8601String(),
                'consumables_count' => $category->consumables_count ?? 0,
                'service_providers_count' => $category->service_providers_count ?? 0,
                'issues_count' => $category->issues_count ?? 0,
            ];
        });

        return $this->paginated($transformed, __('api.categories.list_success'));
    }

    /**
     * Create a new category.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name_en' => ['required', 'string', 'max:255'],
            'name_ar' => ['required', 'string', 'max:255'],
            'icon' => ['nullable', 'string', 'max:50'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        try {
            $category = Category::create([
                'name_en' => $validated['name_en'],
                'name_ar' => $validated['name_ar'],
                'icon' => $validated['icon'] ?? null,
                'is_active' => $validated['is_active'] ?? true,
            ]);

            return $this->created($category, __('api.categories.created_success'));
        } catch (\Exception $e) {
            return $this->error(
                __('api.categories.create_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Update a category.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $category = Category::find($id);

        if (! $category) {
            return $this->notFound(__('api.categories.not_found'));
        }

        $validated = $request->validate([
            'name_en' => ['sometimes', 'string', 'max:255'],
            'name_ar' => ['sometimes', 'string', 'max:255'],
            'icon' => ['nullable', 'string', 'max:50'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        try {
            $category->update($validated);

            return $this->success($category, __('api.categories.updated_success'));
        } catch (\Exception $e) {
            return $this->error(
                __('api.categories.update_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Delete a category.
     */
    public function destroy(int $id): JsonResponse
    {
        $category = Category::withCount(['issues', 'serviceProviders'])->find($id);

        if (! $category) {
            return $this->notFound(__('api.categories.not_found'));
        }

        // Check if category is in use
        if ($category->issues_count > 0 || $category->service_providers_count > 0) {
            return $this->error(
                __('api.categories.in_use'),
                422
            );
        }

        try {
            $category->delete();

            return $this->success(null, __('api.categories.deleted_success'));
        } catch (\Exception $e) {
            return $this->error(
                __('api.categories.delete_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }
}
