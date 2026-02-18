<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Models\Consumable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConsumableController extends ApiController
{
    /**
     * List consumables with optional category filter.
     */
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
        ]);

        $query = Consumable::query()
            ->with('category')
            ->active()
            ->orderBy('name_en');

        // Filter by category if provided
        if (!empty($validated['category_id'])) {
            $query->forCategory((int) $validated['category_id']);
        }

        $consumables = $query->get();

        $data = $consumables->map(fn (Consumable $consumable) => [
            'id' => $consumable->id,
            'name' => $consumable->name,
            'name_en' => $consumable->name_en,
            'name_ar' => $consumable->name_ar,
            'category' => $consumable->category ? [
                'id' => $consumable->category->id,
                'name' => $consumable->category->name,
            ] : null,
        ]);

        return $this->success($data, __('api.consumables.list_success'));
    }
}
