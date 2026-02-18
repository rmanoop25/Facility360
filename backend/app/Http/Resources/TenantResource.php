<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Tenant
 */
class TenantResource extends JsonResource
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
            'user_id' => $this->user_id,
            'user' => $this->whenLoaded('user', fn () => new UserResource($this->user)),
            'unit_number' => $this->unit_number,
            'building_name' => $this->building_name,
            'full_address' => $this->full_address,
            'profile_photo_url' => $this->user?->profile_photo
                ? \Storage::disk('public')->url($this->user->profile_photo)
                : null,
            'issues_count' => $this->when(isset($this->issues_count), $this->issues_count),
            'created_at' => $this->formatDateTime($this->created_at),
            'updated_at' => $this->formatDateTime($this->updated_at),
        ];
    }
}
