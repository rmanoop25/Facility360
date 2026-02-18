<?php

declare(strict_types=1);

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TimeSlot extends Model
{
    use HasFactory;

    protected $fillable = [
        'service_provider_id',
        'day_of_week',
        'start_time',
        'end_time',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'day_of_week' => 'integer',
            'start_time' => 'datetime:H:i',
            'end_time' => 'datetime:H:i',
            'is_active' => 'boolean',
        ];
    }

    // Relationships
    public function serviceProvider(): BelongsTo
    {
        return $this->belongsTo(ServiceProvider::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(IssueAssignment::class);
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeForDay($query, int $dayOfWeek)
    {
        return $query->where('day_of_week', $dayOfWeek);
    }

    // Accessors
    public function getDayNameAttribute(): string
    {
        $days = [
            0 => __('days.sunday'),
            1 => __('days.monday'),
            2 => __('days.tuesday'),
            3 => __('days.wednesday'),
            4 => __('days.thursday'),
            5 => __('days.friday'),
            6 => __('days.saturday'),
        ];

        return $days[$this->day_of_week] ?? '';
    }

    public function getFormattedTimeRangeAttribute(): string
    {
        $start = Carbon::parse($this->start_time)->format('H:i');
        $end = Carbon::parse($this->end_time)->format('H:i');

        return "{$start} - {$end}";
    }

    public function getDisplayNameAttribute(): string
    {
        return "{$this->day_name}: {$this->formatted_time_range}";
    }

    // Helpers

    /**
     * Get detailed availability information for a specific date with capacity tracking.
     *
     * @param  Carbon  $date  The date to check
     * @param  int  $durationMinutes  Required duration in minutes
     * @return array{
     *     is_available: bool,
     *     has_capacity: bool,
     *     available_minutes: int,
     *     booked_minutes: int,
     *     total_minutes: int,
     *     next_available: array{start: string, end: string}|null
     * }
     */
    public function getAvailabilityOn(Carbon $date, int $durationMinutes): array
    {
        // Check basic availability first
        if (! $this->is_active || $date->dayOfWeek !== $this->day_of_week) {
            return [
                'is_available' => false,
                'has_capacity' => false,
                'available_minutes' => 0,
                'booked_minutes' => 0,
                'total_minutes' => 0,
                'next_available' => null,
            ];
        }

        $service = app(\App\Services\TimeSlotAvailabilityService::class);
        $capacity = $service->getSlotCapacity($this, $date);

        $nextAvailable = $capacity['has_capacity']
            ? $service->calculateNextAvailableTime($this, $date, $durationMinutes)
            : null;

        return [
            'is_available' => $capacity['available_minutes'] >= $durationMinutes,
            'has_capacity' => $capacity['has_capacity'],
            'available_minutes' => $capacity['available_minutes'],
            'booked_minutes' => $capacity['booked_minutes'],
            'total_minutes' => $capacity['total_minutes'],
            'next_available' => $nextAvailable,
        ];
    }

    /**
     * Check if time slot is available on a specific date (binary check).
     *
     * @deprecated Use getAvailabilityOn() for capacity-based availability checking
     *
     * @param  Carbon  $date  The date to check
     * @return bool True if slot has any capacity, false otherwise
     */
    public function isAvailableOn(Carbon $date): bool
    {
        if (! $this->is_active) {
            return false;
        }

        // Check if day of week matches
        if ($date->dayOfWeek !== $this->day_of_week) {
            return false;
        }

        // Changed to capacity-based check instead of binary exists check
        $service = app(\App\Services\TimeSlotAvailabilityService::class);
        $capacity = $service->getSlotCapacity($this, $date);

        return $capacity['has_capacity'];
    }
}
