<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Models\Consumable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class AdminConsumableController extends ApiController
{
    /**
     * List all consumables with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'search' => ['nullable', 'string', 'max:255'],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'is_active' => ['nullable', 'boolean'],
            'sort_by' => ['nullable', 'string', Rule::in(['created_at', 'name_en', 'name_ar', 'category_id', 'is_active'])],
            'sort_order' => ['nullable', 'string', Rule::in(['asc', 'desc'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
            'all' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $query = Consumable::with('category:id,name_en,name_ar,icon');

        // Apply filters
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('name_en', 'like', "%{$search}%")
                    ->orWhere('name_ar', 'like', "%{$search}%");
            });
        }

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->input('category_id'));
        }

        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        // Apply sorting
        $sortBy = $request->input('sort_by', 'created_at');
        $sortOrder = $request->input('sort_order', 'desc');
        $query->orderBy($sortBy, $sortOrder);

        // Return all consumables without pagination if requested
        if ($request->boolean('all', false)) {
            $consumables = $query->get();

            return response()->json([
                'success' => true,
                'data' => $consumables->map(fn ($consumable) => $this->formatConsumable($consumable)),
            ]);
        }

        $perPage = $request->input('per_page', 15);
        $consumables = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $consumables->getCollection()->map(fn ($consumable) => $this->formatConsumable($consumable)),
            'meta' => [
                'current_page' => $consumables->currentPage(),
                'last_page' => $consumables->lastPage(),
                'per_page' => $consumables->perPage(),
                'total' => $consumables->total(),
            ],
        ]);
    }

    /**
     * Create a new consumable.
     */
    public function store(Request $request): JsonResponse
    {
        // DEBUG: Write to file to confirm method is called
        file_put_contents(storage_path('logs/debug.txt'),
            date('Y-m-d H:i:s')." - STORE CALLED\n".
            'Request All: '.json_encode($request->all())."\n".
            'Raw Input: '.file_get_contents('php://input')."\n\n",
            FILE_APPEND
        );

        $validator = Validator::make($request->all(), [
            'category_id' => ['required', 'integer', 'exists:categories,id'],
            'name_en' => ['required', 'string', 'max:255'],
            'name_ar' => ['required', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        // Check for duplicate name within the same category
        $exists = Consumable::where('category_id', $request->input('category_id'))
            ->where(function ($q) use ($request) {
                $q->where('name_en', $request->input('name_en'))
                    ->orWhere('name_ar', $request->input('name_ar'));
            })
            ->exists();

        if ($exists) {
            return response()->json([
                'success' => false,
                'message' => __('consumables.duplicate_name'),
                'errors' => [
                    'name_en' => [__('consumables.name_exists_in_category')],
                ],
            ], 422);
        }

        // Debug: Log request data to investigate missing category_id
        \Log::info('Creating consumable - Request data', [
            'request_all' => $request->all(),
            'category_id_input' => $request->input('category_id'),
            'category_id_type' => gettype($request->input('category_id')),
            'has_category_id' => $request->has('category_id'),
            'filled_category_id' => $request->filled('category_id'),
        ]);

        try {
            $consumable = Consumable::create([
                'category_id' => $request->input('category_id'),
                'name_en' => $request->input('name_en'),
                'name_ar' => $request->input('name_ar'),
                'is_active' => $request->input('is_active', true),
            ]);

            $consumable->load('category:id,name_en,name_ar,icon');

            return response()->json([
                'success' => true,
                'message' => __('consumables.created_successfully'),
                'data' => $this->formatConsumable($consumable),
            ], 201);

        } catch (\Exception $e) {
            // Log the full exception for debugging
            \Log::error('Failed to create consumable', [
                'exception' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Failed to create consumable.',
                'errors' => [
                    'exception' => $e->getMessage(),
                ],
            ], 500);
        }
    }

    /**
     * Get consumable details.
     */
    public function show(int $id): JsonResponse
    {
        $consumable = Consumable::with('category:id,name_en,name_ar,icon')
            ->withCount('assignmentConsumables as usage_count')
            ->find($id);

        if (! $consumable) {
            return response()->json([
                'success' => false,
                'message' => __('consumables.not_found'),
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatConsumable($consumable),
        ]);
    }

    /**
     * Update consumable.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $consumable = Consumable::find($id);

        if (! $consumable) {
            return response()->json([
                'success' => false,
                'message' => __('consumables.not_found'),
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'category_id' => ['sometimes', 'required', 'integer', 'exists:categories,id'],
            'name_en' => ['sometimes', 'required', 'string', 'max:255'],
            'name_ar' => ['sometimes', 'required', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        // Check for duplicate name within the same category (excluding current record)
        $categoryId = $request->input('category_id', $consumable->category_id);
        $nameEn = $request->input('name_en', $consumable->name_en);
        $nameAr = $request->input('name_ar', $consumable->name_ar);

        $exists = Consumable::where('category_id', $categoryId)
            ->where('id', '!=', $id)
            ->where(function ($q) use ($nameEn, $nameAr) {
                $q->where('name_en', $nameEn)
                    ->orWhere('name_ar', $nameAr);
            })
            ->exists();

        if ($exists) {
            return response()->json([
                'success' => false,
                'message' => __('consumables.duplicate_name'),
                'errors' => [
                    'name_en' => [__('consumables.name_exists_in_category')],
                ],
            ], 422);
        }

        try {
            $updateData = [];

            if ($request->has('category_id')) {
                $updateData['category_id'] = $request->input('category_id');
            }
            if ($request->has('name_en')) {
                $updateData['name_en'] = $request->input('name_en');
            }
            if ($request->has('name_ar')) {
                $updateData['name_ar'] = $request->input('name_ar');
            }
            if ($request->has('is_active')) {
                $updateData['is_active'] = $request->boolean('is_active');
            }

            $consumable->update($updateData);
            $consumable->load('category:id,name_en,name_ar,icon');

            return response()->json([
                'success' => true,
                'message' => __('consumables.updated_successfully'),
                'data' => $this->formatConsumable($consumable),
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
     * Delete consumable.
     */
    public function destroy(int $id): JsonResponse
    {
        $consumable = Consumable::withCount('assignmentConsumables as usage_count')->find($id);

        if (! $consumable) {
            return response()->json([
                'success' => false,
                'message' => __('consumables.not_found'),
            ], 404);
        }

        // Check if consumable has been used in assignments
        if ($consumable->usage_count > 0) {
            return response()->json([
                'success' => false,
                'message' => __('consumables.has_usage_records', ['count' => $consumable->usage_count]),
            ], 422);
        }

        try {
            $consumable->delete();

            return response()->json([
                'success' => true,
                'message' => __('consumables.deleted_successfully'),
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
     * Format consumable for response.
     */
    private function formatConsumable(Consumable $consumable): array
    {
        $data = [
            'id' => $consumable->id,
            'category_id' => $consumable->category_id,
            'category' => $consumable->category ? [
                'id' => $consumable->category->id,
                'name' => $consumable->category->name,
                'name_en' => $consumable->category->name_en,
                'name_ar' => $consumable->category->name_ar,
                'icon' => $consumable->category->icon,
            ] : null,
            'name' => $consumable->name,
            'name_en' => $consumable->name_en,
            'name_ar' => $consumable->name_ar,
            'is_active' => $consumable->is_active,
            'created_at' => $consumable->created_at?->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $consumable->updated_at?->format('Y-m-d\TH:i:s\Z'),
        ];

        // Include usage count if loaded
        if (isset($consumable->usage_count)) {
            $data['usage_count'] = $consumable->usage_count;
        }

        return $data;
    }
}
