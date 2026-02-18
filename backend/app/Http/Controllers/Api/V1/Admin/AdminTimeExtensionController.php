<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\ExtensionStatus;
use App\Http\Controllers\Api\V1\ApiController;
use App\Models\TimeExtensionRequest;
use App\Services\TimeSlotAvailabilityService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class AdminTimeExtensionController extends ApiController
{
    /**
     * List all time extension requests with filters.
     */
    public function index(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => ['nullable', 'string', 'in:pending,approved,rejected'],
            'assignment_id' => ['nullable', 'integer', 'exists:issue_assignments,id'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $query = TimeExtensionRequest::with([
            'assignment.issue:id,title',
            'assignment.serviceProvider.user:id,name',
            'requester:id,name',
            'responder:id,name',
        ]);

        // Apply filters
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->filled('assignment_id')) {
            $query->forAssignment($request->input('assignment_id'));
        }

        $perPage = $request->input('per_page', 15);
        $extensions = $query->orderBy('requested_at', 'desc')->paginate($perPage);

        $data = $extensions->getCollection()->map(fn ($ext) => $this->formatExtension($ext));

        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => [
                'current_page' => $extensions->currentPage(),
                'last_page' => $extensions->lastPage(),
                'per_page' => $extensions->perPage(),
                'total' => $extensions->total(),
            ],
        ]);
    }

    /**
     * Approve a time extension request.
     *
     * Extends the assignment's assigned_end_time by the requested minutes so that
     * the extra time is automatically blocked for other assignments — no changes
     * to the overlap validation logic are needed.
     */
    public function approve(Request $request, int $id, TimeSlotAvailabilityService $availabilityService): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $extension = TimeExtensionRequest::with('assignment')->find($id);

        if (! $extension) {
            return response()->json([
                'success' => false,
                'message' => __('extensions.not_found'),
            ], 404);
        }

        if (! $extension->canBeApproved()) {
            return response()->json([
                'success' => false,
                'message' => __('extensions.cannot_approve'),
            ], 422);
        }

        $assignment = $extension->assignment;

        // If the assignment has a time range, check for conflicts before extending.
        // Use the last scheduled date (end date for multi-day, otherwise start date).
        if ($assignment->assigned_end_time && $assignment->assigned_start_time) {
            $currentEnd = Carbon::parse($assignment->assigned_end_time);
            $newEnd = $currentEnd->copy()->addMinutes($extension->requested_minutes);
            $checkDate = Carbon::parse($assignment->scheduled_end_date ?? $assignment->scheduled_date);

            $hasConflict = $availabilityService->hasOverlap(
                $assignment->service_provider_id,
                $checkDate,
                $currentEnd->format('H:i:s'),
                $newEnd->format('H:i:s'),
                $assignment->id // exclude the current assignment from the check
            );

            if ($hasConflict) {
                return response()->json([
                    'success' => false,
                    'message' => __('extensions.overlap_conflict', [
                        'minutes' => $extension->requested_minutes,
                    ]),
                ], 422);
            }
        }

        DB::transaction(function () use ($extension, $assignment, $request) {
            // Extend assigned_end_time if a time range is set — this automatically
            // blocks the extra time for any new assignment overlap checks.
            if ($assignment->assigned_end_time && $assignment->assigned_start_time) {
                $newEnd = Carbon::parse($assignment->assigned_end_time)
                    ->addMinutes($extension->requested_minutes);

                $assignment->update([
                    'assigned_end_time' => $newEnd->format('H:i:s'),
                ]);
            }

            $extension->update([
                'status' => ExtensionStatus::APPROVED,
                'responded_by' => auth()->id(),
                'admin_notes' => $request->input('admin_notes'),
                'responded_at' => now(),
            ]);
        });

        $extension->load(['assignment', 'requester', 'responder']);

        return response()->json([
            'success' => true,
            'message' => __('extensions.approved_successfully'),
            'data' => $this->formatExtension($extension),
        ]);
    }

    /**
     * Reject a time extension request.
     */
    public function reject(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'admin_notes' => ['required', 'string', 'min:10', 'max:1000'], // Rejection reason required
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $extension = TimeExtensionRequest::find($id);

        if (! $extension) {
            return response()->json([
                'success' => false,
                'message' => __('extensions.not_found'),
            ], 404);
        }

        if (! $extension->canBeRejected()) {
            return response()->json([
                'success' => false,
                'message' => __('extensions.cannot_reject'),
            ], 422);
        }

        $extension->update([
            'status' => ExtensionStatus::REJECTED,
            'responded_by' => auth()->id(),
            'admin_notes' => $request->input('admin_notes'),
            'responded_at' => now(),
        ]);

        // TODO: Send notification to SP

        return response()->json([
            'success' => true,
            'message' => __('extensions.rejected_successfully'),
            'data' => $this->formatExtension($extension),
        ]);
    }

    /**
     * Format time extension request for response.
     */
    private function formatExtension(TimeExtensionRequest $ext): array
    {
        return [
            'id' => $ext->id,
            'assignment_id' => $ext->assignment_id,
            'issue_title' => $ext->assignment->issue->title ?? null,
            'service_provider_name' => $ext->assignment->serviceProvider->user->name ?? null,
            'requester_name' => $ext->requester->name ?? null,
            'responder_name' => $ext->responder->name ?? null,
            'requested_minutes' => $ext->requested_minutes,
            'reason' => $ext->reason,
            'status' => $ext->status->value,
            'status_label' => $ext->status->label(),
            'admin_notes' => $ext->admin_notes,
            'requested_at' => $ext->requested_at?->format('Y-m-d\TH:i:s\Z'),
            'responded_at' => $ext->responded_at?->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
