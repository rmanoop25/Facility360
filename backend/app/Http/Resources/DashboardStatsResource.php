<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DashboardStatsResource extends JsonResource
{
    /**
     * Create a new resource instance.
     *
     * @param array<string, mixed> $resource
     */
    public function __construct($resource)
    {
        parent::__construct($resource);
    }

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'total_issues' => $this->resource['total_issues'] ?? 0,
            'pending' => $this->resource['pending'] ?? 0,
            'assigned' => $this->resource['assigned'] ?? 0,
            'in_progress' => $this->resource['in_progress'] ?? 0,
            'on_hold' => $this->resource['on_hold'] ?? 0,
            'finished' => $this->resource['finished'] ?? 0,
            'completed' => $this->resource['completed'] ?? 0,
            'cancelled' => $this->resource['cancelled'] ?? 0,
            'high_priority' => $this->resource['high_priority'] ?? 0,
            'recent_activity' => $this->when(
                isset($this->resource['recent_activity']),
                fn () => TimelineResource::collection($this->resource['recent_activity'])
            ),
            'issues_by_category' => $this->resource['issues_by_category'] ?? [],
            'issues_by_priority' => $this->resource['issues_by_priority'] ?? [],
            'average_resolution_time' => $this->resource['average_resolution_time'] ?? null,
        ];
    }
}
