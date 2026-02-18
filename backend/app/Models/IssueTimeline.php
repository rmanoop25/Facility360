<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\TimelineAction;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IssueTimeline extends Model
{
    public $timestamps = false;

    protected $table = 'issue_timeline';

    protected $fillable = [
        'issue_id',
        'issue_assignment_id',
        'action',
        'performed_by',
        'notes',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'action' => TimelineAction::class,
            'metadata' => 'array',
            'created_at' => 'datetime',
        ];
    }

    // Relationships
    public function issue(): BelongsTo
    {
        return $this->belongsTo(Issue::class);
    }

    public function assignment(): BelongsTo
    {
        return $this->belongsTo(IssueAssignment::class, 'issue_assignment_id');
    }

    public function performedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by');
    }

    /**
     * Alias for performedByUser for backward compatibility.
     */
    public function performedBy(): BelongsTo
    {
        return $this->performedByUser();
    }

    // Scopes
    public function scopeForAction($query, TimelineAction $action)
    {
        return $query->where('action', $action);
    }

    // Helpers
    public function getFormattedDescriptionAttribute(): string
    {
        $user = $this->performedByUser?->name ?? 'System';
        $action = $this->action->label();

        return "{$user} {$action}";
    }
}
