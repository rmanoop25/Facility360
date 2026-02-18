<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Issue
 */
class PendingIssueEventResource extends JsonResource
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
            'id' => 'pending-' . $this->id,
            'type' => 'pending_issue',
            'title' => $this->title,
            'issue_id' => $this->id,
            'scheduled_date' => $this->formatDate($this->created_at),
            'start_time' => null,
            'end_time' => null,
            'all_day' => true,
            'status' => [
                'value' => 'pending',
                'label' => __('issues.status.pending'),
                'color' => 'warning',
                'icon' => 'heroicon-o-clock',
            ],
            'service_provider' => null,
            'category' => null,
            'categories' => $this->whenLoaded('categories', fn () =>
                $this->categories->map(fn ($cat) => [
                    'id' => $cat->id,
                    'name' => $cat->localizedName,
                ])
            ),
            'tenant' => $this->whenLoaded('tenant', fn () => [
                'id' => $this->tenant->id,
                'name' => $this->tenant->user?->name,
                'unit' => $this->tenant->unit_number,
            ]),
            'priority' => [
                'value' => $this->priority?->value,
                'label' => $this->priority?->label(),
                'color' => $this->priority?->color(),
            ],
            'time_slot' => null,
            'created_at' => $this->formatDateTime($this->created_at),
        ];
    }
}
