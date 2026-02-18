<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\AssignmentStatus;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Collection;

class IssueAssignment extends Model
{
    use HasFactory;

    protected $fillable = [
        'issue_id',
        'service_provider_id',
        'category_id',
        'time_slot_id',
        'time_slot_ids', // NEW: Multiple time slots support
        'work_type_id',
        'allocated_duration_minutes',
        'is_custom_duration',
        'scheduled_date',
        'scheduled_end_date', // NEW: Multi-day support
        'assigned_start_time',
        'assigned_end_time',
        'status',
        'proof_required',
        'started_at',
        'held_at',
        'resumed_at',
        'finished_at',
        'completed_at',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'status' => AssignmentStatus::class,
            'scheduled_date' => 'date',
            'scheduled_end_date' => 'date', // NEW: Multi-day support
            'proof_required' => 'boolean',
            'is_custom_duration' => 'boolean',
            'allocated_duration_minutes' => 'integer',
            'time_slot_ids' => 'array', // NEW: JSON array of time slot IDs
            'started_at' => 'datetime',
            'held_at' => 'datetime',
            'resumed_at' => 'datetime',
            'finished_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    // Relationships
    public function issue(): BelongsTo
    {
        return $this->belongsTo(Issue::class);
    }

    public function serviceProvider(): BelongsTo
    {
        return $this->belongsTo(ServiceProvider::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function timeSlot(): BelongsTo
    {
        return $this->belongsTo(TimeSlot::class);
    }

    public function workType(): BelongsTo
    {
        return $this->belongsTo(WorkType::class);
    }

    public function consumables(): HasMany
    {
        return $this->hasMany(IssueAssignmentConsumable::class);
    }

    public function proofs(): HasMany
    {
        return $this->hasMany(Proof::class);
    }

    public function timeline(): HasMany
    {
        return $this->hasMany(IssueTimeline::class)->orderBy('created_at', 'desc');
    }

    public function timeExtensionRequests(): HasMany
    {
        return $this->hasMany(TimeExtensionRequest::class, 'assignment_id')
            ->orderBy('requested_at', 'desc');
    }

    public function pendingExtensionRequests(): HasMany
    {
        return $this->timeExtensionRequests()->pending();
    }

    public function approvedExtensionRequests(): HasMany
    {
        return $this->timeExtensionRequests()->approved();
    }

    // Scopes
    public function scopeForServiceProvider($query, int $serviceProviderId)
    {
        return $query->where('service_provider_id', $serviceProviderId);
    }

    public function scopeScheduledOn($query, string $date)
    {
        return $query->where('scheduled_date', $date);
    }

    public function scopeActive($query)
    {
        return $query->whereNotIn('status', [
            AssignmentStatus::FINISHED,
            AssignmentStatus::COMPLETED,
        ]);
    }

    public function scopeInProgress($query)
    {
        return $query->where('status', AssignmentStatus::IN_PROGRESS);
    }

    // Helpers
    public function canStart(): bool
    {
        return $this->status === AssignmentStatus::ASSIGNED;
    }

    public function canHold(): bool
    {
        return $this->status === AssignmentStatus::IN_PROGRESS;
    }

    public function canResume(): bool
    {
        return $this->status === AssignmentStatus::ON_HOLD;
    }

    public function canFinish(): bool
    {
        return $this->status === AssignmentStatus::IN_PROGRESS;
    }

    public function canApprove(): bool
    {
        return $this->status === AssignmentStatus::FINISHED;
    }

    public function getDurationInMinutes(): ?int
    {
        if (! $this->started_at || ! $this->finished_at) {
            return null;
        }

        return (int) $this->started_at->diffInMinutes($this->finished_at);
    }

    public function getCompletionProofs()
    {
        return $this->proofs()->where('stage', 'completion')->get();
    }

    public function getDuringWorkProofs()
    {
        return $this->proofs()->where('stage', 'during_work')->get();
    }

    // Time Tracking Helpers
    public function getAllocatedDurationMinutes(): ?int
    {
        return $this->allocated_duration_minutes;
    }

    public function getTotalApprovedExtensionMinutes(): int
    {
        return $this->approvedExtensionRequests()->sum('requested_minutes');
    }

    public function getTotalAllowedDurationMinutes(): ?int
    {
        if (! $this->allocated_duration_minutes) {
            return null;
        }

        return $this->allocated_duration_minutes + $this->getTotalApprovedExtensionMinutes();
    }

    public function getOvertimeMinutes(): ?int
    {
        $actual = $this->getDurationInMinutes();
        $allowed = $this->getTotalAllowedDurationMinutes();

        if ($actual === null || $allowed === null) {
            return null;
        }

        return $actual - $allowed; // Negative = finished early, Positive = overtime
    }

    public function hasPendingExtensionRequest(): bool
    {
        return $this->pendingExtensionRequests()->exists();
    }

    public function canRequestExtension(): bool
    {
        // Must be in progress, no pending request exists
        return $this->status === AssignmentStatus::IN_PROGRESS
            && ! $this->hasPendingExtensionRequest();
    }

    public function getTimeTrackingData(): array
    {
        return [
            'allocated_minutes' => $this->allocated_duration_minutes,
            'approved_extension_minutes' => $this->getTotalApprovedExtensionMinutes(),
            'total_allowed_minutes' => $this->getTotalAllowedDurationMinutes(),
            'actual_minutes' => $this->getDurationInMinutes(),
            'overtime_minutes' => $this->getOvertimeMinutes(),
            'has_pending_extension' => $this->hasPendingExtensionRequest(),
            'can_request_extension' => $this->canRequestExtension(),
        ];
    }

    // Multi-slot support methods

    /**
     * Get all time slots for this assignment (supports multiple slots).
     */
    public function timeSlots(): Collection
    {
        if (empty($this->time_slot_ids)) {
            return collect();
        }

        return TimeSlot::whereIn('id', $this->time_slot_ids)
            ->orderByRaw('FIELD(id, '.implode(',', $this->time_slot_ids).')')
            ->get();
    }

    /**
     * Get combined time range bounds across all selected slots.
     *
     * @return array{start: string, end: string}|null
     */
    public function getTimeRangeBounds(): ?array
    {
        $slots = $this->timeSlots();
        if ($slots->isEmpty()) {
            return null;
        }

        $startTimes = $slots->map(fn ($s) => Carbon::parse($s->start_time));
        $endTimes = $slots->map(fn ($s) => Carbon::parse($s->end_time));

        return [
            'start' => $startTimes->min()->format('H:i:s'),
            'end' => $endTimes->max()->format('H:i:s'),
        ];
    }

    /**
     * Calculate total duration in minutes excluding gaps between slots.
     */
    public function getTotalDurationMinutes(): int
    {
        return (int) $this->timeSlots()->sum(function ($slot) {
            return Carbon::parse($slot->start_time)
                ->diffInMinutes(Carbon::parse($slot->end_time));
        });
    }

    /**
     * Check if assignment spans multiple days.
     */
    public function isMultiDay(): bool
    {
        if (! $this->scheduled_end_date) {
            return false;
        }

        return ! $this->scheduled_date->isSameDay($this->scheduled_end_date);
    }

    /**
     * Get the date range as a formatted string.
     */
    public function getDateRangeFormatted(): string
    {
        if (! $this->isMultiDay()) {
            return $this->scheduled_date->format('M d, Y');
        }

        return sprintf(
            '%s - %s',
            $this->scheduled_date->format('M d'),
            $this->scheduled_end_date->format('M d, Y')
        );
    }

    /**
     * Get the full datetime range as a formatted string.
     */
    public function getFullDateTimeRangeFormatted(): string
    {
        $startDate = $this->scheduled_date->format('M d, Y');
        $endDate = $this->scheduled_end_date ? $this->scheduled_end_date->format('M d, Y') : $startDate;

        if ($this->assigned_start_time && $this->assigned_end_time) {
            if ($this->isMultiDay()) {
                return sprintf(
                    '%s %s - %s %s',
                    $startDate,
                    Carbon::parse($this->assigned_start_time)->format('H:i'),
                    $endDate,
                    Carbon::parse($this->assigned_end_time)->format('H:i')
                );
            }

            return sprintf(
                '%s (%s - %s)',
                $startDate,
                Carbon::parse($this->assigned_start_time)->format('H:i'),
                Carbon::parse($this->assigned_end_time)->format('H:i')
            );
        }

        if ($this->isMultiDay()) {
            return "$startDate - $endDate";
        }

        return $startDate;
    }

    /**
     * Get number of days this assignment spans.
     */
    public function getSpanDays(): int
    {
        if (! $this->scheduled_end_date) {
            return 1;
        }

        return (int) ($this->scheduled_date->diffInDays($this->scheduled_end_date) + 1);
    }
}
