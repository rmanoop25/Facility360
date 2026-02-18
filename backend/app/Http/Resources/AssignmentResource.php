<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\IssueAssignment
 */
class AssignmentResource extends JsonResource
{
    use FormatsApiDates;

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'issue_id' => $this->issue_id,
            'service_provider_id' => $this->service_provider_id,
            'category_id' => $this->category_id,

            // TIME SLOT SUPPORT (Multi-slot + Legacy single slot)
            'time_slot_id' => $this->time_slot_id, // Legacy: first slot ID
            'time_slot_ids' => $this->time_slot_ids, // NEW: Multi-slot array
            'time_slot' => $this->whenLoaded(
                'timeSlot',
                fn () => new TimeSlotResource($this->timeSlot)
            ), // Legacy single slot
            'time_slots' => TimeSlotResource::collection($this->timeSlots()), // NEW: Multi-slot collection (method, not relationship)

            // RELATIONSHIPS
            'service_provider' => $this->whenLoaded(
                'serviceProvider',
                fn () => new ServiceProviderResource($this->serviceProvider)
            ),
            'category' => $this->whenLoaded(
                'category',
                fn () => new CategoryResource($this->category)
            ),
            'work_type_id' => $this->work_type_id,
            'work_type' => $this->whenLoaded(
                'workType',
                fn () => new WorkTypeResource($this->workType)
            ),

            // DURATION & TIME ALLOCATION
            'allocated_duration_minutes' => $this->allocated_duration_minutes,
            'is_custom_duration' => $this->is_custom_duration,
            'approved_extension_minutes' => $this->getTotalApprovedExtensionMinutes(),
            'total_allowed_minutes' => $this->getTotalAllowedDurationMinutes(),
            'actual_duration_minutes' => $this->getDurationInMinutes(),
            'overtime_minutes' => $this->getOvertimeMinutes(),
            'has_pending_extension' => $this->hasPendingExtensionRequest(),
            'can_request_extension' => $this->canRequestExtension(),

            // SCHEDULING (Multi-day support + time ranges)
            'scheduled_date' => $this->formatDate($this->scheduled_date),
            'scheduled_end_date' => $this->formatDate($this->scheduled_end_date), // NEW: Multi-day
            'assigned_start_time' => $this->assigned_start_time, // NEW: H:i:s format
            'assigned_end_time' => $this->assigned_end_time, // NEW: H:i:s format
            'is_multi_day' => $this->isMultiDay(), // NEW: Multi-day flag
            'span_days' => $this->getSpanDays(), // NEW: Days count

            // STATUS
            'status' => $this->status?->value,
            'status_label' => $this->status?->label(),
            'status_color' => $this->status?->color(),
            'status_icon' => $this->status?->icon(),
            'proof_required' => $this->proof_required,
            'started_at' => $this->formatDateTime($this->started_at),
            'held_at' => $this->formatDateTime($this->held_at),
            'resumed_at' => $this->formatDateTime($this->resumed_at),
            'finished_at' => $this->formatDateTime($this->finished_at),
            'completed_at' => $this->formatDateTime($this->completed_at),
            'duration_minutes' => $this->getDurationInMinutes(),
            'proofs' => ProofResource::collection($this->whenLoaded('proofs')),
            'consumables' => AssignmentConsumableResource::collection($this->whenLoaded('consumables')),
            'extension_requests' => TimeExtensionRequestResource::collection($this->whenLoaded('timeExtensionRequests')),
            'notes' => $this->notes,
            'can_start' => $this->canStart(),
            'can_hold' => $this->canHold(),
            'can_resume' => $this->canResume(),
            'can_finish' => $this->canFinish(),
            'can_approve' => $this->canApprove(),
            'created_at' => $this->formatDateTime($this->created_at),
            'updated_at' => $this->formatDateTime($this->updated_at),
        ];
    }
}
