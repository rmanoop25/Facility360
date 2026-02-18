<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\ExtensionStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TimeExtensionRequest extends Model
{
    use HasFactory;

    protected $fillable = [
        'assignment_id',
        'requested_by',
        'requested_minutes',
        'reason',
        'status',
        'responded_by',
        'admin_notes',
        'requested_at',
        'responded_at',
    ];

    protected function casts(): array
    {
        return [
            'requested_minutes' => 'integer',
            'status' => ExtensionStatus::class,
            'requested_at' => 'datetime',
            'responded_at' => 'datetime',
        ];
    }

    // Relationships
    public function assignment(): BelongsTo
    {
        return $this->belongsTo(IssueAssignment::class, 'assignment_id');
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    public function responder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'responded_by');
    }

    // Scopes
    public function scopePending($query)
    {
        return $query->where('status', ExtensionStatus::PENDING);
    }

    public function scopeApproved($query)
    {
        return $query->where('status', ExtensionStatus::APPROVED);
    }

    public function scopeForAssignment($query, int $assignmentId)
    {
        return $query->where('assignment_id', $assignmentId);
    }

    // Helpers
    public function isPending(): bool
    {
        return $this->status === ExtensionStatus::PENDING;
    }

    public function isApproved(): bool
    {
        return $this->status === ExtensionStatus::APPROVED;
    }

    public function isRejected(): bool
    {
        return $this->status === ExtensionStatus::REJECTED;
    }

    public function canBeApproved(): bool
    {
        return $this->isPending();
    }

    public function canBeRejected(): bool
    {
        return $this->isPending();
    }
}
