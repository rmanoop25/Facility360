<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Tenant extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'unit_number',
        'building_name',
    ];

    // Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function issues(): HasMany
    {
        return $this->hasMany(Issue::class);
    }

    // Accessors
    public function getFullAddressAttribute(): string
    {
        $parts = array_filter([
            $this->unit_number,
            $this->building_name,
        ]);

        return implode(', ', $parts);
    }

    public function getNameAttribute(): string
    {
        return $this->user?->name ?? '';
    }

    public function getEmailAttribute(): string
    {
        return $this->user?->email ?? '';
    }

    public function getPhoneAttribute(): string
    {
        return $this->user?->phone ?? '';
    }
}
