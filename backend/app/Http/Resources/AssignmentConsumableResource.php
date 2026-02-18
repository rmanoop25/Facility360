<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Traits\FormatsApiDates;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\IssueAssignmentConsumable
 */
class AssignmentConsumableResource extends JsonResource
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
            'consumable' => $this->whenLoaded('consumable', fn () => new ConsumableResource($this->consumable)),
            'name' => $this->name,
            'custom_name' => $this->custom_name,
            'is_custom' => $this->is_custom,
            'quantity' => $this->quantity,
            'created_at' => $this->formatDateTime($this->created_at),
        ];
    }
}
