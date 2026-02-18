<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\TimeExtensionRequest
 */
class TimeExtensionRequestResource extends JsonResource
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
            'assignment_id' => $this->assignment_id,
            'requested_by' => $this->requested_by,
            'requester_name' => $this->whenLoaded('requester', fn () => $this->requester->name),
            'requested_minutes' => $this->requested_minutes,
            'reason' => $this->reason,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'status_color' => $this->status->color(),
            'status_icon' => $this->status->icon(),
            'responded_by' => $this->responded_by,
            'responder_name' => $this->whenLoaded('responder', fn () => $this->responder?->name),
            'admin_notes' => $this->admin_notes,
            'requested_at' => $this->formatDateTime($this->requested_at),
            'responded_at' => $this->formatDateTime($this->responded_at),
            'created_at' => $this->formatDateTime($this->created_at),
            'updated_at' => $this->formatDateTime($this->updated_at),
        ];
    }
}
