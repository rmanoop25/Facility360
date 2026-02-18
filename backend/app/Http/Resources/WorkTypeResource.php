<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\WorkType
 */
class WorkTypeResource extends JsonResource
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
            'name_en' => $this->name_en,
            'name_ar' => $this->name_ar,
            'description_en' => $this->description_en,
            'description_ar' => $this->description_ar,
            'duration_minutes' => $this->duration_minutes,
            'duration_hours' => $this->duration_hours,
            'formatted_duration' => $this->formatted_duration,
            'categories' => CategoryResource::collection($this->whenLoaded('categories')),
            'is_active' => $this->is_active,
            'assignments_count' => $this->when(
                isset($this->assignments_count),
                $this->assignments_count
            ),
            'created_at' => $this->formatDateTime($this->created_at),
            'updated_at' => $this->formatDateTime($this->updated_at),
        ];
    }
}
