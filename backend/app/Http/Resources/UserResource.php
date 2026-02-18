<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * @mixin \App\Models\User
 */
class UserResource extends JsonResource
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
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'profile_photo_url' => $this->profile_photo
                ? Storage::disk('public')->url($this->profile_photo)
                : null,
            'role' => $this->getRoleNames()->first(),
            'locale' => $this->locale,
            'is_active' => $this->is_active,
            'created_at' => $this->formatDateTime($this->created_at),
        ];
    }
}
