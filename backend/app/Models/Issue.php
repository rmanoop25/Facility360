<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\AssignmentStatus;
use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Issue extends Model
{
    use HasFactory;

    protected $fillable = [
        'tenant_id',
        'title',
        'description',
        'status',
        'priority',
        'latitude',
        'longitude',
        'address',
        'location',
        'proof_required',
        'cancelled_reason',
        'cancelled_by',
        'cancelled_at',
    ];

    protected $appends = [
        'location',
    ];

    // Location attributes for Google Maps plugin
    public static function getLatLngAttributes(): array
    {
        return [
            'lat' => 'latitude',
            'lng' => 'longitude',
        ];
    }

    public static function getComputedLocation(): string
    {
        return 'location';
    }

    public function getLocationAttribute(): array
    {
        return [
            'lat' => (float) ($this->latitude ?? 0),
            'lng' => (float) ($this->longitude ?? 0),
        ];
    }

    public function setLocationAttribute(?array $location): void
    {
        if (is_array($location)) {
            $this->attributes['latitude'] = $location['lat'] ?? null;
            $this->attributes['longitude'] = $location['lng'] ?? null;
        }
    }

    public function isLocationSet(): bool
    {
        return ! empty($this->latitude) && ! empty($this->longitude);
    }

    protected function casts(): array
    {
        return [
            'status' => IssueStatus::class,
            'priority' => IssuePriority::class,
            'latitude' => 'decimal:8',
            'longitude' => 'decimal:8',
            'proof_required' => 'boolean',
            'cancelled_at' => 'datetime',
        ];
    }

    // Relationships
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function categories(): BelongsToMany
    {
        return $this->belongsToMany(Category::class, 'issue_categories');
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(IssueAssignment::class);
    }

    public function timeline(): HasMany
    {
        return $this->hasMany(IssueTimeline::class)->orderBy('created_at', 'asc')->orderBy('id', 'asc');
    }

    public function media(): HasMany
    {
        return $this->hasMany(IssueMedia::class);
    }

    public function cancelledByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cancelled_by');
    }

    // Scopes
    public function scopePending($query)
    {
        return $query->where('status', IssueStatus::PENDING);
    }

    public function scopeActive($query)
    {
        return $query->whereNotIn('status', [
            IssueStatus::COMPLETED,
            IssueStatus::CANCELLED,
        ]);
    }

    public function scopeForTenant($query, int $tenantId)
    {
        return $query->where('tenant_id', $tenantId);
    }

    public function scopeWithStatus($query, IssueStatus $status)
    {
        return $query->where('status', $status);
    }

    public function scopeHighPriority($query)
    {
        return $query->where('priority', IssuePriority::HIGH);
    }

    // Helpers
    public function hasLocation(): bool
    {
        return $this->latitude !== null && $this->longitude !== null;
    }

    public function getDirectionsUrl(): ?string
    {
        if (! $this->hasLocation()) {
            return null;
        }

        return "https://www.google.com/maps/dir/?api=1&destination={$this->latitude},{$this->longitude}";
    }

    public function getCurrentAssignment(): ?IssueAssignment
    {
        return $this->assignments()
            ->whereNotIn('status', ['completed', 'cancelled'])
            ->latest()
            ->first();
    }

    public function isAssigned(): bool
    {
        return $this->status === IssueStatus::ASSIGNED
            || $this->status === IssueStatus::IN_PROGRESS
            || $this->status === IssueStatus::ON_HOLD;
    }

    public function canBeAssigned(): bool
    {
        // Allow assignment for pending issues and adding more assignments to active issues
        return in_array($this->status, [
            IssueStatus::PENDING,
            IssueStatus::ASSIGNED,
            IssueStatus::IN_PROGRESS,
        ]);
    }

    public function canBeCancelled(): bool
    {
        return ! in_array($this->status, [
            IssueStatus::COMPLETED,
            IssueStatus::CANCELLED,
        ]);
    }

    /**
     * Check if all non-completed assignments are finished (awaiting approval).
     */
    public function areAllAssignmentsFinished(): bool
    {
        $assignments = $this->assignments()->get();

        if ($assignments->isEmpty()) {
            return false;
        }

        // Get assignments that are not yet completed
        $nonCompletedAssignments = $assignments->filter(
            fn ($a) => $a->status !== AssignmentStatus::COMPLETED
        );

        // If all are already completed, return false (nothing to approve)
        if ($nonCompletedAssignments->isEmpty()) {
            return false;
        }

        // Check if all non-completed assignments are finished
        return $nonCompletedAssignments->every(
            fn ($a) => $a->status === AssignmentStatus::FINISHED
        );
    }

    /**
     * Check if all assignments are completed.
     */
    public function areAllAssignmentsCompleted(): bool
    {
        $assignments = $this->assignments;

        if ($assignments->isEmpty()) {
            return false;
        }

        return $assignments->every(
            fn ($a) => $a->status === AssignmentStatus::COMPLETED
        );
    }

    /**
     * Calculate the appropriate issue status based on all assignments.
     */
    public function calculateStatusFromAssignments(): IssueStatus
    {
        $assignments = $this->assignments()->get();

        // No assignments - keep current status if cancelled, otherwise pending
        if ($assignments->isEmpty()) {
            return $this->status === IssueStatus::CANCELLED
                ? IssueStatus::CANCELLED
                : IssueStatus::PENDING;
        }

        // Check for in-progress first (highest priority active status)
        if ($assignments->contains(fn ($a) => $a->status === AssignmentStatus::IN_PROGRESS)) {
            return IssueStatus::IN_PROGRESS;
        }

        // Check for on-hold
        if ($assignments->contains(fn ($a) => $a->status === AssignmentStatus::ON_HOLD)) {
            return IssueStatus::ON_HOLD;
        }

        // Check if all are completed
        if ($assignments->every(fn ($a) => $a->status === AssignmentStatus::COMPLETED)) {
            return IssueStatus::COMPLETED;
        }

        // Check if all non-completed are finished (awaiting approval)
        $nonCompletedAssignments = $assignments->filter(
            fn ($a) => $a->status !== AssignmentStatus::COMPLETED
        );

        if ($nonCompletedAssignments->isNotEmpty() &&
            $nonCompletedAssignments->every(fn ($a) => $a->status === AssignmentStatus::FINISHED)) {
            return IssueStatus::FINISHED;
        }

        // Check for assigned (some work not started)
        if ($assignments->contains(fn ($a) => $a->status === AssignmentStatus::ASSIGNED)) {
            return IssueStatus::ASSIGNED;
        }

        // Fallback
        return IssueStatus::ASSIGNED;
    }

    /**
     * Check if the issue can be approved (at least one assignment finished, awaiting approval).
     */
    public function canBeApproved(): bool
    {
        return $this->assignments()
            ->where('status', AssignmentStatus::FINISHED)
            ->exists();
    }

    /**
     * Get count of assignments pending approval (FINISHED status).
     */
    public function getPendingApprovalCount(): int
    {
        return $this->assignments()
            ->where('status', AssignmentStatus::FINISHED)
            ->count();
    }

    /**
     * Get count of completed assignments.
     */
    public function getCompletedAssignmentCount(): int
    {
        return $this->assignments()
            ->where('status', AssignmentStatus::COMPLETED)
            ->count();
    }

    /**
     * Get total assignment count.
     */
    public function getTotalAssignmentCount(): int
    {
        return $this->assignments()->count();
    }
}
