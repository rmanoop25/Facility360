<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IssueAssignmentConsumable extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'issue_assignment_id',
        'consumable_id',
        'custom_name',
        'quantity',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    // Relationships
    public function assignment(): BelongsTo
    {
        return $this->belongsTo(IssueAssignment::class, 'issue_assignment_id');
    }

    public function consumable(): BelongsTo
    {
        return $this->belongsTo(Consumable::class);
    }

    // Accessors
    public function getNameAttribute(): string
    {
        if ($this->consumable) {
            return $this->consumable->name;
        }

        return $this->custom_name ?? '';
    }

    public function getIsCustomAttribute(): bool
    {
        return $this->consumable_id === null && $this->custom_name !== null;
    }

    // Scopes
    public function scopeCustom($query)
    {
        return $query->whereNull('consumable_id')
            ->whereNotNull('custom_name');
    }

    public function scopeStandard($query)
    {
        return $query->whereNotNull('consumable_id');
    }
}
