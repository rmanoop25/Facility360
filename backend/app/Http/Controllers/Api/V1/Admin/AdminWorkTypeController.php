<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Models\WorkType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class AdminWorkTypeController extends ApiController
{
    /**
     * Display a listing of work types.
     */
    public function index(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'search' => ['nullable', 'string', 'max:255'],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'is_active' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $query = WorkType::with(['categories:id,name_en,name_ar,icon'])
            ->withCount('assignments');

        // Apply filters
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('name_en', 'like', "%{$search}%")
                    ->orWhere('name_ar', 'like', "%{$search}%");
            });
        }

        if ($request->filled('category_id')) {
            $query->forCategory($request->input('category_id'));
        }

        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        $perPage = $request->input('per_page', 15);
        $workTypes = $query->orderBy('name_en')->paginate($perPage);

        $data = $workTypes->getCollection()->map(fn ($wt) => $this->formatWorkType($wt));

        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => [
                'current_page' => $workTypes->currentPage(),
                'last_page' => $workTypes->lastPage(),
                'per_page' => $workTypes->perPage(),
                'total' => $workTypes->total(),
            ],
        ]);
    }

    /**
     * Store a newly created work type.
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name_en' => ['required', 'string', 'max:255'],
            'name_ar' => ['required', 'string', 'max:255'],
            'description_en' => ['nullable', 'string', 'max:2000'],
            'description_ar' => ['nullable', 'string', 'max:2000'],
            'duration_minutes' => ['required', 'integer', 'min:15', 'max:480'], // 15min to 8 hours
            'category_ids' => ['required', 'array', 'min:1'],
            'category_ids.*' => ['required', 'integer', 'exists:categories,id'],
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

            $workType = WorkType::create([
                'name_en' => $request->input('name_en'),
                'name_ar' => $request->input('name_ar'),
                'description_en' => $request->input('description_en'),
                'description_ar' => $request->input('description_ar'),
                'duration_minutes' => $request->input('duration_minutes'),
                'is_active' => $request->input('is_active', true),
            ]);

            // Attach categories
            $workType->categories()->attach($request->input('category_ids'));

            $workType->load(['categories:id,name_en,name_ar,icon']);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('work_types.created_successfully'),
                'data' => $this->formatWorkTypeDetail($workType),
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
     * Display the specified work type.
     */
    public function show(int $id): JsonResponse
    {
        $workType = WorkType::with(['categories:id,name_en,name_ar,icon'])
            ->withCount('assignments')
            ->find($id);

        if (! $workType) {
            return response()->json([
                'success' => false,
                'message' => __('work_types.not_found'),
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatWorkTypeDetail($workType),
        ]);
    }

    /**
     * Update the specified work type.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $workType = WorkType::find($id);

        if (! $workType) {
            return response()->json([
                'success' => false,
                'message' => __('work_types.not_found'),
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'name_en' => ['sometimes', 'required', 'string', 'max:255'],
            'name_ar' => ['sometimes', 'required', 'string', 'max:255'],
            'description_en' => ['nullable', 'string', 'max:2000'],
            'description_ar' => ['nullable', 'string', 'max:2000'],
            'duration_minutes' => ['sometimes', 'required', 'integer', 'min:15', 'max:480'],
            'category_ids' => ['sometimes', 'required', 'array', 'min:1'],
            'category_ids.*' => ['required', 'integer', 'exists:categories,id'],
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

            $workType->update($request->only([
                'name_en', 'name_ar', 'description_en', 'description_ar',
                'duration_minutes', 'is_active',
            ]));

            if ($request->has('category_ids')) {
                $workType->categories()->sync($request->input('category_ids'));
            }

            $workType->load(['categories:id,name_en,name_ar,icon']);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('work_types.updated_successfully'),
                'data' => $this->formatWorkTypeDetail($workType),
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
     * Remove the specified work type.
     */
    public function destroy(int $id): JsonResponse
    {
        $workType = WorkType::withCount('assignments')->find($id);

        if (! $workType) {
            return response()->json([
                'success' => false,
                'message' => __('work_types.not_found'),
            ], 404);
        }

        if ($workType->assignments_count > 0) {
            return response()->json([
                'success' => false,
                'message' => __('work_types.has_assignments', ['count' => $workType->assignments_count]),
            ], 422);
        }

        try {
            DB::beginTransaction();

            $workType->categories()->detach();
            $workType->delete();

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('work_types.deleted_successfully'),
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
     * Format work type for list view.
     */
    private function formatWorkType(WorkType $wt): array
    {
        return [
            'id' => $wt->id,
            'name_en' => $wt->name_en,
            'name_ar' => $wt->name_ar,
            'duration_minutes' => $wt->duration_minutes,
            'formatted_duration' => $wt->formatted_duration,
            'categories' => $wt->categories->map(fn ($c) => [
                'id' => $c->id,
                'name_en' => $c->name_en,
                'name_ar' => $c->name_ar,
                'icon' => $c->icon,
            ]),
            'is_active' => $wt->is_active,
            'assignments_count' => $wt->assignments_count ?? 0,
        ];
    }

    /**
     * Format work type for detail view.
     */
    private function formatWorkTypeDetail(WorkType $wt): array
    {
        return [
            'id' => $wt->id,
            'name_en' => $wt->name_en,
            'name_ar' => $wt->name_ar,
            'description_en' => $wt->description_en,
            'description_ar' => $wt->description_ar,
            'duration_minutes' => $wt->duration_minutes,
            'duration_hours' => $wt->duration_hours,
            'formatted_duration' => $wt->formatted_duration,
            'categories' => $wt->categories->map(fn ($c) => [
                'id' => $c->id,
                'name_en' => $c->name_en,
                'name_ar' => $c->name_ar,
                'icon' => $c->icon,
            ]),
            'is_active' => $wt->is_active,
            'assignments_count' => $wt->assignments_count ?? 0,
            'created_at' => $wt->created_at?->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $wt->updated_at?->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
