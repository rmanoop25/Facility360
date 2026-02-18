<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\IssueTimeline
 */
class TimelineResource extends JsonResource
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
            'action' => $this->action?->value,
            'action_label' => $this->action?->label(),
            'action_color' => $this->action?->color(),
            'action_icon' => $this->action?->icon(),
            'performed_by' => $this->whenLoaded(
                'performedByUser',
                fn () => new UserResource($this->performedByUser)
            ),
            'notes' => $this->notes,
            'metadata' => $this->metadata,
            'formatted_description' => $this->formatted_description,
            'created_at' => $this->formatDateTime($this->created_at),
        ];
    }
}
