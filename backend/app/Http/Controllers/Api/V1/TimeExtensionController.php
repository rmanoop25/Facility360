<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\AssignmentStatus;
use App\Enums\ExtensionStatus;
use App\Models\IssueAssignment;
use App\Models\TimeExtensionRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class TimeExtensionController extends ApiController
{
    /**
     * Request a time extension for an assignment.
     */
    public function request(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'assignment_id' => ['required', 'integer', 'exists:issue_assignments,id'],
            'requested_minutes' => ['required', 'integer', 'min:15', 'max:240'], // 15min to 4 hours
            'reason' => ['required', 'string', 'min:10', 'max:1000'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $assignment = IssueAssignment::with(['serviceProvider.user'])->find($request->input('assignment_id'));

        // Verify assignment belongs to current SP
        if ($assignment->serviceProvider->user_id !== auth()->id()) {
            return response()->json([
                'success' => false,
                'message' => __('extensions.not_authorized'),
            ], 403);
        }

        // Verify work has started
        if ($assignment->status !== AssignmentStatus::IN_PROGRESS) {
            return response()->json([
                'success' => false,
                'message' => __('extensions.work_not_started'),
            ], 422);
        }

        // Verify no pending request exists
        if ($assignment->hasPendingExtensionRequest()) {
            return response()->json([
                'success' => false,
                'message' => __('extensions.pending_request_exists'),
            ], 422);
        }

        $extension = TimeExtensionRequest::create([
            'assignment_id' => $assignment->id,
            'requested_by' => auth()->id(),
            'requested_minutes' => $request->input('requested_minutes'),
            'reason' => $request->input('reason'),
            'status' => ExtensionStatus::PENDING,
            'requested_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => __('extensions.request_submitted'),
            'data' => $this->formatExtension($extension),
        ], 201);
    }

    /**
     * Get all extension requests made by the current SP.
     */
    public function myRequests(): JsonResponse
    {
        $extensions = TimeExtensionRequest::with(['assignment.issue'])
            ->where('requested_by', auth()->id())
            ->orderBy('requested_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $extensions->map(fn ($ext) => $this->formatExtension($ext)),
        ]);
    }

    /**
     * Format time extension request.
     */
    private function formatExtension(TimeExtensionRequest $ext): array
    {
        return [
            'id' => $ext->id,
            'assignment_id' => $ext->assignment_id,
            'issue_title' => $ext->assignment->issue->title ?? null,
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
