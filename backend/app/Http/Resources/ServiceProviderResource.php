<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\ServiceProvider
 */
class ServiceProviderResource extends JsonResource
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
            'user' => $this->whenLoaded('user', function () {
                // Always manually transform to ensure profile_photo_url is included
                return [
                    'id' => $this->user->id,
                    'name' => $this->user->name,
                    'email' => $this->user->email,
                    'phone' => $this->user->phone ?? null,
                    'profile_photo_url' => $this->user->profile_photo
                        ? \Storage::disk('public')->url($this->user->profile_photo)
                        : null,
                    'is_active' => $this->user->is_active ?? true,
                    'locale' => $this->user->locale ?? 'en',
                ];
            }),
            'category_ids' => $this->whenLoaded('categories', fn () => $this->categories->pluck('id')),
            'categories' => CategoryResource::collection($this->whenLoaded('categories')),
            // Keep for backward compatibility (mobile app transition)
            'category_id' => $this->whenLoaded('categories', fn () => $this->categories->first()?->id),
            'category' => $this->whenLoaded('categories', fn () => $this->categories->isNotEmpty() ? new CategoryResource($this->categories->first()) : null
            ),
            'is_available' => $this->is_available,
            'location' => $this->when($this->hasLocation(), [
                'latitude' => $this->latitude,
                'longitude' => $this->longitude,
            ]),
            'profile_photo_url' => $this->user?->profile_photo
                ? \Storage::disk('public')->url($this->user->profile_photo)
                : null,
            'time_slots' => TimeSlotResource::collection($this->whenLoaded('timeSlots')),
            'created_at' => $this->formatDateTime($this->created_at),
        ];
    }
}
