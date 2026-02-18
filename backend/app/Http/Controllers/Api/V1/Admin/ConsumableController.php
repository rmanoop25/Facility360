<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Models\Consumable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConsumableController extends ApiController
{
    /**
     * List all consumables.
     */
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Consumable::orderBy('name_en');

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
        $consumables = $query->paginate($perPage);

        return $this->paginated($consumables, __('api.consumables.list_success'));
    }

    /**
     * Create a new consumable.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category_id' => ['required', 'integer', 'exists:categories,id'],
            'name_en' => ['required', 'string', 'max:255'],
            'name_ar' => ['required', 'string', 'max:255'],
            'unit' => ['nullable', 'string', 'max:50'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        try {
            $consumable = Consumable::create([
                'category_id' => $validated['category_id'],
                'name_en' => $validated['name_en'],
                'name_ar' => $validated['name_ar'],
                'unit' => $validated['unit'] ?? null,
                'is_active' => $validated['is_active'] ?? true,
            ]);

            return $this->created($consumable, __('api.consumables.created_success'));
        } catch (\Exception $e) {
            return $this->error(
                __('api.consumables.create_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Update a consumable.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $consumable = Consumable::find($id);

        if (! $consumable) {
            return $this->notFound(__('api.consumables.not_found'));
        }

        $validated = $request->validate([
            'category_id' => ['sometimes', 'integer', 'exists:categories,id'],
            'name_en' => ['sometimes', 'string', 'max:255'],
            'name_ar' => ['sometimes', 'string', 'max:255'],
            'unit' => ['nullable', 'string', 'max:50'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        try {
            $consumable->update($validated);

            return $this->success($consumable, __('api.consumables.updated_success'));
        } catch (\Exception $e) {
            return $this->error(
                __('api.consumables.update_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Delete a consumable.
     */
    public function destroy(int $id): JsonResponse
    {
        $consumable = Consumable::find($id);

        if (! $consumable) {
            return $this->notFound(__('api.consumables.not_found'));
        }

        try {
            $consumable->delete();

            return $this->success(null, __('api.consumables.deleted_success'));
        } catch (\Exception $e) {
            return $this->error(
                __('api.consumables.delete_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }
}
