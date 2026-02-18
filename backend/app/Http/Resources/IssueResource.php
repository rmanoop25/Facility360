<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Issue
 */
class IssueResource extends JsonResource
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
            'title' => $this->title,
            'description' => $this->description,
            'status' => $this->status?->value,
            'status_label' => $this->status?->label(),
            'status_color' => $this->status?->color(),
            'status_icon' => $this->status?->icon(),
            'priority' => $this->priority?->value,
            'priority_label' => $this->priority?->label(),
            'priority_color' => $this->priority?->color(),
            'priority_icon' => $this->priority?->icon(),
            'location' => $this->when($this->hasLocation(), [
                'latitude' => $this->latitude,
                'longitude' => $this->longitude,
                'address' => $this->address,
                'directions_url' => $this->getDirectionsUrl(),
            ]),
            'proof_required' => $this->proof_required,
            'categories' => CategoryResource::collection($this->whenLoaded('categories')),
            'tenant' => $this->whenLoaded('tenant', fn () => new TenantResource($this->tenant)),
            'assignments' => AssignmentResource::collection($this->whenLoaded('assignments')),
            'current_assignment' => $this->when(
                $this->relationLoaded('assignments'),
                fn () => $this->getCurrentAssignment()
                    ? new AssignmentResource($this->getCurrentAssignment())
                    : null
            ),
            'timeline' => TimelineResource::collection($this->whenLoaded('timeline')),
            'media' => IssueMediaResource::collection($this->whenLoaded('media')),
            'cancelled_reason' => $this->cancelled_reason,
            'cancelled_at' => $this->formatDateTime($this->cancelled_at),
            'cancelled_by' => $this->whenLoaded(
                'cancelledByUser',
                fn () => new UserResource($this->cancelledByUser)
            ),
            'can_be_assigned' => $this->canBeAssigned(),
            'can_be_cancelled' => $this->canBeCancelled(),
            'is_assigned' => $this->isAssigned(),
            'created_at' => $this->formatDateTime($this->created_at),
            'updated_at' => $this->formatDateTime($this->updated_at),
        ];
    }
}
