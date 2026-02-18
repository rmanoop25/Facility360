<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Consumable
 */
class ConsumableResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $locale = $request->header('Accept-Language', app()->getLocale());

        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'name_en' => $this->name_en,
            'name_ar' => $this->name_ar,
            'name' => $locale === 'ar' ? $this->name_ar : $this->name_en,
            'is_active' => $this->is_active,
            'category' => $this->whenLoaded('category', fn () => new CategoryResource($this->category)),
        ];
    }
}
