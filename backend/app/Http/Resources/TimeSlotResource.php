<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\TimeSlot
 */
class TimeSlotResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $startTime = $this->start_time instanceof Carbon
            ? $this->start_time->format('H:i')
            : $this->start_time;
        $endTime = $this->end_time instanceof Carbon
            ? $this->end_time->format('H:i')
            : $this->end_time;

        return [
            'id' => $this->id,
            'day_of_week' => $this->day_of_week,
            'day_name' => $this->day_name,
            'start_time' => $startTime,
            'end_time' => $endTime,
            'formatted_time_range' => $this->formatted_time_range,
            'display_name' => $this->display_name,
            'is_active' => $this->is_active,
            'is_full_day' => $startTime === '00:00' && $endTime === '23:59',
        ];
    }
}
