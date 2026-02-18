<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ServiceProvider extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'latitude',
        'longitude',
        'is_available',
    ];

    protected function casts(): array
    {
        return [
            'latitude' => 'decimal:8',
            'longitude' => 'decimal:8',
            'is_available' => 'boolean',
        ];
    }

    // Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function categories(): BelongsToMany
    {
        return $this->belongsToMany(Category::class, 'category_service_provider')
            ->withTimestamps();
    }

    public function timeSlots(): HasMany
    {
        return $this->hasMany(TimeSlot::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(IssueAssignment::class);
    }

    // Scopes
    public function scopeAvailable($query)
    {
        return $query->where('is_available', true);
    }

    public function scopeForCategory($query, int $categoryId)
    {
        return $query->whereHas('categories', fn ($q) => $q->where('categories.id', $categoryId)
        );
    }

    public function scopeForCategoryWithAncestors($query, int $categoryId)
    {
        $category = Category::find($categoryId);

        if (! $category) {
            return $query->whereHas('categories', fn ($q) => $q->where('categories.id', $categoryId));
        }

        $categoryIds = $category->getAncestorIds();
        $categoryIds[] = $categoryId;

        return $query->whereHas('categories', fn ($q) => $q->whereIn('categories.id', $categoryIds));
    }

    public function scopeForCategories($query, array $categoryIds)
    {
        return $query->whereHas('categories', fn ($q) => $q->whereIn('categories.id', $categoryIds)
        );
    }

    // Accessors
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

    // Helpers
    public function hasLocation(): bool
    {
        return $this->latitude !== null && $this->longitude !== null;
    }

    public function getActiveTimeSlots()
    {
        return $this->timeSlots()->where('is_active', true)->get();
    }
}
