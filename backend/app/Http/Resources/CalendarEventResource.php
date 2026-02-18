<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\IssueAssignment
 */
class CalendarEventResource extends JsonResource
{
    use FormatsApiDates;

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $timeSlot = $this->whenLoaded('timeSlot');

        return [
            'id' => $this->id,
            'type' => 'assignment',
            'title' => $this->issue?->title,
            'issue_id' => $this->issue_id,
            'scheduled_date' => $this->formatDate($this->scheduled_date),
            'start_time' => $this->timeSlot?->start_time?->format('H:i'),
            'end_time' => $this->timeSlot?->end_time?->format('H:i'),
            'all_day' => $this->timeSlot === null,
            'status' => [
                'value' => $this->status?->value,
                'label' => $this->status?->label(),
                'color' => $this->status?->color(),
                'icon' => $this->status?->icon(),
            ],
            'service_provider' => $this->whenLoaded('serviceProvider', fn () => [
                'id' => $this->serviceProvider->id,
                'name' => $this->serviceProvider->user?->name,
            ]),
            'category' => $this->whenLoaded('category', fn () => $this->category ? [
                'id' => $this->category->id,
                'name' => $this->category->localizedName,
            ] : null),
            'tenant' => $this->when($this->issue?->tenant, fn () => [
                'id' => $this->issue->tenant->id,
                'name' => $this->issue->tenant->user?->name,
                'unit' => $this->issue->tenant->unit_number,
            ]),
            'priority' => $this->when($this->issue, fn () => [
                'value' => $this->issue->priority?->value,
                'label' => $this->issue->priority?->label(),
                'color' => $this->issue->priority?->color(),
            ]),
            'time_slot' => $this->whenLoaded('timeSlot', fn () => $this->timeSlot ? [
                'id' => $this->timeSlot->id,
                'day_of_week' => $this->timeSlot->day_of_week,
                'day_name' => $this->timeSlot->day_name,
                'start_time' => $this->timeSlot->start_time?->format('H:i'),
                'end_time' => $this->timeSlot->end_time?->format('H:i'),
                'display_name' => $this->timeSlot->display_name,
            ] : null),
        ];
    }
}
