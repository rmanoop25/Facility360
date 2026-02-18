<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Models\Category;
use App\Models\Consumable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class SyncController extends ApiController
{
    /**
     * Cache TTL in seconds (1 hour).
     */
    private const CACHE_TTL = 3600;

    /**
     * Get master data for mobile caching.
     * Returns all categories and consumables with last update timestamps.
     */
    public function masterData(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'since' => ['nullable', 'date'],
            'include' => ['nullable', 'string'], // comma-separated: categories,consumables
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $since = $request->input('since') ? \Carbon\Carbon::parse($request->input('since')) : null;
        $includes = $request->filled('include')
            ? explode(',', $request->input('include'))
            : ['categories', 'consumables'];

        $data = [];
        $lastUpdated = null;

        // Get categories
        if (in_array('categories', $includes)) {
            $categoriesQuery = Category::active();
            if ($since) {
                $categoriesQuery->where('updated_at', '>', $since);
            }

            $categories = $categoriesQuery->orderBy('name_en')->get();
            $data['categories'] = $categories->map(fn ($cat) => [
                'id' => $cat->id,
                'name_en' => $cat->name_en,
                'name_ar' => $cat->name_ar,
                'icon' => $cat->icon,
                'updated_at' => $cat->updated_at?->format('Y-m-d\TH:i:s\Z'),
            ]);

            $latestCategory = Category::active()->max('updated_at');
            if ($latestCategory && (!$lastUpdated || $latestCategory > $lastUpdated)) {
                $lastUpdated = $latestCategory;
            }
        }

        // Get consumables
        if (in_array('consumables', $includes)) {
            $consumablesQuery = Consumable::active()->with('category:id,name_en,name_ar');
            if ($since) {
                $consumablesQuery->where('updated_at', '>', $since);
            }

            $consumables = $consumablesQuery->orderBy('category_id')->orderBy('name_en')->get();
            $data['consumables'] = $consumables->map(fn ($c) => [
                'id' => $c->id,
                'category_id' => $c->category_id,
                'name_en' => $c->name_en,
                'name_ar' => $c->name_ar,
                'updated_at' => $c->updated_at?->format('Y-m-d\TH:i:s\Z'),
            ]);

            $latestConsumable = Consumable::active()->max('updated_at');
            if ($latestConsumable && (!$lastUpdated || $latestConsumable > $lastUpdated)) {
                $lastUpdated = $latestConsumable;
            }
        }

        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => [
                'last_updated' => $lastUpdated?->format('Y-m-d\TH:i:s\Z'),
                'fetched_at' => now()->format('Y-m-d\TH:i:s\Z'),
                'is_incremental' => $since !== null,
            ],
        ]);
    }

    /**
     * Handle batch sync of offline mutations.
     * Processes multiple operations in a single request.
     */
    public function batch(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'operations' => ['required', 'array', 'min:1', 'max:100'],
            'operations.*.id' => ['required', 'string', 'max:36'], // Client-generated UUID for idempotency
            'operations.*.entity' => ['required', 'string', 'in:issue,issue_assignment'],
            'operations.*.action' => ['required', 'string', 'in:create,update,delete'],
            'operations.*.data' => ['required', 'array'],
            'operations.*.timestamp' => ['required', 'date'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $operations = $request->input('operations');
        $results = [];
        $successCount = 0;
        $failureCount = 0;

        foreach ($operations as $operation) {
            $operationId = $operation['id'];

            // Check for duplicate operation (idempotency)
            $cacheKey = "sync_operation:{$operationId}";
            if (Cache::has($cacheKey)) {
                $results[] = [
                    'operation_id' => $operationId,
                    'status' => 'duplicate',
                    'message' => __('sync.operation_already_processed'),
                    'cached_result' => Cache::get($cacheKey),
                ];
                continue;
            }

            try {
                DB::beginTransaction();

                $result = $this->processOperation($operation);

                DB::commit();

                // Cache the result for idempotency (24 hours)
                Cache::put($cacheKey, $result, 86400);

                $results[] = [
                    'operation_id' => $operationId,
                    'status' => 'success',
                    'result' => $result,
                ];
                $successCount++;

            } catch (\Illuminate\Validation\ValidationException $e) {
                DB::rollBack();

                $results[] = [
                    'operation_id' => $operationId,
                    'status' => 'validation_error',
                    'message' => $e->getMessage(),
                    'errors' => $e->errors(),
                ];
                $failureCount++;

            } catch (\Exception $e) {
                DB::rollBack();

                $results[] = [
                    'operation_id' => $operationId,
                    'status' => 'error',
                    'message' => config('app.debug') ? $e->getMessage() : __('common.operation_failed'),
                ];
                $failureCount++;
            }
        }

        return response()->json([
            'success' => $failureCount === 0,
            'data' => [
                'results' => $results,
                'summary' => [
                    'total' => count($operations),
                    'success' => $successCount,
                    'failed' => $failureCount,
                    'duplicates' => count($operations) - $successCount - $failureCount,
                ],
            ],
        ], $failureCount > 0 && $successCount === 0 ? 422 : 200);
    }

    /**
     * Process a single sync operation.
     */
    private function processOperation(array $operation): array
    {
        $entity = $operation['entity'];
        $action = $operation['action'];
        $data = $operation['data'];
        $timestamp = \Carbon\Carbon::parse($operation['timestamp']);

        return match ($entity) {
            'issue' => $this->processIssueOperation($action, $data, $timestamp),
            'issue_assignment' => $this->processAssignmentOperation($action, $data, $timestamp),
            default => throw new \InvalidArgumentException("Unsupported entity: {$entity}"),
        };
    }

    /**
     * Process issue-related operations.
     */
    private function processIssueOperation(string $action, array $data, \Carbon\Carbon $timestamp): array
    {
        $issueClass = \App\Models\Issue::class;

        return match ($action) {
            'create' => $this->createIssueFromSync($data, $timestamp),
            'update' => $this->updateIssueFromSync($data, $timestamp),
            'delete' => $this->deleteIssueFromSync($data),
            default => throw new \InvalidArgumentException("Unsupported action: {$action}"),
        };
    }

    /**
     * Process assignment-related operations.
     */
    private function processAssignmentOperation(string $action, array $data, \Carbon\Carbon $timestamp): array
    {
        return match ($action) {
            'update' => $this->updateAssignmentFromSync($data, $timestamp),
            default => throw new \InvalidArgumentException("Unsupported action for assignment: {$action}"),
        };
    }

    /**
     * Create issue from sync data.
     */
    private function createIssueFromSync(array $data, \Carbon\Carbon $timestamp): array
    {
        $validator = Validator::make($data, [
            'tenant_id' => ['required', 'exists:tenants,id'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'priority' => ['required', 'string', 'in:low,medium,high'],
            'category_ids' => ['nullable', 'array'],
            'category_ids.*' => ['integer', 'exists:categories,id'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
        ]);

        if ($validator->fails()) {
            throw new \Illuminate\Validation\ValidationException($validator);
        }

        $issue = \App\Models\Issue::create([
            'tenant_id' => $data['tenant_id'],
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'priority' => $data['priority'],
            'status' => \App\Enums\IssueStatus::PENDING,
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
            'created_at' => $timestamp,
        ]);

        if (!empty($data['category_ids'])) {
            $issue->categories()->attach($data['category_ids']);
        }

        // Create timeline entry
        \App\Models\IssueTimeline::create([
            'issue_id' => $issue->id,
            'action' => \App\Enums\TimelineAction::CREATED,
            'performed_by' => auth()->id(),
            'metadata' => ['synced' => true, 'original_timestamp' => $timestamp->format('Y-m-d\TH:i:s\Z')],
            'created_at' => $timestamp,
        ]);

        return [
            'entity_id' => $issue->id,
            'created_at' => $issue->created_at->format('Y-m-d\TH:i:s\Z'),
        ];
    }

    /**
     * Update issue from sync data.
     */
    private function updateIssueFromSync(array $data, \Carbon\Carbon $timestamp): array
    {
        $validator = Validator::make($data, [
            'id' => ['required', 'exists:issues,id'],
            'title' => ['sometimes', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'priority' => ['sometimes', 'string', 'in:low,medium,high'],
        ]);

        if ($validator->fails()) {
            throw new \Illuminate\Validation\ValidationException($validator);
        }

        $issue = \App\Models\Issue::findOrFail($data['id']);

        // Only update if sync timestamp is newer than last update
        if ($timestamp->lessThan($issue->updated_at)) {
            return [
                'entity_id' => $issue->id,
                'skipped' => true,
                'reason' => 'Server has newer data',
            ];
        }

        $updateData = array_filter([
            'title' => $data['title'] ?? null,
            'description' => $data['description'] ?? null,
            'priority' => $data['priority'] ?? null,
        ], fn ($v) => $v !== null);

        $issue->update($updateData);

        return [
            'entity_id' => $issue->id,
            'updated_at' => $issue->updated_at->format('Y-m-d\TH:i:s\Z'),
        ];
    }

    /**
     * Delete issue from sync data (soft cancel).
     */
    private function deleteIssueFromSync(array $data): array
    {
        $validator = Validator::make($data, [
            'id' => ['required', 'exists:issues,id'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        if ($validator->fails()) {
            throw new \Illuminate\Validation\ValidationException($validator);
        }

        $issue = \App\Models\Issue::findOrFail($data['id']);

        if (!$issue->canBeCancelled()) {
            throw new \Exception(__('issues.cannot_cancel'));
        }

        $issue->update([
            'status' => \App\Enums\IssueStatus::CANCELLED,
            'cancelled_reason' => $data['reason'],
            'cancelled_by' => auth()->id(),
            'cancelled_at' => now(),
        ]);

        return [
            'entity_id' => $issue->id,
            'cancelled' => true,
        ];
    }

    /**
     * Update assignment from sync data (e.g., SP status updates).
     */
    private function updateAssignmentFromSync(array $data, \Carbon\Carbon $timestamp): array
    {
        $validator = Validator::make($data, [
            'id' => ['required', 'exists:issue_assignments,id'],
            'status' => ['sometimes', 'string', 'in:in_progress,on_hold,finished'],
            'notes' => ['sometimes', 'nullable', 'string'],
        ]);

        if ($validator->fails()) {
            throw new \Illuminate\Validation\ValidationException($validator);
        }

        $assignment = \App\Models\IssueAssignment::findOrFail($data['id']);

        $updateData = [];
        $timelineAction = null;

        if (isset($data['status'])) {
            $newStatus = \App\Enums\AssignmentStatus::from($data['status']);

            // Validate status transition
            $validTransition = match ($newStatus) {
                \App\Enums\AssignmentStatus::IN_PROGRESS => $assignment->canStart() || $assignment->canResume(),
                \App\Enums\AssignmentStatus::ON_HOLD => $assignment->canHold(),
                \App\Enums\AssignmentStatus::FINISHED => $assignment->canFinish(),
                default => false,
            };

            if (!$validTransition) {
                throw new \Exception(__('assignments.invalid_status_transition'));
            }

            $updateData['status'] = $newStatus;

            // Set timestamps based on status
            if ($newStatus === \App\Enums\AssignmentStatus::IN_PROGRESS && !$assignment->started_at) {
                $updateData['started_at'] = $timestamp;
                $timelineAction = \App\Enums\TimelineAction::STARTED;
            } elseif ($newStatus === \App\Enums\AssignmentStatus::IN_PROGRESS) {
                $updateData['resumed_at'] = $timestamp;
                $timelineAction = \App\Enums\TimelineAction::RESUMED;
            } elseif ($newStatus === \App\Enums\AssignmentStatus::ON_HOLD) {
                $updateData['held_at'] = $timestamp;
                $timelineAction = \App\Enums\TimelineAction::HELD;
            } elseif ($newStatus === \App\Enums\AssignmentStatus::FINISHED) {
                $updateData['finished_at'] = $timestamp;
                $timelineAction = \App\Enums\TimelineAction::FINISHED;
            }
        }

        if (isset($data['notes'])) {
            $updateData['notes'] = $data['notes'];
        }

        $assignment->update($updateData);

        // Update issue status if needed
        if (isset($data['status'])) {
            $issueStatus = match (\App\Enums\AssignmentStatus::from($data['status'])) {
                \App\Enums\AssignmentStatus::IN_PROGRESS => \App\Enums\IssueStatus::IN_PROGRESS,
                \App\Enums\AssignmentStatus::ON_HOLD => \App\Enums\IssueStatus::ON_HOLD,
                \App\Enums\AssignmentStatus::FINISHED => \App\Enums\IssueStatus::FINISHED,
                default => null,
            };

            if ($issueStatus) {
                $assignment->issue->update(['status' => $issueStatus]);
            }
        }

        // Create timeline entry
        if ($timelineAction) {
            \App\Models\IssueTimeline::create([
                'issue_id' => $assignment->issue_id,
                'issue_assignment_id' => $assignment->id,
                'action' => $timelineAction,
                'performed_by' => auth()->id(),
                'notes' => $data['notes'] ?? null,
                'metadata' => ['synced' => true, 'original_timestamp' => $timestamp->format('Y-m-d\TH:i:s\Z')],
                'created_at' => $timestamp,
            ]);
        }

        return [
            'entity_id' => $assignment->id,
            'updated_at' => $assignment->updated_at->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
